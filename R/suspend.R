# Suspending the outputs nobody can see.
#
# A tabset shows one panel; the others are hidden client-side. On the
# server every renderer behind every panel used to run on every
# invalidation, and every invalidate_later() behind a hidden panel
# kept polling, so a page made of several tools cost the sum of them
# while one was on screen. The tree says which panel each output is
# in, and a tabset with an id reports which panel is open, so the
# server can tell: an output inside a hidden panel waits, and renders
# once when its panel opens.

#' Which tab panels enclose each id
#'
#' Walks a tree and, for every component with an id inside a panel of
#' a tabset, records the (tabset id, panel title) pairs that must all
#' be open for it to be visible. Nested tabsets stack their
#' conditions. Ids outside any panel are not recorded: nothing hides
#' them.
#'
#' @param x a component, or a tree in its unclassed list form
#' @param base conditions already enclosing `x` (a dynamic subtree
#'   inherits its slot's)
#' @return a named list, id -> list of list(tabset =, panel =)
#' @keywords internal
output_panels <- function(x, base = list()) {
    out <- list()
    walk <- function(node, conds) {
        if (!is.list(node) || is.data.frame(node)) {
            return(invisible(NULL))
        }
        if (length(conds) && is.character(node$component) &&
            length(node$component) == 1L && is.character(node$id) &&
            length(node$id) == 1L && !is.na(node$id)) {
            out[[node$id]] <<- conds
        }
        if (identical(node$component, "tabset")) {
            gated <- is.character(node$id) && length(node$id) == 1L &&
                !is.na(node$id)
            for (panel in if (is.null(node$panels)) list() else node$panels) {
                inner <- conds
                if (gated && is.character(panel$title)) {
                    inner <- c(conds, list(list(tabset = node$id,
                                                panel = panel$title)))
                }
                for (child in if (is.null(panel$children)) list() else panel$children) {
                    walk(child, inner)
                }
            }
            return(invisible(NULL))
        }
        for (part in node) {
            if (is.list(part)) {
                walk(part, conds)
            }
        }
        invisible(NULL)
    }
    walk(x, base)
    out
}

#' A session's panel map, from the static tree
#'
#' One environment per session, because a dynamic subtree adds to it
#' at render time and sessions render different subtrees.
#'
#' @param ui the app's UI tree
#' @return an environment, id -> conditions
#' @keywords internal
panel_env <- function(ui) {
    list2env(output_panels(ui), parent = emptyenv())
}

#' Is this output's panel open?
#'
#' Reads the selection input of every tabset enclosing the output,
#' inside the output's own reactive context, which is what re-runs
#' the renderer when the panel opens. An output the map does not
#' know, or a session with no map, is visible. A tabset whose
#' selection is NULL (unseeded, never reported) hides nothing: a
#' guess that suspends is worse than a render nobody sees.
#'
#' @param session a glinty_session
#' @param id character output id
#' @return logical
#' @keywords internal
output_visible <- function(session, id) {
    panels <- session$panel_of
    if (is.null(panels)) {
        return(TRUE)
    }
    conds <- panels[[id]]
    if (is.null(conds)) {
        return(TRUE)
    }
    for (cond in conds) {
        open <- session$input[[cond$tabset]]()
        if (!is.null(open) && !identical(open, cond$panel)) {
            return(FALSE)
        }
    }
    TRUE
}

#' Record the panels of a dynamic subtree's ids
#'
#' A render_ui() tree is not in the static map; its ids inherit the
#' slot's conditions plus any tabset inside the subtree. Ids this
#' slot recorded on an earlier render and no longer contains are
#' forgotten, so a moved output is not gated by a panel it left.
#'
#' @param session a glinty_session
#' @param slot character the ui_output's id
#' @param tree the rendered subtree, unclassed
#' @return invisible(NULL)
#' @keywords internal
note_dynamic_panels <- function(session, slot, tree) {
    panels <- session$panel_of
    if (is.null(panels)) {
        return(invisible(NULL))
    }
    if (is.null(session$panel_by_slot)) {
        session$panel_by_slot <- new.env(parent = emptyenv())
    }
    base <- panels[[slot]]
    if (is.null(base)) {
        base <- list()
    }
    found <- output_panels(tree, base)
    before <- session$panel_by_slot[[slot]]
    for (old in setdiff(before, names(found))) {
        if (exists(old, envir = panels, inherits = FALSE)) {
            rm(list = old, envir = panels)
        }
    }
    for (nm in names(found)) {
        panels[[nm]] <- found[[nm]]
    }
    session$panel_by_slot[[slot]] <- names(found)
    invisible(NULL)
}
