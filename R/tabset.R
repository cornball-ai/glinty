#' Create a tab panel
#'
#' One labelled page of a tabset(). Not a component on its own; it
#' only means anything inside tabset().
#'
#' @param title character tab label, also the value reported to the
#'   server when the tab is selected. Titles must be unique within a
#'   tabset.
#' @param ... child components
#' @return A tab panel spec
#' @examples
#' tab_panel("Text", verbatim_output("transcription"))
#' @export
tab_panel <- function(title, ...) {
    list(title = title, children = list(...))
}

#' Create a tabset
#'
#' Given an id the tabset is also an input: its value is the title of
#' the open tab.
#'
#' Hidden panels keep their state in the browser and in Flutter, both
#' of which retain the widgets they are not showing.
#'
#' @param ... tab_panel() objects
#' @param id character input ID reporting the open tab
#' @param selected character title of the initially open tab
#' @return A UI component
#' @examples
#' tabset(
#'     tab_panel("Text", verbatim_output("body")),
#'     tab_panel("Raw", verbatim_output("raw")),
#'     id = "results"
#' )
#' @export
tabset <- function(..., id, selected = NULL) {
    component("tabset", id = id, panels = list(...), selected = selected)
}
