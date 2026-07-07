#' Run a glinty application in a native window
#'
#' Renders the app with flitR (the Flutter Engine) instead of a
#' browser. The reactive core, sessions, and wire protocol are the
#' same as run_app(): the native window is simply another client of
#' the update messages. Requires the flitR package with its engine
#' installed (flitR::install_engine()), and a display.
#'
#' Supported UI subset: headings, p/span/a text, text_input, button,
#' checkbox_input, slider_input (step is ignored), text_output, and
#' plot_output via flitR's image op. Unsupported widgets fail fast
#' with a list. update_* label and choices changes are ignored
#' natively.
#'
#' @param app_obj a glinty_app object
#' @param width integer window width in logical pixels
#' @param height integer window height in logical pixels
#' @param quiet logical suppress the startup message
#' @return invisible(NULL); runs until the window closes
#' @examples
#' \dontrun{
#' run_app_native(app_obj)
#' }
#' @export
run_app_native <- function(app_obj, width = 800L, height = 600L,
                           quiet = FALSE) {
    if (!inherits(app_obj, "glinty_app")) {
        stop("app_obj must be a glinty_app (see app())", call. = FALSE)
    }
    if (!requireNamespace("flitR", quietly = TRUE)) {
        stop("the native backend needs the flitR package ",
            "(and flitR::install_engine())", call. = FALSE)
    }
    exports <- getNamespaceExports("flitR")
    if (!all(c("image", "render_dirty", "ensure_window") %in% exports)) {
        stop("this glinty needs a newer flitR (image op and driver ",
            "API); update flitR", call. = FALSE)
    }

    # Reset reactive state
    .globals$current_context <- NULL
    .globals$pending_flush <- list()
    .globals$flush_scheduled <- FALSE
    .globals$current_session <- NULL
    .globals$timers <- list()

    values <- new.env(parent = emptyenv())
    native <- new.env(parent = emptyenv())
    native$dirty <- TRUE
    native$done <- FALSE

    s <- new_session("native", send_fn = function(msg) {
        native_apply(msg, values, native)
    })

    n_formals <- length(formals(app_obj$server))
    with_session(s, {
        if (n_formals >= 3L) {
            app_obj$server(s$input, s$output, s)
        } else {
            app_obj$server(s$input, s$output)
        }
    })
    flush_reactions()

    conn <- flitR::ensure_window()
    flitR::on_close(function() native$done <- TRUE)
    on.exit({
        flitR::on_close(NULL)
        session_end(s)
        tryCatch(flitR::close_window(), error = function(e) NULL)
    }, add = TRUE)

    if (!quiet) {
        message("glinty native app running; close the window to stop.")
    }

    tryCatch(
        repeat {
            run_due_timers()
            flush_reactions()
            drain_session(s)

            if (native$dirty || flitR::render_dirty()) {
                native$dirty <- FALSE
                flitR::render_clean()
                flitR::reset_widgets()
                items <- build_native_ops(app_obj$ui, s, values)
                sc <- do.call(flitR::scene,
                    c(items, list(width = width, height = height)))
                flitR::send_scene_to_conn(conn, sc)
            }
            if (native$done) {
                break
            }

            tmo <- next_timer_deadline()
            tmo <- if (is.null(tmo)) 0.5 else min(0.5, max(tmo, 0))
            while (socketSelect(list(conn), timeout = tmo)) {
                msg <- flitR::read_framed_message(conn)
                if (is.null(msg)) {
                    native$done <- TRUE
                    break
                }
                flitR::handle_event_json(msg)
                tmo <- 0 # drain queued events without sleeping
            }
            if (native$done) {
                break
            }
        },
        interrupt = function(e) message("\nglinty native app stopped.")
    )
    invisible(NULL)
}

#' Apply a protocol message to the native value store
#'
#' The native backend is a client of the same wire protocol the
#' browser speaks: update messages set output values, errors show as
#' text, update_input redraws (the server side already synced the
#' input value). Any change marks the scene dirty.
#'
#' @param msg_json character one protocol message
#' @param values output value env
#' @param native native loop state env
#' @return invisible(NULL)
#' @keywords internal
native_apply <- function(msg_json, values, native) {
    msg <- tryCatch(
        jsonlite::fromJSON(msg_json, simplifyVector = FALSE),
        error = function(e) NULL
    )
    if (is.null(msg) || is.null(msg$type)) {
        return(invisible(NULL))
    }
    if (identical(msg$type, "update")) {
        values[[msg$id]] <- msg$value
        native$dirty <- TRUE
    } else if (identical(msg$type, "error")) {
        if (!is.null(msg$id)) {
            values[[msg$id]] <- paste("Error:", msg$message)
            native$dirty <- TRUE
        }
    } else if (identical(msg$type, "update_input")) {
        native$dirty <- TRUE
    }
    invisible(NULL)
}