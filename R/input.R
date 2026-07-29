#' Create an input proxy for a session
#'
#' Wraps the session's input environment so that accessing an unknown
#' input auto-creates a reactive_val initialized to NULL. This prevents
#' errors when server code reads inputs before any events arrive.
#'
#' @param session a glinty_session
#' @return a glinty_input proxy
#' @keywords internal
make_input_proxy <- function(session) {
    structure(list(.env = session$input_env), class = "glinty_input")
}

#' Access an input value
#'
#' @param x a glinty_input proxy
#' @param name character input ID
#' @return a reactive_val function
#' @export
`$.glinty_input` <- function(x, name) {
    input_env <- .subset2(x, ".env")
    if (!exists(name, envir = input_env)) {
        input_env[[name]] <- reactive_val(NULL)
    }
    input_env[[name]]
}

#' Access an input value by name
#'
#' @param x a glinty_input proxy
#' @param name character input ID
#' @return a reactive_val function
#' @export
`[[.glinty_input` <- function(x, name) {
    `$.glinty_input`(x, name)
}

#' Process an input change for a session
#'
#' Creates a reactive_val for new inputs or updates existing ones.
#' Does not flush; the dispatch layer flushes after handling.
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value the new value
#' @keywords internal
handle_input <- function(session, id, value) {
    env <- session$input_env
    if (!exists(id, envir = env)) {
        env[[id]] <- reactive_val(value)
    } else {
        env[[id]](value)
    }
    invisible(NULL)
}

#' Process a discrete event for a session
#'
#' Event counters follow action-button semantics: the input starts at
#' NULL (treated as 0) and each event increments it, so every press
#' invalidates dependents even though the "value" is monotonic.
#'
#' A button carrying a `value` sets that instead of counting, so one
#' handler can serve a list of rows and read which row was pressed.
#' Pressing the same row twice still invalidates -- reactive_val()
#' writes unconditionally -- so this keeps event semantics rather
#' than quietly becoming an input that ignores repeats.
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value the button's value, or NULL for a counting button
#' @keywords internal
handle_event <- function(session, id, value = NULL) {
    env <- session$input_env
    if (!is.null(value)) {
        if (!exists(id, envir = env)) {
            env[[id]] <- reactive_val(value)
        } else {
            env[[id]](value)
        }
        return(invisible(NULL))
    }
    if (!exists(id, envir = env)) {
        env[[id]] <- reactive_val(1L)
    } else {
        cur <- isolate(env[[id]]())
        if (is.null(cur)) {
            cur <- 0L
        }
        env[[id]](cur + 1L)
    }
    invisible(NULL)
}
