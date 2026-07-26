#' Create an output proxy for a session
#'
#' Assignments to output$id create observers that send update messages
#' to this session. The DOM property defaults to textContent but can be
#' overridden by registering a property via output_property() or by
#' assigning a renderer created with render_html() and friends.
#'
#' @param session a glinty_session
#' @return a glinty_output proxy
#' @keywords internal
make_output_proxy <- function(session) {
    output_reg <- new.env(parent = emptyenv())
    prop_reg <- new.env(parent = emptyenv())

    reg_output <- function(id, value) {
        if (exists(id, envir = output_reg)) {
            output_reg[[id]]$destroy()
        }
        default_prop <- if (exists(id, envir = prop_reg)) {
            prop_reg[[id]]
        } else {
            "textContent"
        }
        renderer <- as_renderer(value, default_prop)
        # Renderers with a bind hook (e.g. render_plot with client
        # sizing) build their fn once they know their output id and
        # session.
        if (!is.null(renderer$bind)) {
            renderer <- new_renderer(renderer$bind(id, session),
                                     renderer$property)
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
                                    update_msg(id, renderer$property, result$ok))
                # Dynamic UI: elements just (re)built client-side have
                # never seen their outputs' patches. Replay the last
                # known state of any output id inside the new tree so
                # panels appear current, not blank.
                if (identical(renderer$property, "ui") && !is.null(result$ok)) {
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

    structure(list(.reg = reg_output, .env = output_reg, .props = prop_reg),
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
#' A bare function becomes a textContent renderer whose value is
#' coerced to character. Renderers pass through unchanged.
#'
#' @param value a function or glinty_renderer
#' @param default_prop character DOM property for bare functions
#' @return a glinty_renderer list
#' @keywords internal
as_renderer <- function(value, default_prop = "textContent") {
    if (inherits(value, "glinty_renderer")) {
        return(value)
    }
    if (!is.function(value)) {
        stop("output values must be functions or renderers", call. = FALSE)
    }
    structure(
              list(fn = function() as.character(value()), property = default_prop),
              class = "glinty_renderer"
    )
}

#' Set the DOM property for an output
#'
#' By default, output observers update textContent. Call this before
#' assigning the output function to use a different property (e.g.
#' "src" for audio, "innerHTML" for HTML output).
#'
#' @param output a glinty_output proxy
#' @param id character output ID
#' @param property character DOM property name
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' output_property(output, "player", "src")
#' output$player <- function() audio_data_uri()
#' }
#' @export
output_property <- function(output, id, property) {
    prop_reg <- .subset2(output, ".props")
    prop_reg[[id]] <- property
    invisible(NULL)
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
    if (!is.null(x$attrs$id)) {
        ids <- as.character(x$attrs$id)
    }
    for (child in if (is.null(x$children)) list() else x$children) {
        ids <- c(ids, collect_tree_ids(child))
    }
    ids
}
