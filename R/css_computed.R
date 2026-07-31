# Reading the cascade result instead of the source.
#
# css_variant_conflicts() looks at one shape -- a rule whose selector
# is a bare base class -- because that is the shape that has shipped
# twice and it needs nothing but a file. Its own documentation lists
# what it therefore cannot see, and the first item is the one that
# matters: `.g-btn:hover { ... }` really does overrule
# `.g-btn-primary:hover`, and no amount of reading selectors line by
# line will say so without reimplementing the cascade.
#
# So ask the thing that already implements it. Render the components,
# load the stylesheets in the order a real page loads them, and read
# getComputedStyle() out of a headless browser.
#
# Two ideas make it work:
#
#   - **Differential.** The page is rendered twice, once with glinty's
#     stylesheet alone and once with the app's on top, and only a
#     difference between the two is a finding. Asking "are these
#     variants distinguishable" of a single page would need a list of
#     what glinty's own stylesheet distinguishes, which is one more
#     thing to keep in step with the stylesheet. The baseline is that
#     list, computed fresh every run.
#
#   - **States as classes.** :hover cannot be queried without driving
#     the browser over its debug protocol, so the stylesheets are
#     rewritten first: `:hover` becomes `.g-force-hover`. A
#     pseudo-class and a class have the same specificity, so the
#     cascade resolves exactly as it did, and the state can be forced
#     by putting the class on the element.

#' Which states the probe forces
#'
#' :hover, :focus and :active are the ones a variant defines a
#' treatment for. `:focus-visible` rewrites to
#' `.g-force-focus-visible`, which nothing carries, so rules written
#' against it are not exercised -- a gap worth knowing rather than a
#' wrong answer.
#'
#' @keywords internal
COMPUTED_STATES <- c("hover", "focus", "active")

#' Rewrite state pseudo-classes as classes of equal specificity
#'
#' `.g-btn:hover` and `.g-btn.g-force-hover` are both one class plus
#' one class as far as the cascade is concerned, so swapping them
#' changes which elements match and nothing else. Pseudo-*elements*
#' are left alone: `::after` counts as an element, and `:` followed by
#' `:` never matches these patterns anyway.
#'
#' @param css character stylesheet text
#' @return the same text with state pseudo-classes rewritten
#' @keywords internal
css_force_states <- function(css) {
    for (state in COMPUTED_STATES) {
        css <- gsub(paste0("(?<!:):", state, "\\b"),
                    paste0(".g-force-", state), css, perl = TRUE)
    }
    css
}

#' The longhand properties a shorthand resolves to
#'
#' getComputedStyle() answers for longhands; a stylesheet writes
#' shorthands. Reading `background` back would compare a string the
#' browser assembles rather than the values that actually differ.
#'
#' @param props character properties as written in the stylesheet
#' @return character longhand property names
#' @keywords internal
computed_longhands <- function(props) {
    map <- list(
        background = c("background-color", "background-image"),
        border = c("border-top-color", "border-top-width",
                   "border-top-style"),
        "border-color" = "border-top-color",
        "border-bottom" = c("border-bottom-color", "border-bottom-width"),
        padding = c("padding-top", "padding-left"),
        margin = c("margin-top", "margin-left"),
        font = c("font-size", "font-weight", "font-family")
    )
    out <- character(0)
    for (prop in props) {
        out <- c(out, if (is.null(map[[prop]])) prop else map[[prop]])
    }
    # Custom properties resolve to whatever they were set to and say
    # nothing about what the element looks like.
    unique(out[!startsWith(out, "--")])
}

#' One probe element per variant, from the real lowering
#'
#' The markup comes from `component_to_html()` rather than being
#' written out here, so a change to how a button lowers cannot leave
#' this probing something the app never renders.
#'
#' @return list of list(base, variants, html) entries
#' @keywords internal
computed_probe_families <- function() {
    make <- list(
        "g-btn" = function(v) button("probe", "Button", variant = v),
        "g-panel" = function(v) panel(txt("Panel"), variant = v),
        "g-text" = function(v) txt("Text", variant = v),
        "g-divider" = function(v) {
            if (identical(v, "labelled")) divider("Label") else divider()
        }
    )
    families <- css_variant_families()
    out <- list()
    for (base in names(families)) {
        if (is.null(make[[base]])) {
            next
        }
        variants <- sub(paste0("^", base, "-"), "", families[[base]])
        out[[length(out) + 1L]] <- list(base = base, variants = variants,
                                        make = make[[base]])
    }
    out
}

#' Tag one rendered component as a probe, in a forced state
#'
#' String surgery on markup, which is only safe because this is markup
#' glinty just produced: the outermost element is the component's own,
#' and it always carries a class. Both edits are checked rather than
#' assumed -- a lowering that stopped emitting a class attribute would
#' otherwise leave a probe that silently measures nothing.
#'
#' @param html character one component's HTML
#' @param id character probe id, read back by the page script
#' @param force character state class to add, or NULL
#' @return character HTML
#' @keywords internal
probe_element <- function(html, id, force = NULL) {
    if (!is.null(force)) {
        if (!grepl('class="', html, fixed = TRUE)) {
            stop("probe markup carries no class attribute: ", html,
                 call. = FALSE)
        }
        html <- sub('class="', paste0('class="g-force-', force, " "), html,
                    fixed = TRUE)
    }
    out <- sub("^<([a-z][a-z0-9]*)",
               paste0("<\\1 data-probe=\"", id, "\""), html)
    if (identical(out, html)) {
        stop("probe markup does not open with a tag: ", html, call. = FALSE)
    }
    out
}

#' Build the page the browser measures
#'
#' @param app_css character app stylesheet text, or NULL for the
#'   baseline page
#' @param glinty_css character glinty stylesheet text
#' @param families list from computed_probe_families()
#' @param props named list of properties to read, per base class
#' @return character HTML document
#' @keywords internal
computed_probe_html <- function(app_css, glinty_css, families, props) {
    parts <- character(0)
    plan <- list()
    for (family in families) {
        for (variant in family$variants) {
            for (state in c("", COMPUTED_STATES)) {
                id <- paste(family$base, variant, state, sep = "|")
                html <- component_to_html(family$make(variant))
                parts <- c(parts, probe_element(html, id,
                                                if (nzchar(state)) state))
            }
        }
        # I() so a family or property list of length one still
        # crosses as an array: auto_unbox would make it a string, and
        # the page would iterate its characters.
        plan[[family$base]] <- list(base = family$base,
                                    variants = I(family$variants),
                                    properties = I(props[[family$base]]))
    }
    # c() then collapse, not paste() of several vectors: paste()
    # recycles, so the plan would be repeated onto every line of the
    # script and `const plan` redeclared fifty times.
    script <- paste(c(
                      paste0("const plan = ", as.character(jsonlite::toJSON(
                    unname(plan), auto_unbox = TRUE)), ";"),
                      readLines(system.file("tools", "computed-style.js",
                                            package = "glinty"), warn = FALSE)
    ), collapse = "\n")
    paste0(
        "<!doctype html><html><head><meta charset=\"utf-8\">\n",
        "<style>\n", css_force_states(glinty_css), "\n</style>\n",
        if (is.null(app_css)) {
            ""
        } else {
            paste0("<style>\n", css_force_states(app_css), "\n</style>\n")
        },
        "</head><body>\n", paste(parts, collapse = "\n"),
        "\n<pre id=\"glinty-computed\"></pre>\n",
        "<script>\n", script, "\n</script>\n</body></html>"
    )
}

#' Measure one page in a headless browser
#'
#' @param html character document
#' @param chrome character browser binary
#' @param dir character working directory for the run
#' @param tag character file name stem
#' @return named list: "base|state|property" -> list(distinct, values)
#' @keywords internal
computed_measure <- function(html, chrome, dir, tag) {
    page <- file.path(dir, paste0(tag, ".html"))
    writeLines(html, page)
    out <- suppressWarnings(system2(chrome, c(
                "--headless", "--disable-gpu", "--no-sandbox",
                "--no-first-run", "--disable-extensions",
                paste0("--user-data-dir=", file.path(dir, paste0(tag, "-profile"))),
                "--virtual-time-budget=2000", "--dump-dom",
                paste0("file://", page)
            ), stdout = TRUE, stderr = FALSE))
    dom <- paste(out, collapse = "\n")
    found <- regmatches(dom, regexpr(
            "<pre id=\"glinty-computed\">.*?</pre>", dom, perl = TRUE))
    if (length(found) == 0L) {
        stop("the browser returned a page without the probe results; ",
             "it may have failed to start", call. = FALSE)
    }
    json <- sub("^<pre id=\"glinty-computed\">", "", found)
    json <- sub("</pre>$", "", json)
    for (pair in list(c("&lt;", "<"), c("&gt;", ">"), c("&quot;", "\""),
                      c("&amp;", "&"))) {
        json <- gsub(pair[1], pair[2], json, fixed = TRUE)
    }
    if (!nzchar(trimws(json))) {
        stop("the browser returned empty probe results", call. = FALSE)
    }
    jsonlite::fromJSON(json, simplifyVector = FALSE)
}

#' Find a browser to measure with
#'
#' @param chrome character explicit binary, or NULL to search
#' @return character path, or NULL when there is none
#' @keywords internal
find_chrome <- function(chrome = NULL) {
    if (!is.null(chrome)) {
        return(chrome)
    }
    named <- Sys.getenv("GLINTY_CHROME", "")
    if (nzchar(named)) {
        return(named)
    }
    for (binary in c("google-chrome", "google-chrome-stable", "chromium",
                     "chromium-browser")) {
        found <- Sys.which(binary)
        if (nzchar(found)) {
            return(unname(found))
        }
    }
    NULL
}

#' What an app's stylesheet cancels, as the browser resolves it
#'
#' Renders every variant of every family twice -- once under glinty's
#' stylesheet alone, once with the app's loaded after it, the way a
#' real page loads them -- and reports each property where variants
#' the baseline told apart have collapsed to one value.
#'
#' This is the check `css_variant_conflicts()` documents itself as not
#' being. It reads the cascade's answer rather than the source, so it
#' sees `!important`, specificity ties, shorthand against longhand,
#' and the `:hover` case that motivated it. It needs a browser, and
#' says so rather than passing when there is none.
#'
#' States are forced by rewriting `:hover` and friends into classes of
#' equal specificity, so hover, focus and active are measured
#' alongside the default state.
#'
#' @param path character path to the app's stylesheet
#' @param chrome character browser binary; NULL searches
#'   `GLINTY_CHROME`, then google-chrome and chromium on the PATH
#' @param glinty_css character glinty.css contents, for testing this
#'   function itself; read from the installed package when absent
#' @return character vector of findings, empty when there are none
#' @examples
#' \dontrun{
#' css <- system.file("app/www/styles.css", package = "myapp")
#' expect_equal(glinty::css_computed_conflicts(css), character(0))
#' }
#' @export
css_computed_conflicts <- function(path, chrome = NULL, glinty_css = NULL) {
    browser_bin <- find_chrome(chrome)
    if (is.null(browser_bin)) {
        stop("no browser found: css_computed_conflicts() reads ",
             "getComputedStyle() out of a real one. Install Google Chrome ",
             "or Chromium, or name a binary with GLINTY_CHROME.",
             call. = FALSE)
    }
    if (is.null(glinty_css)) {
        glinty_css <- readLines(system.file("www", "glinty.css",
                                            package = "glinty"), warn = FALSE)
    }
    glinty_css <- paste(glinty_css, collapse = "\n")
    app_css <- paste(readLines(path, warn = FALSE), collapse = "\n")

    families <- computed_probe_families()
    variant_props <- css_variant_properties(glinty_css)
    props <- lapply(variant_props, computed_longhands)
    families <- Filter(function(f) length(props[[f$base]]) > 0L, families)
    if (length(families) == 0L) {
        return(character(0))
    }

    dir <- file.path(tempdir(), paste0("glinty-computed-", Sys.getpid()))
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)

    baseline <- computed_measure(
        computed_probe_html(NULL, glinty_css, families, props),
        browser_bin, dir, "baseline")
    withapp <- computed_measure(
        computed_probe_html(app_css, glinty_css, families, props),
        browser_bin, dir, "app")

    computed_findings(baseline, withapp)
}

#' Turn two measurements into findings
#'
#' A finding is a property the baseline told apart and the app made
#' identical. The other direction -- an app introducing a distinction
#' glinty did not make -- is an app styling its variants, which is the
#' whole point of variants.
#'
#' @param baseline list from computed_measure() without the app CSS
#' @param withapp list from computed_measure() with it
#' @return character vector of findings
#' @keywords internal
computed_findings <- function(baseline, withapp) {
    findings <- character(0)
    for (key in names(baseline)) {
        before <- baseline[[key]]
        after <- withapp[[key]]
        if (is.null(after) || !isTRUE(before$distinct > 1L)) {
            next
        }
        if (after$distinct > 1L) {
            next
        }
        parts <- strsplit(key, "|", fixed = TRUE)[[1]]
        findings <- c(findings, sprintf(
                ".%s-* all share one %s%s (%s) where glinty gives them %d: the variant stops working",
                parts[1], parts[3],
                if (length(parts) > 2L && nzchar(parts[2])) {
                    paste0(" on :", parts[2])
                } else {
                    ""
                },
                after$values[[1]], before$distinct
            ))
    }
    sort(findings)
}
