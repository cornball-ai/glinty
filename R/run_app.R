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
#' @param app_obj a glinty_app object
#' @param port integer HTTP port (default 8080)
#' @param static_dir character directory served under /static/
#'   (default "www" in the working directory; skipped if absent)
#' @param quiet logical suppress the startup message
#' @return invisible(NULL); runs until interrupt
#' @examples
#' \dontrun{
#' run_app(app_obj, port = 8080)
#' }
#' @export
run_app <- function(app_obj, port = 8080L, static_dir = "www",
                    quiet = FALSE) {
    if (!inherits(app_obj, "glinty_app")) {
        stop("app_obj must be a glinty_app (see app())", call. = FALSE)
    }

    # Reset reactive state
    .globals$current_context <- NULL
    .globals$pending_flush <- list()
    .globals$flush_scheduled <- FALSE
    .globals$current_session <- NULL
    .globals$timers <- list()

    page_html <- full_page_html(
        tag_to_html(app_obj$ui),
        if (!is.null(app_obj$ui$title)) app_obj$ui$title else "glinty app"
    )
    pkg_www <- system.file("www", package = "glinty")
    if (!is.null(static_dir) && !dir.exists(static_dir)) {
        static_dir <- NULL
    }

    n_formals <- length(formals(app_obj$server))

    handlers <- list(
        on_request = function(req) {
            route_http(req, page_html, pkg_www, static_dir)
        },
        on_open = function(sid) {
            s <- new_session(sid, send_fn = function(msg) {
                send_to_session(sid, msg)
            })
            s$send(config_msg(sid))
            with_session(s, {
                if (n_formals >= 3L) {
                    app_obj$server(s$input, s$output, s)
                } else {
                    app_obj$server(s$input, s$output)
                }
            })
            flush_reactions()
        },
        on_message = function(sid, txt) {
            s <- .globals$sessions[[sid]]
            if (!is.null(s)) {
                dispatch_client_message(s, txt)
            }
        },
        on_close = function(sid) {
            s <- .globals$sessions[[sid]]
            if (!is.null(s)) {
                session_end(s)
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
    if (!identical(req$method, "GET")) {
        return(http_response_raw(404L, "text/plain", "Not found"))
    }
    if (req$path %in% c("/", "")) {
        return(http_response_raw(200L, "text/html; charset=utf-8",
            page_html))
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
    available <- list.dirs(examples_dir, recursive = FALSE,
        full.names = FALSE)
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
