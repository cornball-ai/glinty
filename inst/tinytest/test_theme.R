# Theme tokens: a closed set, validated at construction, carried in
# welcome, and painted into the served page.

app_theme <- glinty::app_theme
theme_css <- glinty:::theme_css
theme_wire <- glinty:::theme_wire
theme_defaults <- glinty:::theme_defaults

# --- defaults are the neutral glinty look, fully populated ---
th <- app_theme()
expect_true(inherits(th, "glinty_theme"))
expect_equal(th$colors$primary, "#2456d6")
expect_equal(sort(names(th$colors)), sort(glinty:::THEME_COLOR_NAMES))
expect_equal(th$spacing, 4)
expect_equal(th$font$size, 16)

# --- partial arguments merge over the defaults ---
th2 <- app_theme(colors = list(primary = "#7C3AED"), radius = 10)
expect_equal(th2$colors$primary, "#7c3aed")
expect_equal(th2$colors$text, th$colors$text)
expect_equal(th2$radius, 10)
expect_equal(th2$spacing, 4)

# --- the set is closed and the values are checked ---
expect_error(app_theme(colors = list(primry = "#000000")), "unknown token")
expect_error(app_theme(colors = list(primary = "red")), "rrggbb")
expect_error(app_theme(colors = list(primary = "#12345")), "rrggbb")
expect_error(app_theme(spacing = -1), "spacing")
expect_error(app_theme(spacing = 1000), "spacing")
expect_error(app_theme(font = list(face = "x")), "unknown token")
expect_error(app_theme(font = list(size = 2)), "size")
expect_error(app_theme(font = list(body = 12)), "font family")
# font tokens are interpolated into the served style block, so the
# character set is the injection surface: one family name, no syntax
expect_error(app_theme(font = list(body = "x;--g-primary:#ff0000")),
             "font family")
expect_error(app_theme(font = list(mono = "a}body{display:none")),
             "font family")
expect_error(app_theme(font = list(body = "Inter, sans-serif")),
             "font family")
expect_equal(app_theme(font = list(body = "JetBrains Mono"))$font$body,
             "JetBrains Mono")
# an eight-digit hex (alpha) is allowed
expect_equal(app_theme(colors = list(border = "#d0d0d580"))$colors$border,
             "#d0d0d580")

# --- app() takes a theme, or refuses a non-theme ---
a <- app(ui = page(txt("x"), title = "T"),
         server = function(input, output) NULL,
         theme = th2)
expect_true(inherits(a$theme, "glinty_theme"))
expect_error(app(ui = page(txt("x"), title = "T"),
                 server = function(input, output) NULL,
                 theme = list(colors = list())), "app_theme")
a0 <- app(ui = page(txt("x"), title = "T"),
          server = function(input, output) NULL)
expect_null(a0$theme)

# --- the CSS block names every token the client will set ---
css <- theme_css(th2)
expect_true(startsWith(css, ":root{"))
expect_true(grepl("--g-primary:#7c3aed", css, fixed = TRUE))
expect_true(grepl("--g-on-primary:#ffffff", css, fixed = TRUE))
expect_true(grepl("--g-space:4px", css, fixed = TRUE))
expect_true(grepl("--g-radius:10px", css, fixed = TRUE))
expect_true(grepl("--g-font-body:system-ui", css, fixed = TRUE))
expect_true(grepl("--g-font-size:16px", css, fixed = TRUE))

# every CSS variable the stylesheet declares in :root is one the
# theme emits, so a themed app overrides all of them and none dangle
sheet <- readLines(system.file("www", "glinty.css", package = "glinty"),
                   warn = FALSE)
root_start <- grep("^:root \\{", sheet)[1L]
root_end <- root_start + grep("^\\}", sheet[root_start:length(sheet)])[1L] - 1L
declared <- regmatches(sheet[root_start:root_end],
                       regexpr("--g-[a-z-]+", sheet[root_start:root_end]))
for (v in declared) {
    expect_true(grepl(paste0(v, ":"), css, fixed = TRUE))
}

# --- the served page embeds the block after the stylesheet link ---
html <- glinty:::full_page_html("<div></div>", "T",
                                ui_revision = strrep("a", 64L),
                                theme_css = css)
expect_true(grepl('<style id="g-theme">:root{', html, fixed = TRUE))
expect_true(regexpr("glinty.css", html, fixed = TRUE) <
                regexpr("g-theme", html, fixed = TRUE))
# and omits it for a themeless app
html0 <- glinty:::full_page_html("<div></div>", "T",
                                 ui_revision = strrep("a", 64L))
expect_false(grepl("g-theme", html0, fixed = TRUE))

# --- welcome carries the tokens when set, omits them when not ---
.g <- getFromNamespace(".globals", "glinty")
.g$welcome_theme <- theme_wire(th2)
w <- jsonlite::fromJSON(glinty:::welcome_msg("s1"), simplifyVector = FALSE)
expect_equal(w$theme$colors$primary, "#7c3aed")
expect_equal(w$theme$spacing, 4)
.g$welcome_theme <- NULL
w0 <- jsonlite::fromJSON(glinty:::welcome_msg("s1"), simplifyVector = FALSE)
expect_null(w0$theme)

# --- a dark palette merges over the stylesheet's dark defaults ---
thd <- app_theme(colors = list(primary = "#7c3aed"),
                 dark = list(primary = "#A78BFA"))
expect_equal(thd$dark$primary, "#a78bfa")
expect_equal(thd$dark$surface, "#1e2128")
expect_equal(sort(names(thd$dark)), sort(glinty:::THEME_COLOR_NAMES))
# merging never reaches across schemes: light primary stays light-only
expect_equal(thd$colors$primary, "#7c3aed")
expect_false(identical(thd$dark$background, thd$colors$background))
# dark = list() is exactly the stock dark palette
expect_equal(app_theme(dark = list())$dark, glinty:::DARK_COLOR_DEFAULTS)
# NULL keeps the theme exact: no dark on the object or the wire
expect_null(th2$dark)
expect_null(theme_wire(th2)$dark)
# dark values are held to the same closed set and hex rule
expect_error(app_theme(dark = list(primry = "#000000")), "unknown token")
expect_error(app_theme(dark = list(primary = "red")), "rrggbb")

# DARK_COLOR_DEFAULTS restates the stylesheet's dark block, so read
# the block back and hold them equal: neither can drift alone
dark_start <- grep("prefers-color-scheme: dark", sheet)[1L]
dark_lines <- sheet[dark_start:length(sheet)]
dark_lines <- dark_lines[seq_len(grep("^\\}", dark_lines)[1L])]
decls <- regmatches(dark_lines,
                    regexpr("--g-[a-z-]+: #[0-9a-f]+", dark_lines))
expect_equal(length(decls), length(glinty:::DARK_COLOR_DEFAULTS))
for (d in decls) {
    nm <- gsub("-", "_", sub("^--g-", "", sub(":.*$", "", d)), fixed = TRUE)
    expect_equal(glinty:::DARK_COLOR_DEFAULTS[[nm]], sub("^.*: ", "", d))
}

# --- theme_css: the dark block rides only when dark is present ---
cssd <- theme_css(thd)
expect_true(grepl("@media (prefers-color-scheme: dark){:root{", cssd,
                  fixed = TRUE))
expect_true(grepl("--g-primary:#a78bfa", cssd, fixed = TRUE))
# after the light block, so it wins inside the media query
expect_true(regexpr("#7c3aed", cssd, fixed = TRUE) <
                regexpr("#a78bfa", cssd, fixed = TRUE))
expect_false(grepl("@media", theme_css(th2), fixed = TRUE))

# --- welcome carries dark when set ---
.g$welcome_theme <- theme_wire(thd)
wd <- jsonlite::fromJSON(glinty:::welcome_msg("s1"), simplifyVector = FALSE)
expect_equal(wd$theme$dark$primary, "#a78bfa")
expect_equal(wd$theme$colors$primary, "#7c3aed")
.g$welcome_theme <- NULL

# --- the client builds byte-identical CSS from the same tokens ---
# theme_css() paints the served page, themeCssText() the hydrated
# one; sliced out of the shipped glinty.js and fed the same wire
# theme. Skipped where node is absent, like the keyboard harness.
node <- Sys.which("node")
js_path <- system.file("www", "glinty.js", package = "glinty")
harness <- system.file("tinytest", "theme_client.js", package = "glinty")
if (nzchar(node) && nzchar(harness) && file.exists(harness)) {
    for (theme in list(th2, thd)) {
        tf_theme <- tempfile(fileext = ".json")
        tf_css <- tempfile(fileext = ".css")
        writeLines(as.character(jsonlite::toJSON(theme_wire(theme),
                                                 auto_unbox = TRUE)),
                   tf_theme)
        writeChar(theme_css(theme), tf_css, eos = NULL)
        out <- suppressWarnings(system2(node,
            c(harness, js_path, tf_theme, tf_css),
            stdout = TRUE, stderr = TRUE))
        status <- attr(out, "status")
        expect_true(is.null(status) || identical(status, 0L),
                    info = paste(out, collapse = "\n"))
    }
}
