# Theme tokens. A closed set, not a stylesheet: the browser turns
# them into CSS custom properties, Flutter into ThemeData, and any
# future frontend into whatever it styles with. Apps that want more
# than tokens ship a stylesheet, which only the browser sees.

THEME_COLOR_NAMES <- c("primary", "on_primary", "surface", "background",
                       "text", "muted", "border", "danger")

#' glinty's default look, as explicit tokens
#'
#' @return named list of token defaults
#' @keywords internal
theme_defaults <- function() {
    list(
         colors = list(primary = "#2456d6", on_primary = "#ffffff",
                       surface = "#ffffff", background = "#ffffff",
                       text = "#1a1a1a", muted = "#6a6a6a",
                       border = "#d0d0d5", danger = "#b3261e"),

         spacing = 4,
         radius = 6,
         font = list(body = "system-ui", mono = "ui-monospace", size = 16)
    )
}

#' Define an app theme
#'
#' A closed set of semantic tokens, sent once in `welcome` and applied
#' by every frontend: the browser emits them as CSS custom properties
#' (and the served page carries them inline, so the first paint is
#' already themed), a Flutter client maps them onto ThemeData.
#' Partial arguments merge over glinty's defaults, so
#' `app_theme(colors = list(primary = "#7c3aed"))` changes one thing.
#'
#' An app with no theme gets each frontend's own defaults instead --
#' in the browser that includes the stylesheet's automatic dark mode,
#' which a supplied theme replaces with exactly its tokens.
#'
#' Named app_theme() rather than theme() for the same reason text()
#' became txt(): theme() would mask ggplot2::theme() the moment an
#' app draws a styled plot, and breaking plotting is the one cost
#' glinty must never charge.
#'
#' @param colors named list over primary, on_primary, surface,
#'   background, text, muted, border, danger; values are
#'   "#rrggbb" (or "#rrggbbaa") strings
#' @param spacing numeric base spacing unit in logical pixels;
#'   spacer() sizes are multiples of it
#' @param radius numeric corner radius in logical pixels
#' @param font named list over body, mono (font family names) and
#'   size (numeric, logical pixels)
#' @return a glinty_theme
#' @examples
#' app_theme(colors = list(primary = "#7c3aed"), radius = 10)
#' @export
app_theme <- function(colors = list(), spacing = NULL, radius = NULL,
                      font = list()) {
    base <- theme_defaults()

    check_named_subset(colors, THEME_COLOR_NAMES, "colors")
    for (nm in names(colors)) {
        val <- colors[[nm]]
        if (!is.character(val) || length(val) != 1L ||
            !grepl("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$", val)) {
            stop("app_theme() colors$", nm,
                 " must be a \"#rrggbb\" or \"#rrggbbaa\" string",
                 call. = FALSE)
        }
        base$colors[[nm]] <- tolower(val)
    }

    if (!is.null(spacing)) {
        base$spacing <- check_theme_number(spacing, "spacing", max = 64)
    }
    if (!is.null(radius)) {
        base$radius <- check_theme_number(radius, "radius", max = 64)
    }

    check_named_subset(font, c("body", "mono", "size"), "font")
    for (nm in intersect(names(font), c("body", "mono"))) {
        val <- font[[nm]]
        # One family name (or a CSS generic like system-ui), and
        # nothing that could carry CSS syntax: these tokens are
        # interpolated into the served style block, so the character
        # set is the injection surface. The client refuses the same
        # characters, and validating here keeps the first paint and
        # the hydrated state identical.
        if (!is.character(val) || length(val) != 1L || !nzchar(val) ||
                !grepl("^[A-Za-z0-9][A-Za-z0-9 _-]*$", val)) {
            stop("app_theme() font$", nm,
                 " must be a single font family name ",
                 "(letters, digits, spaces, hyphens)", call. = FALSE)
        }
        base$font[[nm]] <- val
    }
    if (!is.null(font$size)) {
        base$font$size <- check_theme_number(font$size, "font$size",
            min = 6, max = 64)
    }

    structure(base, class = "glinty_theme")
}

#' Require names to come from a closed set
#'
#' @param x a named list
#' @param allowed character vector of valid names
#' @param what character argument name for the error
#' @return invisible(NULL)
#' @keywords internal
check_named_subset <- function(x, allowed, what) {
    if (length(x) == 0L) {
        return(invisible(NULL))
    }
    if (!is.list(x) || is.null(names(x)) || any(!nzchar(names(x)))) {
        stop("app_theme() ", what, " must be a named list", call. = FALSE)
    }
    unknown <- setdiff(names(x), allowed)
    if (length(unknown) > 0L) {
        stop("app_theme() ", what, " got unknown token(s): ",
             paste(unknown, collapse = ", "), ". Allowed: ",
             paste(allowed, collapse = ", "), call. = FALSE)
    }
    invisible(NULL)
}

#' Validate one numeric theme token
#'
#' @param x candidate value
#' @param what character token name for the error
#' @param min,max numeric bounds
#' @return the value as a plain number
#' @keywords internal
check_theme_number <- function(x, what, min = 0, max = 64) {
    x <- suppressWarnings(as.numeric(x))
    if (length(x) != 1L || !is.finite(x) || x < min || x > max) {
        stop("app_theme() ", what, " must be a number in [", min, ", ",
             max, "]", call. = FALSE)
    }
    x
}

#' The wire form of a theme
#'
#' @param th a glinty_theme
#' @return plain list for JSON
#' @keywords internal
theme_wire <- function(th) {
    unclass_recursive(unclass(th))
}

#' CSS custom property name for a theme token
#'
#' One mapping, used by both the server-side style block and the
#' client's welcome handler -- the token names are the contract, the
#' var names are the browser lowering of it.
#'
#' @param name character token name (underscores)
#' @return character CSS custom property name
#' @keywords internal
theme_var <- function(name) {
    paste0("--g-", gsub("_", "-", name, fixed = TRUE))
}

#' Serialize a theme as a :root CSS block
#'
#' Emitted into the served document so the first paint is themed
#' before any socket work; welcome repeats the same tokens and the
#' client re-applies them, so a cached page self-heals.
#'
#' @param th a glinty_theme
#' @return character CSS
#' @keywords internal
theme_css <- function(th) {
    parts <- character(0L)
    for (nm in names(th$colors)) {
        parts <- c(parts, paste0(theme_var(nm), ":", th$colors[[nm]]))
    }
    parts <- c(parts, paste0("--g-space:", th$spacing, "px"),
               paste0("--g-radius:", th$radius, "px"),
               paste0("--g-font-body:", th$font$body),
               paste0("--g-font-mono:", th$font$mono),
               paste0("--g-font-size:", th$font$size, "px"))
    paste0(":root{", paste(parts, collapse = ";"), "}")
}
