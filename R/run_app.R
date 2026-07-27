#' Define a glinty application
#'
#' @param ui a UI tree from page() etc.
#' @param server a function(input, output) or
#'   function(input, output, session) defining reactive logic; it is
#'   called once per connecting browser tab, each with its own
#'   session-scoped state
#' @param theme an app_theme(), or NULL for each frontend's own
#'   defaults (in the browser that includes automatic dark mode,
#'   which a supplied theme replaces with exactly its tokens)
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
app <- function(ui, server, theme = NULL) {
    if (!is.function(server)) {
        stop("server must be a function", call. = FALSE)
    }
    if (!is.null(theme) && !inherits(theme, "glinty_theme")) {
        stop("theme must come from app_theme(), or be NULL", call. = FALSE)
    }
    structure(list(ui = ui, server = server, theme = theme),
              class = "glinty_app")
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
#' @param port integer HTTP port. NULL (the default) reads
#'   GLINTY_PORT then PORT from the environment before falling back
#'   to 8080, so a scheduler-allocated port needs no plumbing.
#' @param auth a function(token) verifying the opaque token a client
#'   sends in hello: NULL from the function refuses the connection,
#'   anything else becomes session$principal. NULL (the default)
#'   accepts every connection with no principal. See jwt_auth() for
#'   the JWT case.
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
run_app <- function(app_obj, port = NULL, auth = NULL, static_dir = "www",
                    max_upload = 10485760L, check_secrets = TRUE,
                    quiet = FALSE) {
    if (!inherits(app_obj, "glinty_app")) {
        stop("app_obj must be a glinty_app (see app())", call. = FALSE)
    }
    if (!is.null(auth) && !is.function(auth)) {
        stop("auth must be a function(token), or NULL (see jwt_auth())",
             call. = FALSE)
    }
    port <- resolve_port(port)

    old_max <- options(glinty.max_upload = as.integer(max_upload))
    on.exit(options(old_max), add = TRUE)

    # Reset reactive state
    .globals$current_context <- NULL
    .globals$pending_flush <- list()
    .globals$flush_scheduled <- FALSE
    .globals$current_session <- NULL
    .globals$timers <- list()
    .globals$progress <- list()
    .globals$tickets <- new.env(parent = emptyenv())

    # The tree and its revision are computed once: the same wire form
    # goes into every welcome, and the revision goes into both the
    # pre-rendered document and the welcome, which is what lets a
    # client tell whether the markup it was handed matches the tree
    # it was just sent.
    .globals$welcome_ui <- unclass_recursive(app_obj$ui)
    .globals$welcome_revision <- ui_revision(app_obj$ui)
    # Theme tokens ride beside the tree, not in it: a palette change
    # must not invalidate hydration, any more than a stylesheet would.
    .globals$welcome_theme <- if (is.null(app_obj$theme)) {
        NULL
    } else {
        theme_wire(app_obj$theme)
    }

    page_html <- full_page_html(
                                component_to_html(app_obj$ui),
        if (!is.null(app_obj$ui$title)) app_obj$ui$title else "glinty app",
                                attr(app_obj$ui, "assets"),
                                ui_revision = .globals$welcome_revision,
                                theme_css = if (is.null(app_obj$theme)) {
            NULL
        } else {
            theme_css(app_obj$theme)
        }
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
    started <- as.numeric(Sys.time())

    start_session <- function(sid, resumed = NULL, principal = NULL) {
        s <- new_session(sid, send_fn = function(msg) {
            send_to_session(sid, msg)
        })
        s$principal <- principal
        # Inputs seed from the tree before the server function runs:
        # reactives read defaults on their first run, and
        # observe_event()'s ignore_init treats them as init state
        # rather than changes. Protocol 2 waited for the client to
        # send these back.
        seed_session_inputs(s, app_obj$ui)
        s$send(welcome_msg(sid, resumed = resumed))
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
        route_http(req, page_html, pkg_www, static_dir, started = started)
    },
                     # Sessions start on the FIRST client message, not at
                     # upgrade: the hello decides between a fresh
                     # session and a resume of a detached one.
                     on_open = function(sid) invisible(NULL),
                     on_message = function(sid, txt) {
        s <- .globals$sessions[[sid]]
        if (!is.null(s)) {
            dispatch_client_message(s, txt)
            return(invisible(NULL))
        }
        first <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                          error = function(e) NULL)
        # The gate sits before any session exists, resume included: a
        # token that no longer verifies does not get its old session
        # back.
        gate <- authenticate_hello(auth, first)
        if (!gate$ok) {
            refuse_conn(sid, "authentication failed")
            return(invisible(NULL))
        }
        resume_id <- if (!is.null(first) && identical(first$type, "hello")) {
            first$resume
        } else {
            NULL
        }
        if (is.character(resume_id) && nzchar(resume_id)) {
            old <- .globals$sessions[[resume_id]]
            if (!is.null(old) && isTRUE(old$detached) &&
                     transport_rebind(sid, resume_id)) {
                old$principal <- gate$principal
                resume_session(old)
                # the reconnecting client redeclares its capabilities
                dispatch_client_message(old, txt)
            } else {
                # unknown or expired: honest fresh session; the
                # client reloads since its DOM holds dead state
                s <- start_session(sid, resumed = FALSE,
                                   principal = gate$principal)
                dispatch_client_message(s, txt)
            }
            return(invisible(NULL))
        }
        s <- start_session(sid, principal = gate$principal)
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
        # Named in the same breath as the URL, not buried in ?run_app:
        # base R's serverSocket() takes no bind address, so the one
        # component that can bind selectively is the firewall or
        # namespace around this port.
        message("listening on all interfaces (base R sockets cannot ",
                "bind selectively); gate sessions with auth = and ",
                "scope the port with a firewall or namespace")
        if (is.null(auth)) {
            message("auth: none (every connection accepted)")
        }
    }
    run_ws_server(port, handlers)
    invisible(NULL)
}

#' Resolve the port to serve on
#'
#' An explicit port wins. NULL reads GLINTY_PORT then PORT from the
#' environment -- a scheduler that allocates ports sets one of those
#' -- and falls back to 8080.
#'
#' @param port integer or NULL
#' @return integer port
#' @keywords internal
resolve_port <- function(port) {
    if (!is.null(port)) {
        port <- suppressWarnings(as.integer(port))
        if (length(port) != 1L || is.na(port) || port < 1L || port > 65535L) {
            stop("port must be a single integer in [1, 65535]", call. = FALSE)
        }
        return(port)
    }
    for (var in c("GLINTY_PORT", "PORT")) {
        val <- Sys.getenv(var, "")
        if (nzchar(val)) {
            p <- suppressWarnings(as.integer(val))
            if (length(p) == 1L && !is.na(p) && p >= 1L && p <= 65535L) {
                return(p)
            }
            stop(var, " is set but not a valid port: '", val, "'",
                 call. = FALSE)
        }
    }
    8080L
}

#' Refuse a connection before any session exists
#'
#' Sends one error frame so the refusal is visible client-side, then
#' marks the transport dead; the close happens at the top of the next
#' loop tick, after the frame has been written.
#'
#' @param sid character transport session id
#' @param message character reason shown to the client
#' @return invisible(NULL)
#' @keywords internal
refuse_conn <- function(sid, message) {
    send_to_session(sid, error_msg(NULL, message))
    key <- REG$sessions[[sid]]
    if (!is.null(key)) {
        mark_dead(key)
    }
    invisible(NULL)
}

#' Route a plain HTTP request
#'
#' @param req parsed request
#' @param page_html character full page document
#' @param pkg_www character package asset dir (served at /glinty/)
#' @param static_dir character app asset dir (served at /static/),
#'   or NULL
#' @param started numeric epoch seconds the server came up, for
#'   /healthz uptime
#' @return raw HTTP response
#' @keywords internal
route_http <- function(req, page_html, pkg_www, static_dir,
                       started = as.numeric(Sys.time())) {
    if (identical(req$method, "POST") && identical(req$path, "/upload")) {
        return(handle_upload(req))
    }
    if (!identical(req$method, "GET")) {
        return(http_response_raw(404L, "text/plain", "Not found"))
    }
    if (identical(req$path, "/healthz")) {
        # Session count and uptime, so a supervisor can tell
        # "listening" from "working" without opening a WebSocket.
        return(http_response_raw(200L, "application/json",
                                 sprintf('{"status":"ok","sessions":%d,"uptime":%d}',
                    length(ls(.globals$sessions)),
                    max(0L, as.integer(as.numeric(Sys.time()) - started)))))
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
