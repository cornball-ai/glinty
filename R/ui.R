# Public UI builders. Thin wrappers over component(): validation and
# the wire format live there, so these stay readable and every one of
# them is one call.

#' Create a page
#'
#' The top-level container. The title becomes the browser tab title
#' when served, and the app name a native client shows.
#'
#' The asset arguments are browser-only and travel outside the
#' component tree, since a Flutter client has no use for a stylesheet.
#'
#' @param ... child components
#' @param title character page title
#' @param width character "content" for the centred reading column,
#'   "full" for the whole viewport. Forms and documents read best in a
#'   column; a workspace with side-by-side panels wants everything
#' @param css character vector of stylesheet URLs, e.g.
#'   "/static/styles.css"
#' @param js character vector of script URLs
#' @param favicon character URL of the tab icon
#' @param head a raw character HTML string appended to the document
#'   head; the escape hatch for meta tags. Trusted as-is.
#' @return A UI component
#' @examples
#' page(heading("Hello"), title = "My app")
#' page(row(panel(txt("left")), panel(txt("right"))), width = "full")
#' @export
page <- function(..., title = "glinty app", width = "content", css = NULL,
                 js = NULL, favicon = NULL, head = NULL) {
    x <- component("page", children = list(...), title = title, width = width)
    # Assets are a transport concern, not UI. Kept off the component so
    # they never reach a client that cannot use them.
    attr(x, "assets") <- page_head(css = css, js = js, favicon = favicon,
                                   extra = head)
    x
}

#' Display a string
#'
#' Named txt() rather than text() on purpose: text() would mask
#' graphics::text(), and a glinty app that draws a plot calls that
#' inside render_plot(). Masking it would break plotting in the one
#' place glinty most needs it to work. The component is still "text"
#' on the wire; only the R name gives way.
#'
#' @param value character text to show
#' @param variant character "normal", "muted", "strong", "heading",
#'   "mono" or "small". "mono" is for values that align by character:
#'   timecodes, file listings, hashes. "small" is fine print
#' @param id character element ID
#' @return A UI component
#' @examples
#' txt("Ready.")
#' txt("optional", variant = "muted")
#' @export
txt <- function(value, variant = "normal", id = NULL) {
    component("text", value = value, variant = variant, id = id)
}

#' Create a heading
#'
#' The level is a number rather than a tag name, so a client that has
#' no h1..h6 can map it onto its own type scale.
#'
#' @param value character heading text
#' @param level integer 1 to 4
#' @param id character element ID
#' @return A UI component
#' @examples
#' heading("Results", level = 2L)
#' @export
heading <- function(value, level = 2L, id = NULL) {
    component("heading", value = value, level = level, id = id)
}

#' Create a hyperlink
#'
#' @param value character link text
#' @param href character target URL
#' @param external logical open outside the app; a native client hands
#'   this to the system browser
#' @param children list of components, for a link around something
#'   that is not text (a logo, say). Give `value` or `children`, never
#'   both. A list rather than `...` because `value` comes first
#'   positionally: an unnamed child would bind to it instead
#' @return A UI component
#' @examples
#' link("cornball.ai", "https://cornball.ai", external = TRUE)
#' link(href = "https://cornball.ai",
#'      children = list(image("/static/logo.png")))
#' @export
link <- function(value = NULL, href, external = FALSE, children = NULL) {
    component("link", value = value, href = href, external = external,
              children = children)
}

#' Create an icon
#'
#' The name is a token, not artwork: each frontend supplies its own
#' glyph. An unmapped name renders a visible placeholder rather than
#' nothing, so a typo shows up.
#'
#' @param name character icon name, e.g. "play", "trash", "download"
#' @param size integer pixel size
#' @return A UI component
#' @examples
#' icon("play")
#' @export
icon <- function(name, size = 16L) {
    component("icon", name = name, size = size)
}

#' Create a horizontal rule
#'
#' @param label character text shown in the rule, e.g. "or"
#' @return A UI component
#' @examples
#' divider()
#' divider(label = "or")
#' @export
divider <- function(label = NULL) {
    component("divider", label = label,
              variant = if (is.null(label)) "line" else "labelled")
}

#' Create empty space
#'
#' Sized in theme spacing units rather than pixels, so it scales with
#' the theme instead of pinning a frontend to CSS lengths.
#'
#' @param size integer multiples of the theme's spacing unit
#' @return A UI component
#' @examples
#' spacer(2L)
#' @export
spacer <- function(size = 1L) {
    component("spacer", size = size)
}

#' Arrange children in a horizontal row
#'
#' Note: masks base::row() (matrix row indices) when glinty is
#' attached, the same way page() masks utils::page(); call base::row()
#' qualified if you need it.
#'
#' @param ... child components
#' @param gap integer space between children, in pixels
#' @param align character "start", "center", "end" or "stretch";
#'   "stretch" makes every child as tall as the tallest, which is what
#'   side-by-side panels want
#' @param grow integer share of the parent's spare space; 0 or NULL
#'   takes none. A row of one grown child and one fixed-width child is
#'   the sidebar-plus-content shape
#' @param width integer fixed width in pixels
#' @param id character element ID
#' @return A UI component
#' @examples
#' row(button("a", "A"), button("b", "B"), gap = 12L)
#' @export
row <- function(..., gap = NULL, align = NULL, grow = NULL, width = NULL,
                id = NULL) {
    component("row", children = list(...), gap = gap, align = align,
              grow = grow, width = width, id = id)
}

#' Arrange children in a vertical column
#'
#' @param ... child components
#' @param gap integer space between children, in pixels
#' @param grow integer share of the parent's spare space; 0 or NULL
#'   takes none
#' @param width integer fixed width in pixels
#' @param scroll logical scroll overflowing content instead of growing.
#'   A grown, scrolling column inside `panel(fill = TRUE)` is the
#'   message-list shape: it takes the panel's spare height and scrolls
#'   what does not fit
#' @param id character element ID
#' @return A UI component
#' @examples
#' column(heading("Stack"), text_output("a"), text_output("b"))
#' @export
column <- function(..., gap = NULL, grow = NULL, width = NULL,
                   scroll = FALSE, id = NULL) {
    component("column", children = list(...), gap = gap, grow = grow,
              width = width, scroll = scroll, id = id)
}

#' Group children in a container
#'
#' @param ... child components
#' @param variant character "plain", "card" or "sidebar"
#' @param title character heading shown above the contents
#' @param grow integer share of the parent's spare space; 0 or NULL
#'   takes none
#' @param width integer fixed width in pixels
#' @param fill logical hand the panel's height to its children, so one
#'   of them can grow into it. Without it a panel is as tall as its
#'   content and a child's `grow` has nothing to take
#' @param id character element ID
#' @return A UI component
#' @examples
#' panel(txt("body"), variant = "card", title = "Results")
#' panel(column(text_output("log"), grow = 1L, scroll = TRUE),
#'       fill = TRUE)
#' @export
panel <- function(..., variant = "plain", title = NULL, grow = NULL,
                  width = NULL, fill = FALSE, id = NULL) {
    component("panel", children = list(...), variant = variant,
              title = title, grow = grow, width = width, fill = fill,
              id = id)
}

#' A picture that is part of the UI
#'
#' For a logo or a static illustration. An image the *server* produces
#' is `image_output()` plus `render_plot()` or `render_image()`; this
#' is the one that is simply there.
#'
#' @param src character URL or data URI
#' @param alt character alternative text
#' @param width,height integer pixel size
#' @return A UI component
#' @examples
#' image("/static/logo.png", alt = "cornball.ai", width = 32L)
#' @export
image <- function(src, alt = "", width = NULL, height = NULL) {
    component("image", src = src, alt = alt, width = width, height = height)
}

#' A section the user can fold away
#'
#' `<details>` in the browser, an `ExpansionTile` in Flutter: the
#' interaction is native to both, so nothing has to be rebuilt out of
#' a button and a hidden div.
#'
#' @param ... child components
#' @param title character the always-visible summary line
#' @param open logical start unfolded
#' @param id character element ID
#' @return A UI component
#' @examples
#' collapse(slider_input("speed", "Speed", 0.5, 2), title = "Parameters")
#' @export
collapse <- function(..., title, open = FALSE, id = NULL) {
    component("collapse", children = list(...), title = title, open = open,
              id = id)
}
