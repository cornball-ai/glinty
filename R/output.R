#' Create an output proxy for a session
#'
#' Assignments to output$id create observers that send `output`
#' messages to this session, typed by the renderer's kind. A bare
#' function is a text renderer; anything else comes from render_text()
#' and friends, which say what they produce.
#'
#' @param session a glinty_session
#' @return a glinty_output proxy
#' @keywords internal
make_output_proxy <- function(session) {
    output_reg <- new.env(parent = emptyenv())

    reg_output <- function(id, value) {
        if (exists(id, envir = output_reg)) {
            output_reg[[id]]$destroy()
        }
        renderer <- as_renderer(value)
        # Renderers with a bind hook (e.g. render_plot with client
        # sizing) build their fn once they know their output id and
        # session.
        if (!is.null(renderer$bind)) {
            renderer <- new_renderer(renderer$bind(id, session), renderer$kind)
        }
        obs <- with_session(session, observe(
                fn = function() {
            # Render errors become error messages for this output;
            # glinty_silent (req) passes through to the observer
            # runner and suppresses the update entirely.
            result <- tryCatch(
                               list(ok = renderer$fn()),
                               error = function(e) list(err = conditionMessage(e))
            )
            if (is.null(result$err)) {
                session$send_output(id,
                                    output_msg(id, renderer$kind, result$ok))
                # Dynamic UI: elements just (re)built client-side have
                # never seen their outputs' values. Replay the last
                # known state of any output id inside the new tree so
                # panels appear current, not blank.
                if (identical(renderer$kind, "ui") && !is.null(result$ok)) {
                    for (oid in collect_tree_ids(result$ok)) {
                        if (!identical(oid, id) &&
                            !is.null(session$last_sent[[oid]])) {
                            session$send(session$last_sent[[oid]])
                        }
                    }
                }
            } else {
                session$send_output(id, error_msg(id, result$err))
            }
        },
                label = paste0("output:", id)
            ))
        output_reg[[id]] <- obs
    }

    structure(list(.reg = reg_output, .env = output_reg),
              class = "glinty_output")
}

#' Register an output renderer
#'
#' @param x a glinty_output proxy
#' @param name character output ID
#' @param value a function that computes the output, or a renderer
#'   from render_text() and friends
#' @return the proxy, invisibly
#' @export
`$<-.glinty_output` <- function(x, name, value) {
    x$.reg(name, value)
    x
}

#' Register an output renderer by name
#'
#' @param x a glinty_output proxy
#' @param name character output ID
#' @param value a function that computes the output, or a renderer
#'   from render_text() and friends
#' @return the proxy, invisibly
#' @export
`[[<-.glinty_output` <- function(x, name, value) {
    x$.reg(name, value)
    x
}

#' Coerce an output value to a renderer
#'
#' A bare function becomes a text renderer whose value is coerced to
#' character. Renderers pass through unchanged.
#'
#' @param value a function or glinty_renderer
#' @return a glinty_renderer list
#' @keywords internal
as_renderer <- function(value) {
    if (inherits(value, "glinty_renderer")) {
        return(value)
    }
    if (!is.function(value)) {
        stop("output values must be functions or renderers", call. = FALSE)
    }
    structure(list(fn = function() as.character(value()), kind = "text"),
              class = "glinty_renderer")
}

#' Collect element ids from an unclassed tag tree
#'
#' @param x an unclassed tag tree node
#' @return character vector of ids
#' @keywords internal
collect_tree_ids <- function(x) {
    if (!is.list(x)) {
        return(character(0L))
    }
    ids <- character(0L)
    if (!is.null(x$id)) {
        ids <- as.character(x$id)
    }
    for (child in if (is.null(x$children)) list() else x$children) {
        ids <- c(ids, collect_tree_ids(child))
    }
    # A tabset's children hang off its panels, so a replay would miss
    # every output inside a tab without this.
    for (panel in if (is.null(x$panels)) list() else x$panels) {
        for (child in if (is.null(panel$children)) list() else panel$children) {
            ids <- c(ids, collect_tree_ids(child))
        }
    }
    ids
}
