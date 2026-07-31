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
# Which classes form a variant family is derived from the lowering --
# rendered, not restated. It used to be a stated table, and the table
# was wrong in three places at once, none of which the tests could see
# because they checked it against the schema it had been built from.

#' Empty out anything a semicolon or colon can hide inside
#'
#' Declarations are found by splitting on `;` and `:`, and both appear
#' inside values that are none of this reader's business:
#'
#' \preformatted{
#' background: url("data:image/svg+xml;utf8,<svg/>");
#' content: ";";
#' }
#'
#' glinty's own stylesheet is full of the first: every icon is a
#' `mask-image` data URI. Split naively, those produce declarations that
#' are not ones -- `utf8,<svg/>")` read as a property name.
#'
#' Only those two characters are replaced, each with one space, so the
#' string keeps its length and the block walker's character counting is
#' undisturbed. Quoted strings go first, because a url() often holds one.
#'
#' @param css character one string of CSS
#' @return the same string with string and url() contents blanked
#'
#' @keywords internal
css_blank_literals <- function(css) {
    for (pattern in c('"[^"\n]*"', "'[^'\n]*'", "url\\([^)\n]*\\)")) {
        hits <- gregexpr(pattern, css, perl = TRUE)
        found <- regmatches(css, hits)[[1]]
        if (length(found) == 0L) {
            next
        }
        # Only the two characters that mean anything to this reader are
        # replaced, and each with one space. Everything else stays, so
        # the string is the same length and brace depth is unchanged --
        # which matters, because the block walker counts characters.
        regmatches(css, hits) <- list(gsub("[;:]", " ", found))
    }
    css
}

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
    # (?s) so . matches a newline. Without it a multi-line comment was
    # not stripped at all, and glinty.css is full of them: the whole
    # comment came back glued to the property after it, so that real
    # property was lost rather than merely joined by a phantom.
    css <- gsub("(?s)/\\*.*?\\*/", "", css, perl = TRUE)
    css <- css_blank_literals(css)

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

#' One component per variant family, built the way an app builds it
#'
#' The families are derived from what these render, so this list is
#' the only thing stated: which components carry variants at all. The
#' schema supplies the values; the lowering supplies the classes.
#'
#' @return named list: component name -> function(variant) -> component
#' @keywords internal
CSS_VARIANT_BUILDERS <- list(
                             button = function(v) button("probe", "Button", variant = v),
                             download_button = function(v) download_button("probe", "D", variant = v),
                             panel = function(v) panel(txt("Panel"), variant = v),
                             text = function(v) txt("Text", variant = v),
                             text_output = function(v) text_output("probe", variant = v),
                             divider = function(v) {
    if (identical(v, "labelled")) divider("L") else divider()
}
)

#' The classes on a rendered component's outermost element
#'
#' @param html character one component's HTML
#' @return character class names, empty when there are none
#' @keywords internal
html_outer_classes <- function(html) {
    open <- regmatches(html, regexpr("^<[a-z][a-z0-9]*[^>]*", html))
    if (length(open) == 0L) {
        return(character(0))
    }
    attr <- regmatches(open, regexpr("class=\"[^\"]*\"", open))
    if (length(attr) == 0L) {
        return(character(0))
    }
    parts <- strsplit(sub("^class=\"", "", sub("\"$", "", attr)), " +")[[1]]
    parts[nzchar(parts)]
}

#' The base classes that carry variants, and the variants they carry
#'
#' Derived from the lowering: every variant of every component that
#' has them is rendered, and the classes they all share are the base
#' while the rest tell them apart.
#'
#' This used to be a stated table, and the table was wrong. It said
#' `text`'s variants were `.g-text-muted` and `.g-text-strong`;
#' `html_text()` emits `g-text g-muted` and `g-text g-strong`. It gave
#' `divider` a `.g-divider-line`; the line case adds no class at all.
#' It had no entry for `text_output`, which lowers to `.g-output`
#' rather than `.g-text`. So `.g-text { color: red }` -- the exact
#' shape these guards exist to catch -- went unreported, because
#' `color` was never in the property set being compared.
#'
#' The tests checked the table against `COMPONENT_SCHEMA`, which is
#' where the variant *values* come from, so a table built out of those
#' values agreed with itself and the markup was never consulted. It is
#' computed from the markup now. Deriving from the *stylesheet* would
#' still be wrong -- that invents families like `.g-tab-nav` and needs
#' a blocklist that grows with the CSS -- but the lowering is the
#' authority on which classes exist, and it is the thing that must not
#' drift from this.
#'
#' @return named list: base class -> its variant classes
#'
#' @keywords internal
#' Which classes tell each component's variants apart
#'
#' The single derivation both guards read: what the lowering emits for
#' every variant of every component that has them, split into the
#' classes they all share and the classes that differ.
#'
#' @return named list: component -> list(component, values, shared,
#'   telling)
#' @keywords internal
css_variant_components <- function() {
    out <- list()
    for (name in names(CSS_VARIANT_BUILDERS)) {
        values <- COMPONENT_SCHEMA[[name]]$variant$values
        if (is.null(values)) {
            stop("component '", name, "' has no variant in COMPONENT_SCHEMA",
                 call. = FALSE)
        }
        classes <- lapply(values, function(v) {
            html_outer_classes(component_to_html(
                    CSS_VARIANT_BUILDERS[[name]](v)))
        })
        shared <- Reduce(intersect, classes)
        if (length(shared) == 0L) {
            stop("component '", name, "' has no class common to all its ",
                 "variants, so it has no base class to guard", call. = FALSE)
        }
        telling <- setdiff(unique(unlist(classes)), shared)
        if (length(telling) == 0L) {
            next
        }
        out[[name]] <- list(component = name, values = values,
                            shared = sort(shared), telling = sort(telling))
    }
    out
}

#' @rdname css_variant_components
#' @keywords internal
css_variant_families <- function() {
    out <- list()
    for (entry in css_variant_components()) {
        # Registered under every class all its variants share, not
        # just one. download_button lowers to `g-btn g-btn-<variant>
        # g-download`, and a rule on `.g-download` cancels the variants
        # exactly as a rule on `.g-btn` does.
        for (base in entry$shared) {
            out[[base]] <- sort(unique(c(out[[base]], entry$telling)))
        }
    }
    out
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

#' A bare-base-class preflight check, not a cascade validator
#'
#' glinty emits `g-btn g-btn-<variant>`, and an app stylesheet loads
#' after glinty's. A rule on the *base* class therefore cancels every
#' variant at equal specificity, silently: nothing fails, and the app
#' just has one kind of button.
#'
#' **What it looks at is exactly one shape**: a selector that is a bare
#' base class, `.g-btn`. Deliberately narrow, because narrow is what
#' makes it free of false positives -- an app writing `#header .g-btn`
#' or `.g-btn.g-btn-ghost` is beating a variant on specificity on
#' purpose, and saying so.
#'
#' What it therefore does **not** see:
#'
#' - `.g-btn:hover`, `.g-btn:focus` and any other compound or
#'   pseudo-class selector. A hover rule on the base class really does
#'   overrule a variant's hover, and this will not tell you.
#' - a conflict in the other direction, where glinty's own stylesheet
#'   overrules something the app set. `.g-image { height: auto }`
#'   beating `image(height = 32)` was that, and this would not have
#'   caught it.
#' - anything that is not a variant family: layout, spacing, a theme
#'   token overridden to something unreadable.
#'
#' For those, read the cascade result rather than the source: load the
#' page in a headless browser and assert `getComputedStyle()`. That
#' catches every shape and needs a browser; this catches the one shape
#' that has actually shipped twice and needs nothing.
#'
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
    # The classes to name in the message. `.<base>-*` was a pattern
    # invented from the base name, and now that the families are
    # derived it invents names that do not exist: `.g-text-*` for a
    # family whose members are `.g-muted` and `.g-strong`,
    # `.g-download-*` for one whose members are `.g-btn-*`. Naming the
    # real ones is the whole point of having derived them.
    classes <- css_variant_families()
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
            variants <- paste0(".", classes[[base]], collapse = ", ")
            findings <- c(findings, sprintf(
                    "%s sets %s, which %s also set: the base rule wins and the variant stops working",
                    sel, paste(sort(clash), collapse = ", "), variants
                ))
        }
    }
    findings
}
