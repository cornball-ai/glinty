# radio_buttons and date_input widgets + their update functions

tag_to_html <- getFromNamespace("tag_to_html", "glinty")

# --- radio_buttons HTML shape ---
rb <- radio_buttons("mode", "Mode:", c(Fast = "fast", Careful = "careful"))
html <- tag_to_html(rb)
expect_true(grepl('id="mode"', html))
expect_true(grepl('class="g-radio-group"', html))
expect_true(grepl('type="radio"', html))
# shared name groups the members; per-member ids are derived
expect_true(grepl('name="mode"', html))
expect_true(grepl('id="mode_1"', html))
expect_true(grepl('id="mode_2"', html))
expect_true(grepl('value="fast"', html))
expect_true(grepl('value="careful"', html))
# first choice checked by default
expect_true(grepl('value="fast"[^>]*checked="checked"', html))
expect_false(grepl('value="careful"[^>]*checked', html))
# labels shown, binding present on members
expect_true(grepl(">Fast</label>", html))
expect_true(grepl('data-g-event="change"', html))
expect_true(grepl('data-g-target="mode"', html))

# explicit selected wins
rb2 <- radio_buttons("m2", choices = c("a", "b"), selected = "b")
html2 <- tag_to_html(rb2)
expect_true(grepl('value="b"[^>]*checked="checked"', html2))

# --- date_input HTML shape ---
di <- date_input("start", "Start:", value = "2026-07-07",
    min = "2026-01-01", max = "2026-12-31")
html <- tag_to_html(di)
expect_true(grepl('type="date"', html))
expect_true(grepl('value="2026-07-07"', html))
expect_true(grepl('min="2026-01-01"', html))
expect_true(grepl('max="2026-12-31"', html))
expect_true(grepl('data-g-event="change"', html))

# NULL attrs omitted
di2 <- date_input("d2")
html2 <- tag_to_html(di2)
expect_false(grepl("value=", html2))
expect_false(grepl("min=", html2))

# --- update functions ---
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

s <- glinty:::new_session("rd1")
last_msg <- function() jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])

update_radio_buttons(s, "mode", selected = "careful")
m <- last_msg()
expect_equal(m$type, "update_input")
expect_equal(m$id, "mode")
expect_equal(m$selected, "careful")
expect_false("choices" %in% names(m))
expect_equal(isolate(s$input$mode()), "careful")

update_radio_buttons(s, "mode", choices = c(X = "x", Y = "y"))
m <- last_msg()
expect_equal(m$choices$value, c("x", "y"))
expect_equal(m$choices$label, c("X", "Y"))
expect_equal(m$selected, "x")
expect_equal(isolate(s$input$mode()), "x")

update_date_input(s, "start", value = "2026-01-15")
m <- last_msg()
expect_equal(m$type, "update_input")
expect_equal(m$value, "2026-01-15")
expect_equal(isolate(s$input$start()), "2026-01-15")

# Date objects coerce to the wire string
update_date_input(s, "start", value = as.Date("2026-02-01"))
m <- last_msg()
expect_equal(m$value, "2026-02-01")

# min/max only
n <- length(s$outgoing)
update_date_input(s, "start", min = "2025-01-01")
m <- last_msg()
expect_equal(m$min, "2025-01-01")
expect_false("value" %in% names(m))
# no value change on the server side
expect_equal(isolate(s$input$start()), "2026-02-01")

glinty:::session_end(s)
