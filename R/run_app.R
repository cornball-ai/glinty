#' Define a glinty application
#'
#' @param ui a UI tree from page() etc.
#' @param server a function(input, output) or
#'   function(input, output, session) defining reactive logic; it is
#'   called once per connecting browser tab, each with its own
#'   session-scoped state
#' @return A glinty_app object
#' @examples
#' app_obj <- app(
#'     ui = page(
#'         text_input("name", "Name:"),
#'         text_output("greeting")
#'     ),
#'     server = function(input, output) {
#'         output$greeting <- render_text(function() {
#'             paste("Hello,", input$name())
#'         })
#'     }
#' )
#' @export
app <- function(ui, server) {
    if (!is.function(server)) {
        stop("server must be a function", call. = FALSE)
    }
    structure(list(ui = ui, server = server), class = "glinty_app")
}

#' Run a glinty application
#'
#' Serves the app over HTTP with a WebSocket per browser tab, all on
#' base R sockets in a single-threaded event loop. Blocks until
#' interrupted (Ctrl-C). Note base R's serverSocket() listens on all
#' interfaces; treat the port as reachable from the local network.
#'
#' Dropped connections detach their session rather than ending it:
#' observers and timers stay alive for
#' getOption("glinty.resume_grace", 60) seconds, and a client that
#' reconnects with the session id resumes where it left off (current
#' output state is replayed, no renderers re-run). Within that grace
#' window the session id acts as the resume credential -- acceptable
#' for the localhost/LAN tool scope, but treat it accordingly.
#'
#' @param app_obj a glinty_app object
#' @param port integer HTTP port (default 8080)
#' @param static_dir character directory served under /static/
#'   (default "www" in the working directory; skipped if absent)
#' @param check_secrets logical refuse to start when the rendered page
#'   contains the value of a secret-looking environment variable (see
#'   env_secrets_in()). The usual cause is prefilling an input from
#'   Sys.getenv(), which publishes the secret to anyone who can fetch
#'   the page. Set FALSE only deliberately.
#' @param max_upload integer largest accepted request body in bytes
#'   (default 10 MB). Bodies are buffered whole in memory before
#'   routing, so this is a memory ceiling as much as a policy one;
#'   raise it deliberately for apps that take audio or video.
#'   Oversized requests get a 413 without being read.
#' @param quiet logical suppress the startup message
#' @return invisible(NULL); runs until interrupt
#' @examples
#' \dontrun{
#' run_app(app_obj, port = 8080)
#' }
#' @export
run_app <- function(app_obj, port = 8080L, static_dir = "www",
                    max_upload = 10485760L, check_secrets = TRUE,
                    quiet = FALSE) {
    if (!inherits(app_obj, "glinty_app")) {
        stop("app_obj must be a glinty_app (see app())", call. = FALSE)
    }

    old_max <- options(glinty.max_upload = as.integer(max_upload))
    on.exit(options(old_max), add = TRUE)

    # Reset reactive state
    .globals$current_context <- NULL
    .globals$pending_flush <- list()
    .globals$flush_scheduled <- FALSE
    .globals$current_session <- NULL
    .globals$timers <- list()
    .globals$progress <- list()

    page_html <- full_page_html(
                                tag_to_html(app_obj$ui),
        if (!is.null(app_obj$ui$title)) app_obj$ui$title else "glinty app",
                                app_obj$ui$head
    )
    # Before a single byte is served, not after.
    if (isTRUE(check_secrets)) {
        check_page_secrets(page_html)
    }

    pkg_www <- system.file("www", package = "glinty")
    if (!is.null(static_dir) && !dir.exists(static_dir)) {
        static_dir <- NULL
    }

    n_formals <- length(formals(app_obj$server))

    start_session <- function(sid, resumed = NULL) {
        s <- new_session(sid, send_fn = function(msg) {
            send_to_session(sid, msg)
        })
        s$send(config_msg(sid, resumed = resumed))
        with_session(s, {
            if (n_formals >= 3L) {
                app_obj$server(s$input, s$output, s)
            } else {
                app_obj$server(s$input, s$output)
            }
        })
        flush_reactions()
        s
    }

    handlers <- list(
                     on_request = function(req) {
        route_http(req, page_html, pkg_www, static_dir)
    },
                     # Sessions start on the FIRST client message, not at
                     # upgrade: the first frame decides between a fresh
                     # init and a resume of a detached session.
                     on_open = function(sid) invisible(NULL),
                     on_message = function(sid, txt) {
        s <- .globals$sessions[[sid]]
        if (!is.null(s)) {
            dispatch_client_message(s, txt)
            return(invisible(NULL))
        }
        first <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                          error = function(e) NULL)
        if (!is.null(first) && identical(first$type, "resume")) {
            old_id <- first$session_id
            old <- if (is.character(old_id) && nzchar(old_id)) {
                .globals$sessions[[old_id]]
            } else {
                NULL
            }
            if (!is.null(old) && isTRUE(old$detached) &&
                     transport_rebind(sid, old_id)) {
                resume_session(old)
            } else {
                # unknown or expired: honest fresh session; the
                # client reloads since its DOM may be stale
                start_session(sid, resumed = FALSE)
            }
            return(invisible(NULL))
        }
        s <- start_session(sid)
        dispatch_client_message(s, txt)
        flush_reactions()
    },
                     on_close = function(sid) {
        s <- .globals$sessions[[sid]]
        if (!is.null(s)) {
            detach_session(s)
        }
    }
    )

    if (!quiet) {
        message("glinty app running at http://localhost:", port)
    }
    run_ws_server(port, handlers)
    invisible(NULL)
}

#' Route a plain HTTP request
#'
#' @param req parsed request
#' @param page_html character full page document
#' @param pkg_www character package asset dir (served at /glinty/)
#' @param static_dir character app asset dir (served at /static/),
#'   or NULL
#' @return raw HTTP response
#' @keywords internal
route_http <- function(req, page_html, pkg_www, static_dir) {
    if (identical(req$method, "POST") && identical(req$path, "/upload")) {
        return(handle_upload(req))
    }
    if (!identical(req$method, "GET")) {
        return(http_response_raw(404L, "text/plain", "Not found"))
    }
    if (identical(req$path, "/download")) {
        return(handle_download(req))
    }
    if (req$path %in% c("/", "")) {
        return(http_response_raw(200L, "text/html; charset=utf-8", page_html))
    }
    if (startsWith(req$path, "/glinty/")) {
        return(serve_static(sub("^/glinty/", "", req$path), pkg_www))
    }
    if (!is.null(static_dir) && startsWith(req$path, "/static/")) {
        return(serve_static(sub("^/static/", "", req$path), static_dir))
    }
    http_response_raw(404L, "text/plain", "Not found")
}

#' Run a bundled example app
#'
#' @param name character example name; omit to list available
#'   examples
#' @param port integer HTTP port
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' run_example("counter")
#' }
#' @export
run_example <- function(name, port = 8080L) {
    examples_dir <- system.file("examples", package = "glinty")
    available <- list.dirs(examples_dir, recursive = FALSE, full.names = FALSE)
    if (missing(name)) {
        message("Available examples: ", paste(available, collapse = ", "))
        return(invisible(NULL))
    }
    app_dir <- file.path(examples_dir, name)
    app_file <- file.path(app_dir, "app.R")
    if (!file.exists(app_file)) {
        stop("no example named '", name, "'; available: ",
             paste(available, collapse = ", "), call. = FALSE)
    }
    app_obj <- source(app_file, local = new.env())$value
    if (!inherits(app_obj, "glinty_app")) {
        stop("example '", name, "' did not end with an app() object",
             call. = FALSE)
    }
    www <- file.path(app_dir, "www")
    run_app(app_obj, port = port,
            static_dir = if (dir.exists(www)) www else NULL)
}
