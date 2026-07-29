# Catching the one kind of bug the test suites cannot see.
#
# A stylesheet conflict has no failing assertion. Every rule is valid,
# every lowering is correct, nothing errors, and the page is wrong.
# Two landed in one afternoon of looking at rendered pages after
# fifteen review rounds had found neither:
#
#   .g-image { height: auto }   in glinty, overruling image(height = 32)
#   .g-btn { background: ... }  in an app, overruling .g-btn-ghost
#
# The second is the general shape: glinty emits `g-btn g-btn-<variant>`,
# an app styles the base class, and because app CSS loads after
# glinty's at equal specificity the base rule cancels every variant.
# The app author never sees a variant stop working -- they see a page
# where all the buttons look the same, which is easy to read as a
# design choice.
#
# Which classes form a variant family is stated here, beside a check
# that the statement matches COMPONENT_SCHEMA and the stylesheet, so
# the three cannot drift apart quietly.

#' Read declarations out of a stylesheet, by selector
#'
#' A deliberately small CSS reader, not a CSS parser: comments are
#' stripped, at-rule bodies are walked into so a media query's contents
#' count as rules, and declarations are split on `;` and `:`. Enough
#' for hand-written stylesheets, which is all this is asked to read.
#'
#' @param text character lines, or one string, of CSS
#' @return list of list(selectors = character, properties = character)
#'
#' @keywords internal
css_rules <- function(text) {
    css <- paste(text, collapse = "\n")
    css <- gsub("/\\*.*?\\*/", "", css, perl = TRUE)

    out <- list()
    parse_block <- function(s) {
        chars <- strsplit(s, "", fixed = TRUE)[[1]]
        start <- 1L
        i <- 1L
        n <- length(chars)
        while (i <= n) {
            if (chars[i] == "{") {
                selector <- trimws(paste(chars[start:(i - 1L)], collapse = ""))
                depth <- 1L
                j <- i + 1L
                while (j <= n && depth > 0L) {
                    if (chars[j] == "{") {
                        depth <- depth + 1L
                    }
                    if (chars[j] == "}") {
                        depth <- depth - 1L
                    }
                    j <- j + 1L
                }
                body <- paste(chars[(i + 1L):(j - 2L)], collapse = "")
                if (startsWith(selector, "@")) {
                    # A media query holds rules, not declarations. Its
                    # contents override the same properties, so they
                    # have to count.
                    parse_block(body)
                } else if (nzchar(selector)) {
                    decls <- trimws(strsplit(body, ";", fixed = TRUE)[[1]])
                    decls <- decls[nzchar(decls)]
                    props <- trimws(sub(":.*$", "", decls))
                    out[[length(out) + 1L]] <<- list(
                        selectors = trimws(strsplit(selector, ",",
                                fixed = TRUE)[[1]]),
                        properties = props[nzchar(props)]
                    )
                }
                start <- j
                i <- j
            } else {
                i <- i + 1L
            }
        }
    }
    parse_block(css)
    out
}

#' The base classes that carry variants, and the variants they carry
#'
#' Stated, not derived. An earlier version of this read the families out
#' of glinty.css by looking for `.g-x` with `.g-x-*` siblings, which
#' invents families that are not ones -- `.g-tab-nav` is a piece of a
#' tabset rather than a flavour of it, `.g-radio-group` is a container
#' rather than a kind of radio -- and then needs a blocklist that grows
#' every time the stylesheet does.
#'
#' Which classes are a variant family is a fact about the lowering that
#' emits them (see `html_button`, `html_panel`), so it belongs beside
#' the lowering. ``css_variant_classes_styled()`` checks this against the
#' stylesheet, so the two cannot drift apart quietly.
#'
#' @return named list: base class -> its variant classes
#'
#' @keywords internal
css_variant_families <- function() {
    variants <- function(base, values) {
        stats::setNames(list(paste0(base, "-", values)), base)
    }
    c(
        # button and download_button share the class and the variant set
        variants("g-btn",
                 c("default", "primary", "secondary", "danger", "ghost")),
        variants("g-panel", c("plain", "card", "sidebar")),
        # text and text_output; heading is text's only extra
        variants("g-text", c("normal", "muted", "strong", "heading")),
        variants("g-divider", c("line", "labelled"))
    )
}

#' Which variant classes glinty's own stylesheet gives a treatment
#'
#' Not every variant needs a rule: `.g-btn-default` and `.g-text-normal`
#' are the unstyled case on purpose. This exists so a variant class that
#' is *named* here but spelled differently in the stylesheet shows up as
#' a mismatch rather than as a guard that silently checks nothing.
#'
#' @param css character glinty.css contents; read from the installed
#'   package when absent
#' @return character vector of variant classes the stylesheet styles
#'
#' @keywords internal
css_variant_classes_styled <- function(css = NULL) {
    if (is.null(css)) {
        css <- readLines(system.file("www", "glinty.css", package = "glinty"),
                         warn = FALSE)
    }
    styled <- character(0)
    for (rule in css_rules(css)) {
        for (sel in rule$selectors) {
            for (cls in regmatches(sel, gregexpr("\\.g-[a-z0-9-]+",
                        sel))[[1]]) {
                styled <- c(styled, sub("^\\.", "", cls))
            }
        }
    }
    all_variants <- unlist(css_variant_families(), use.names = FALSE)
    sort(unique(intersect(styled, all_variants)))
}

#' Properties glinty's variants set, per family
#'
#' What an app's base-class rule would cancel. Read from the stylesheet
#' rather than listed, because *which* properties a variant sets is a
#' styling decision that changes freely; which classes are variants is
#' not.
#'
#' @param css character glinty.css contents; read from the installed
#'   package when absent
#' @return named list: base class -> properties its variants set
#'
#' @keywords internal
css_variant_properties <- function(css = NULL) {
    if (is.null(css)) {
        css <- readLines(system.file("www", "glinty.css", package = "glinty"),
                         warn = FALSE)
    }
    rules <- css_rules(css)
    out <- list()
    for (base in names(css_variant_families())) {
        kin <- css_variant_families()[[base]]
        props <- character(0)
        for (rule in rules) {
            hit <- any(vapply(rule$selectors, function(sel) {
                any(vapply(kin, function(k) {
                    grepl(paste0("\\.", k, "(?![a-z0-9-])"), sel, perl = TRUE)
                }, logical(1)))
            }, logical(1)))
            if (hit) {
                props <- union(props, rule$properties)
            }
        }
        if (length(props)) {
            out[[base]] <- sort(props)
        }
    }
    out
}

#' App stylesheet rules that overrule a glinty variant
#'
#' glinty emits `g-btn g-btn-<variant>`, and an app stylesheet loads
#' after glinty's. A rule on the *base* class therefore cancels every
#' variant at equal specificity, silently: nothing fails, and the page
#' just has one kind of button.
#'
#' Call this from an app's tests. An empty result is the passing case.
#'
#' @param path character path to the app's stylesheet
#' @param glinty_css character glinty.css contents, for testing this
#'   function itself; read from the installed package when absent
#' @return character vector of findings, empty when there are none
#' @examples
#' \dontrun{
#' # in inst/tinytest/test_styles.R
#' css <- system.file("app/www/styles.css", package = "myapp")
#' expect_equal(glinty::css_variant_conflicts(css), character(0))
#' }
#' @export
css_variant_conflicts <- function(path, glinty_css = NULL) {
    families <- css_variant_properties(glinty_css)
    if (length(families) == 0L) {
        return(character(0))
    }
    rules <- css_rules(readLines(path, warn = FALSE))

    findings <- character(0)
    for (rule in rules) {
        for (sel in rule$selectors) {
            # Only a bare base class. `.g-btn.g-btn-ghost` or
            # `#panel .g-btn` are more specific on purpose, and an app
            # narrowing its reach is doing the right thing.
            base <- sub("^\\.", "", sel)
            if (!base %in% names(families)) {
                next
            }
            clash <- intersect(rule$properties, families[[base]])
            if (length(clash) == 0L) {
                next
            }
            variants <- paste0(".", base, "-*")
            findings <- c(findings, sprintf(
                    "%s sets %s, which %s also sets: the base rule wins and the variant stops working",
                    sel, paste(sort(clash), collapse = ", "), variants
                ))
        }
    }
    findings
}
