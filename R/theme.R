# Theme tokens. A closed set, not a stylesheet: the browser turns
# them into CSS custom properties, Flutter into ThemeData, and any
# future frontend into whatever it styles with. Apps that want more
# than tokens ship a stylesheet, which only the browser sees.

THEME_COLOR_NAMES <- c("primary", "on_primary", "surface", "background",
                       "text", "muted", "border", "danger")

# The stylesheet's dark palette (inst/www/glinty.css), as tokens:
# what app_theme(dark = ) merges over, so a partial dark list starts
# from the same look an unthemed app gets in dark mode. Kept in step
# with the stylesheet by test_theme.R.
DARK_COLOR_DEFAULTS <- list(primary = "#6f95f5", on_primary = "#10131a",
                            surface = "#1e2128", background = "#16181d",
                            text = "#e6e6e6", muted = "#9a9aa2",
                            border = "#3a3d45", danger = "#e5484d")

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
#' which a supplied theme without `dark` replaces with exactly its
#' tokens, in both schemes. Supplying `dark` keeps automatic dark
#' mode: the frontend applies `colors` normally and `dark` when the
#' system prefers a dark scheme. There is no third state -- the
#' choice follows the system setting, and an app that supplies only
#' one palette renders it everywhere, which is today's behaviour and
#' stays available on purpose.
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
#' @param dark named list like `colors`, applied when the system
#'   prefers a dark scheme; partial values merge over glinty's dark
#'   defaults, so `dark = list()` is exactly the stock dark palette.
#'   Merging never reaches across schemes: a light `primary` says
#'   nothing about the dark one, because a colour tuned for a white
#'   surface is not a preference about black -- brand colour in dark
#'   means setting `dark$primary`. NULL (the default) keeps the
#'   supplied theme exact in both schemes
#' @return a glinty_theme
#' @examples
#' app_theme(colors = list(primary = "#7c3aed"), radius = 10)
#' app_theme(colors = list(primary = "#7c3aed"),
#'           dark = list(primary = "#a78bfa"))
#' @export
app_theme <- function(colors = list(), spacing = NULL, radius = NULL,
                      font = list(), dark = NULL) {
    base <- theme_defaults()
    base$colors <- merge_theme_colors(base$colors, colors, "colors")
    if (!is.null(dark)) {
        base$dark <- merge_theme_colors(DARK_COLOR_DEFAULTS, dark, "dark")
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

#' Validate colour tokens and merge them over a base palette
#'
#' The one loop both palettes go through, so `colors` and `dark` are
#' held to the same names and the same "#rrggbb(aa)" rule and can
#' never drift apart.
#'
#' @param base named list of complete default colours
#' @param colors named list of supplied colours
#' @param what character argument name for errors
#' @return the merged palette, values lowercased
#' @keywords internal
merge_theme_colors <- function(base, colors, what) {
    check_named_subset(colors, THEME_COLOR_NAMES, what)
    for (nm in names(colors)) {
        val <- colors[[nm]]
        if (!is.character(val) || length(val) != 1L ||
            !grepl("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$", val)) {
            stop("app_theme() ", what, "$", nm,
                 " must be a \"#rrggbb\" or \"#rrggbbaa\" string",
                 call. = FALSE)
        }
        base[[nm]] <- tolower(val)
    }
    base
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

#' Colour tokens as CSS custom property declarations
#'
#' @param colors named list of colour tokens
#' @return character vector of "--g-name:value" declarations
#' @keywords internal
theme_color_parts <- function(colors) {
    vapply(names(colors), function(nm) {
        paste0(theme_var(nm), ":", colors[[nm]])
    }, character(1L), USE.NAMES = FALSE)
}

#' Serialize a theme as CSS
#'
#' Emitted into the served document so the first paint is themed
#' before any socket work; welcome repeats the same tokens and the
#' client re-applies them, so a cached page self-heals. A theme with
#' a dark palette adds a prefers-color-scheme block after the :root
#' block -- the same shape the stylesheet's own dark mode has, in the
#' same style element, so precedence over the stylesheet and under
#' app CSS is unchanged.
#'
#' @param th a glinty_theme
#' @return character CSS
#' @keywords internal
theme_css <- function(th) {
    parts <- c(theme_color_parts(th$colors),
               paste0("--g-space:", th$spacing, "px"),
               paste0("--g-radius:", th$radius, "px"),
               paste0("--g-font-body:", th$font$body),
               paste0("--g-font-mono:", th$font$mono),
               paste0("--g-font-size:", th$font$size, "px"))
    css <- paste0(":root{", paste(parts, collapse = ";"), "}")
    if (!is.null(th$dark)) {
        css <- paste0(css, "@media (prefers-color-scheme: dark){:root{",
                      paste(theme_color_parts(th$dark), collapse = ";"),
                      "}}")
    }
    css
}
