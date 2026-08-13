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
expect_equal(m$type, "input_update")
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
expect_equal(m$type, "input_update")
expect_equal(m$choices$value, c("fast", "slow"))
expect_equal(m$choices$label, c("Fast", "Slow"))
# replacing choices without selected picks the first
expect_equal(m$selected, "fast")
expect_equal(isolate(s$input$engine()), "fast")

# --- a multiple select's push is an array at every length ---
#
# The same rule the component schema keeps. update_select_input()
# serialized a scalar whatever the control was, so a server pushing a
# one-element selection to a multiple select sent "a" where the tree
# had said ["a"] -- and a client that trusted the rule got a string.
raw <- function() s$outgoing[[length(s$outgoing)]]

update_select_input(s, "tags", selected = c("a", "c"))
expect_true(grepl('"selected":["a","c"]', raw(), fixed = TRUE))
expect_equal(isolate(s$input$tags()), c("a", "c"))

# one value cannot say by itself which control it is for, so
# multiple = TRUE is how a caller says it
update_select_input(s, "tags", selected = "a", multiple = TRUE)
expect_true(grepl('"selected":["a"]', raw(), fixed = TRUE))

# and clearing a selection is character(0), which is an empty array
update_select_input(s, "tags", selected = character(0), multiple = TRUE)
expect_true(grepl('"selected":[]', raw(), fixed = TRUE))

# a single select is still a bare string -- the other half of the rule
update_select_input(s, "engine", selected = "slow")
expect_true(grepl('"selected":"slow"', raw(), fixed = TRUE))

# a label-only update must not clear a selection it was not asked
# about: NULL means "leave it alone" and stays NULL all the way down
update_select_input(s, "tags", label = "Tags:", multiple = TRUE)
m <- last_msg()
expect_equal(m$label, "Tags:")
expect_false("selected" %in% names(m))

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

# --- video: playback commands, not input updates ---
update_video(s, "preview", current_time = 1.5, playing = TRUE)
m <- last_msg()
expect_equal(m$type, "video_update")
expect_equal(m$id, "preview")
expect_equal(m$current_time, 1.5)
expect_true(m$playing)

# each half of the state travels alone, and NULL leaves the other be
update_video(s, "preview", playing = FALSE)
m <- last_msg()
expect_false(m$playing)
expect_false("current_time" %in% names(m))

update_video(s, "preview", current_time = 0)
m <- last_msg()
expect_equal(m$current_time, 0)
expect_false("playing" %in% names(m))

# an all-NULL update sends nothing
n <- length(s$outgoing)
update_video(s, "preview")
expect_equal(length(s$outgoing), n)

# refusals name the field: a position is one finite non-negative
# number, playing is one TRUE or FALSE
expect_error(update_video(s, "preview", current_time = -1),
             "finite, non-negative")
expect_error(update_video(s, "preview", current_time = c(1, 2)),
             "finite, non-negative")
expect_error(update_video(s, "preview", current_time = Inf),
             "finite, non-negative")
expect_error(update_video(s, "preview", playing = NA),
             "TRUE or FALSE")
expect_error(update_video(s, "preview", playing = "yes"),
             "TRUE or FALSE")

session_end(s)
