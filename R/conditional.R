#' Show a panel only when a condition holds
#'
#' The client evaluates the condition against the inputs it already
#' tracks and toggles the panel's visibility. Nothing is destroyed or
#' rebuilt, so inputs inside a hidden panel keep their values and
#' still report to the server; only the display changes.
#'
#' That is the difference from render_ui(), which rebuilds its
#' subtree on every change and resets any inputs inside it. Use
#' conditional_panel() to show and hide fixed content, and render_ui()
#' when the content itself is computed.
#'
#' Conditions are built from input_is() and combined with cond_and(),
#' cond_or() and cond_not(). There is no JavaScript expression to
#' write and nothing is eval()ed.
#'
#' Condition evaluation is a client capability. A frontend that does
#' not implement it renders the children always visible.
#'
#' @param ... child elements
#' @param condition a condition from input_is() and friends
#' @return A UI element
#' @examples
#' conditional_panel(
#'     text_input("api_base", "API URL:"),
#'     condition = input_is("backend", "openai")
#' )
#'
#' # show unless we are in qwen3 voice-design mode
#' conditional_panel(
#'     select_input("voice", "Voice:", c("a", "b")),
#'     condition = cond_not(cond_and(
#'         input_is("backend", "qwen3"),
#'         input_is("use_voice_design", TRUE)
#'     ))
#' )
#' @export
conditional_panel <- function(..., condition) {
    if (missing(condition)) {
        stop("conditional_panel() needs a condition from input_is(), ",
             "cond_and(), cond_or() or cond_not()", call. = FALSE)
    }
    component("conditional_panel", condition = condition, children = list(...))
}

#' Test an input's value
#'
#' TRUE when the input's current value is any of values, which makes
#' a vector an "is one of" test. Comparison is by string, except that
#' a logical compares by truthiness, so input_is("save", TRUE) reads a
#' checkbox correctly.
#'
#' An input that has never been set matches nothing, so a panel keyed
#' on an untouched input starts hidden.
#'
#' @param id character input ID
#' @param values vector of values to match
#' @return A glinty_condition
#' @examples
#' input_is("backend", "openai")
#' input_is("backend", c("chatterbox", "native"))
#' input_is("stream_mode", TRUE)
#' @export
input_is <- function(id, values) {
    if (!is.character(id) || length(id) != 1L || !nzchar(id)) {
        stop("input_is() id must be a non-empty character string",
             call. = FALSE)
    }
    if (length(values) == 0L) {
        stop("input_is() needs at least one value", call. = FALSE)
    }
    new_condition(list(op = "is", id = id, values = I(unname(values))))
}

#' Combine conditions with logical and
#'
#' @param ... conditions
#' @return A glinty_condition
#' @examples
#' cond_and(input_is("backend", "qwen3"), input_is("use_voice_design", TRUE))
#' @export
cond_and <- function(...) {
    new_condition(list(op = "and",
                       args = check_conditions(list(...), "cond_and")))
}

#' Combine conditions with logical or
#'
#' For alternatives on a single input, pass a vector to input_is()
#' instead; this is for alternatives across different inputs.
#'
#' @param ... conditions
#' @return A glinty_condition
#' @examples
#' cond_or(input_is("backend", "openai"), input_is("expert_mode", TRUE))
#' @export
cond_or <- function(...) {
    new_condition(list(op = "or",
                       args = check_conditions(list(...), "cond_or")))
}

#' Negate a condition
#'
#' @param condition a condition
#' @return A glinty_condition
#' @examples
#' cond_not(input_is("backend", "openai"))
#' @export
cond_not <- function(condition) {
    if (!inherits(condition, "glinty_condition")) {
        stop("cond_not() expects a condition", call. = FALSE)
    }
    new_condition(list(op = "not", arg = unclass(condition)))
}

#' Tag a condition list
#'
#' @param x a plain list describing one condition node
#' @return the list with class glinty_condition
#' @keywords internal
new_condition <- function(x) {
    structure(x, class = "glinty_condition")
}

#' Validate and unclass a set of conditions
#'
#' @param args list of candidate conditions
#' @param fn character calling function name, for the error message
#' @return an unnamed list of plain condition lists
#' @keywords internal
check_conditions <- function(args, fn) {
    if (length(args) < 1L) {
        stop(fn, "() needs at least one condition", call. = FALSE)
    }
    ok <- vapply(args, inherits, logical(1L), what = "glinty_condition")
    if (!all(ok)) {
        stop(fn, "() arguments must all be conditions", call. = FALSE)
    }
    unname(lapply(args, unclass))
}

#' Serialize a condition to JSON for the client
#'
#' @param condition a glinty_condition
#' @return character JSON
#' @keywords internal
condition_json <- function(condition) {
    as.character(jsonlite::toJSON(unclass(condition), auto_unbox = TRUE))
}

#' Evaluate a condition against a session's inputs
#'
#' The R-side twin of the client's interpreter, used by the native
#' backend, which has no JavaScript to run the browser one. The two
#' must agree, so the matching rule is the same: logicals compare by
#' truthiness, everything else by string, and an input that was never
#' set matches nothing.
#'
#' @param cond a decoded condition list (from condition_json)
#' @param session a glinty_session
#' @return logical
#' @keywords internal
eval_condition <- function(cond, session) {
    if (!is.list(cond) || is.null(cond$op)) {
        return(FALSE)
    }
    if (identical(cond$op, "is")) {
        val <- isolate(session$input[[cond$id]]())
        if (is.null(val)) {
            return(FALSE)
        }
        return(condition_matches(val, cond$values))
    }
    if (identical(cond$op, "and")) {
        return(all(vapply(cond$args, eval_condition, logical(1L),
                          session = session)))
    }
    if (identical(cond$op, "or")) {
        return(any(vapply(cond$args, eval_condition, logical(1L),
                          session = session)))
    }
    if (identical(cond$op, "not")) {
        return(!eval_condition(cond$arg, session))
    }
    FALSE
}

#' Test one input value against a condition's candidates
#'
#' @param actual the input's current value
#' @param wanted list or vector of candidate values
#' @return logical
#' @keywords internal
condition_matches <- function(actual, wanted) {
    for (w in wanted) {
        if (is.logical(w) || is.logical(actual)) {
            if (isTRUE(as.logical(actual)[[1L]]) == isTRUE(as.logical(w))) {
                return(TRUE)
            }
        } else if (identical(as.character(actual)[[1L]], as.character(w))) {
            return(TRUE)
        }
    }
    FALSE
}

#' Read a conditional panel's condition off its tag
#'
#' @param tg a glinty_tag
#' @return a decoded condition list, or NULL when absent or malformed
#' @keywords internal
tag_condition <- function(tg) {
    raw <- tg$attrs[["data-g-cond"]]
    if (is.null(raw)) {
        return(NULL)
    }
    tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE),
             error = function(e) NULL)
}
