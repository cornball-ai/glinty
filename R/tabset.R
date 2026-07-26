#' Create a tab panel
#'
#' One labelled page of a tabset(). Not a UI element on its own; it
#' only means anything inside tabset().
#'
#' @param title character tab label, also the value reported to the
#'   server when the tab is selected. Titles must be unique within a
#'   tabset.
#' @param ... child elements
#' @return A glinty_tab_panel
#' @examples
#' tab_panel("Text", verbatim_output("transcription"))
#' @export
tab_panel <- function(title, ...) {
    if (!is.character(title) || length(title) != 1L || !nzchar(title)) {
        stop("tab_panel() title must be a non-empty character string",
             call. = FALSE)
    }
    structure(list(title = title, children = list(...)),
              class = "glinty_tab_panel")
}

#' Create a tabset
#'
#' Switching tabs is a client-side class toggle, not a round trip, so
#' panel contents keep their DOM and their inputs keep their values
#' while hidden. Outputs in a hidden tab still update; they are
#' merely not visible.
#'
#' Given an id, the tabset is also an input: its value is the title
#' of the selected tab, readable as input$id() and seeded at page
#' load. Without an id it is presentation only.
#'
#' Tabsets nest: a panel may contain another tabset, and each is
#' scoped to its own container.
#'
#' @param ... tab_panel() objects
#' @param id character input ID reporting the selected tab, or NULL
#' @param selected character title of the initially open tab
#'   (defaults to the first)
#' @return A UI element
#' @examples
#' tabset(
#'     tab_panel("Text", verbatim_output("transcription")),
#'     tab_panel("Segments", table_output("segments")),
#'     id = "results_tabs"
#' )
#' @export
tabset <- function(..., id = NULL, selected = NULL) {
    panels <- list(...)
    if (length(panels) == 0L) {
        stop("tabset() needs at least one tab_panel()", call. = FALSE)
    }
    ok <- vapply(panels, inherits, logical(1L), what = "glinty_tab_panel")
    if (!all(ok)) {
        stop("tabset() children must all be tab_panel() objects",
             call. = FALSE)
    }

    titles <- vapply(panels, function(p) p$title, character(1L))
    if (anyDuplicated(titles) > 0L) {
        stop("tabset() titles must be unique; duplicated: ",
             paste(unique(titles[duplicated(titles)]), collapse = ", "),
             call. = FALSE)
    }
    if (is.null(selected)) {
        selected <- titles[[1L]]
    } else if (!selected %in% titles) {
        stop("tabset() selected must name one of its panels; got '",
             selected, "'", call. = FALSE)
    }

    buttons <- lapply(panels, function(p) {
        cls <- if (identical(p$title, selected)) {
            "g-tab-btn g-tab-active"
        } else {
            "g-tab-btn"
        }
        attrs <- list(class = cls, type = "button")
        attrs[["data-g-tab-panel"]] <- p$title
        # With an id the button doubles as a value-carrying click
        # bind, so selecting a tab reports the title as the input.
        bind <- if (is.null(id)) {
            NULL
        } else {
            list(event = "click", target = id, value = p$title)
        }
        tag("button", text = p$title, attrs = attrs, bind = bind)
    })

    bodies <- lapply(panels, function(p) {
        cls <- if (identical(p$title, selected)) {
            "g-tab-body"
        } else {
            "g-tab-body g-hidden"
        }
        attrs <- list(class = cls)
        attrs[["data-g-tab-panel"]] <- p$title
        tag("div", children = p$children, attrs = attrs)
    })

    set_attrs <- list(class = "g-tabset")
    if (!is.null(id)) {
        set_attrs$id <- id
    }
    tag(
        "div",
        attrs = set_attrs,
        children = list(
                        tag("div", children = buttons,
                            attrs = list(class = "g-tab-nav")),
                        tag("div", children = bodies,
                            attrs = list(class = "g-tab-bodies"))
        )
    )
}
