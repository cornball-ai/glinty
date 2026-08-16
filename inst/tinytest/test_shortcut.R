# Keyboard shortcuts: the key spec is parsed once, in R, so no frontend
# has to and no two can disagree about a case nobody wrote a test for.

parse_key <- glinty:::parse_key
component_to_html <- glinty:::component_to_html
KEY_NAMES <- glinty:::KEY_NAMES
INPUT_META <- glinty:::INPUT_META

# --- parsing ---
expect_equal(parse_key("k"),
             list(key = "k", ctrl = FALSE, shift = FALSE, alt = FALSE))
expect_equal(parse_key("ctrl+k")$ctrl, TRUE)
expect_equal(parse_key("ctrl+shift+alt+k"),
             list(key = "k", ctrl = TRUE, shift = TRUE, alt = TRUE))

# cmd, meta and super are ctrl: an app that means "the platform's
# command modifier" says it once, and each frontend knows which key
# that is locally.
expect_equal(parse_key("cmd+s")$ctrl, TRUE)
expect_equal(parse_key("meta+s")$ctrl, TRUE)
expect_equal(parse_key("command+s")$ctrl, TRUE)
expect_equal(parse_key("option+s")$alt, TRUE)

# Case and surrounding space are the writer's business, not the wire's.
expect_equal(parse_key("  Ctrl+Shift+F5  "),
             list(key = "f5", ctrl = TRUE, shift = TRUE, alt = FALSE))

# Aliases reach the token; the token itself always works.
expect_equal(parse_key("esc")$key, "escape")
expect_equal(parse_key("escape")$key, "escape")
expect_equal(parse_key("return")$key, "enter")
expect_equal(parse_key("ArrowLeft")$key, "left")
expect_equal(parse_key("ctrl+=")$key, "equal")
expect_equal(parse_key("ctrl+/")$key, "slash")
expect_equal(parse_key("ctrl+[")$key, "bracketleft")

# --- a bad spec fails where it was written ---
# The whole reason the set is closed: a shortcut that never fires is
# invisible in a way a missing button is not.
expect_error(parse_key("ctrl+splat"), "is not a key name")
expect_error(parse_key("hyper+k"), "unknown modifier")
expect_error(parse_key(""), "one non-empty string")
expect_error(parse_key(c("a", "b")), "one non-empty string")
expect_error(parse_key(NA_character_), "one non-empty string")
expect_error(parse_key("+"), "names no key")
expect_error(glinty::shortcut("x", "ctrl+f13"), "is not a key name")

# Every alias resolves INTO the closed set, so no alias can smuggle a
# token past the schema.
aliases <- glinty:::KEY_ALIASES
expect_true(all(unname(aliases) %in% KEY_NAMES))
# And every name is one both lowerings answer for (asserted against the
# browser map in test_lowerings.R; here, that the set is what it says).
expect_true(all(letters %in% KEY_NAMES))
expect_true(all(as.character(0:9) %in% KEY_NAMES))
expect_true(all(paste0("f", 1:12) %in% KEY_NAMES))
expect_false(anyDuplicated(KEY_NAMES) > 0L)

# --- the component ---
s <- glinty::shortcut("play", "space")
expect_equal(s$component, "shortcut")
expect_equal(s$id, "play")
expect_equal(s$key, "space")
expect_false(s$typing)
expect_false(s$hold)

# A shortcut emits what a button emits, so one observe_event() serves
# the visible control and its accelerator under one id.
expect_equal(INPUT_META$shortcut$message, "event")
expect_equal(INPUT_META$shortcut$message, INPUT_META$button$message)
expect_true(glinty:::is_input_component("shortcut"))

# The value rides along exactly as a button's does.
expect_equal(glinty::shortcut("nudge", "left", value = "-1")$value, "-1")

# --- the browser lowering ---
h <- component_to_html(s)
expect_true(grepl("hidden", h, fixed = TRUE))
expect_true(grepl('data-g-key="space"', h, fixed = TRUE))
expect_true(grepl('data-g-message="event"', h, fixed = TRUE))
expect_true(grepl('data-g-target="play"', h, fixed = TRUE))
# Flags are absent rather than "0": present-means-true is what the
# client tests, so a false flag must not be there to be read.
expect_false(grepl("data-g-ctrl", h, fixed = TRUE))
expect_false(grepl("data-g-typing", h, fixed = TRUE))
expect_false(grepl("data-g-hold", h, fixed = TRUE))
expect_false(grepl("data-g-value", h, fixed = TRUE))

h2 <- component_to_html(glinty::shortcut("save", "ctrl+shift+s",
                                         typing = TRUE))
expect_true(grepl('data-g-ctrl="1"', h2, fixed = TRUE))
expect_true(grepl('data-g-shift="1"', h2, fixed = TRUE))
expect_true(grepl('data-g-typing="1"', h2, fixed = TRUE))
expect_false(grepl("data-g-alt", h2, fixed = TRUE))
expect_true(grepl('data-g-key="s"', h2, fixed = TRUE))

h3 <- component_to_html(glinty::shortcut("nudge", "left", value = "-1",
                                         hold = TRUE))
expect_true(grepl('data-g-hold="1"', h3, fixed = TRUE))
expect_true(grepl('data-g-value="-1"', h3, fixed = TRUE))

# It renders nothing visible: no text, and hidden.
expect_true(grepl("></span>", h, fixed = TRUE))

# --- values are escaped on the way out, like every other component ---
nasty <- component_to_html(glinty::shortcut("x", "k",
        value = '"><script>alert(1)</script>'))
expect_false(grepl("<script>", nasty, fixed = TRUE))

# --- the schema refuses a malformed one ---
expect_error(glinty:::component("shortcut", key = "k"), "id")
expect_error(glinty:::component("shortcut", id = "x"), "key")
expect_error(glinty:::component("shortcut", id = "x", key = "splat"),
             "splat")

# --- the browser's key map answers for every name in the set ---
# The closed set is only closed if both sides carry all of it; a token
# the server can send that the client cannot match is a shortcut that
# binds to nothing, silently.
js <- readLines(system.file("www", "glinty.js", package = "glinty"),
                warn = FALSE)
js <- paste(js, collapse = "\n")
named <- setdiff(KEY_NAMES, c(letters, as.character(0:9),
                              paste0("f", 1:12)))
for (k in named) {
    expect_true(grepl(paste0("\n        ", k, ": \""), js, fixed = TRUE) ||
                grepl(paste0(" ", k, ": \""), js, fixed = TRUE),
                info = paste("browser key map is missing", k))
}
# Letters, digits and function keys are matched by pattern rather than
# listed, so assert the patterns exist instead of each name.
expect_true(grepl("^Key[A-Z]$", js, fixed = TRUE))
expect_true(grepl("^Digit[0-9]$", js, fixed = TRUE))
expect_true(grepl("^F([1-9]|1[0-2])$", js, fixed = TRUE))

# --- and so does the Flutter one ---
dart_path <- file.path("..", "..", "dart", "glinty_flutter", "lib", "src",
                       "render.dart")
if (!file.exists(dart_path)) {
    dart_path <- path.expand("~/glinty/dart/glinty_flutter/lib/src/render.dart")
}
if (file.exists(dart_path)) {
    dart <- paste(readLines(dart_path, warn = FALSE), collapse = "\n")
    for (k in KEY_NAMES) {
        expect_true(grepl(paste0("'", k, "': PhysicalKeyboardKey."), dart,
                          fixed = TRUE),
                    info = paste("Flutter key map is missing", k))
    }
}

# --- and the client half, driven for real ---
#
# Everything above asserts what goes on the wire. Nothing in R can
# assert that pressing a key produces it, so the keyboard block is
# sliced out of the shipped glinty.js and run under node against a DOM
# stub. Skipped where node is absent; it is a development check, not a
# reason for R CMD check to fail on a machine without a JS runtime.
node <- Sys.which("node")
js_path <- system.file("www", "glinty.js", package = "glinty")
harness <- system.file("tinytest", "keyboard_client.js", package = "glinty")
if (nzchar(node) && nzchar(harness) && file.exists(harness)) {
    out <- suppressWarnings(system2(node, c(harness, js_path),
                                    stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status")
    expect_true(is.null(status) || identical(status, 0L),
                info = paste(out, collapse = "\n"))
    expect_true(any(grepl("^ok [0-9]+$", out)),
                info = paste(out, collapse = "\n"))
}
