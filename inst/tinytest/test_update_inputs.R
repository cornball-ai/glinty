# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end

s <- new_session("u1")
last_msg <- function() jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])

# --- text: exact shape, NULL fields omitted ---
update_text_input(s, "name", value = "troy")
m <- last_msg()
expect_equal(m$type, "update_input")
expect_equal(m$id, "name")
expect_equal(m$value, "troy")
expect_false("label" %in% names(m))

# server-side input synced without a round trip
expect_equal(isolate(s$input$name()), "troy")

# --- label-only update does not touch the input value ---
update_text_input(s, "name", label = "Full name:")
expect_equal(isolate(s$input$name()), "troy")
m <- last_msg()
expect_equal(m$label, "Full name:")
expect_false("value" %in% names(m))

# --- all-NULL update sends nothing ---
n <- length(s$outgoing)
update_text_input(s, "name")
expect_equal(length(s$outgoing), n)

# --- select: choices become {value, label} pairs ---
update_select_input(s, "engine", choices = c(Fast = "fast", Slow = "slow"))
m <- last_msg()
expect_equal(m$type, "update_input")
expect_equal(m$choices$value, c("fast", "slow"))
expect_equal(m$choices$label, c("Fast", "Slow"))
# replacing choices without selected picks the first
expect_equal(m$selected, "fast")
expect_equal(isolate(s$input$engine()), "fast")

# --- slider: numeric fields pass through ---
update_slider_input(s, "n", value = 50, min = 0, max = 100, step = 5)
m <- last_msg()
expect_equal(m$value, 50)
expect_equal(m$min, 0)
expect_equal(m$max, 100)
expect_equal(m$step, 5)
expect_equal(isolate(s$input$n()), 50)

# --- checkbox ---
update_checkbox_input(s, "save", value = TRUE)
m <- last_msg()
expect_true(m$value)
expect_true(isolate(s$input$save()))

# --- number ---
update_number_input(s, "k", value = 7, min = 1)
m <- last_msg()
expect_equal(m$value, 7)
expect_equal(m$min, 1)
expect_false("max" %in% names(m))

session_end(s)
