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
