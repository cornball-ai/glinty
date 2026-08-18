# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session
dispatch <- glinty:::dispatch_client_message
custom_msg <- glinty:::custom_msg
normalize_value <- glinty:::normalize_value

# --- custom_msg produces exact JSON, scalars unboxed ---
expect_equal(
    custom_msg("set_mode", TRUE),
    '{"type":"custom","handler":"set_mode","value":true}'
)
expect_equal(
    custom_msg("ping", NULL),
    '{"type":"custom","handler":"ping","value":null}'
)
expect_equal(
    custom_msg("cfg", list(a = 1L, b = "x")),
    '{"type":"custom","handler":"cfg","value":{"a":1,"b":"x"}}'
)

# --- send_custom_message queues on the session ---
s <- new_session("cm1")
send_custom_message(s, "set_mode", TRUE)
expect_equal(length(s$outgoing), 1L)
expect_equal(s$outgoing[[1]], custom_msg("set_mode", TRUE))

# it is not an output message, so it does not enter last_sent
expect_equal(length(ls(s$last_sent)), 0L)

# --- argument validation ---
expect_error(send_custom_message(list(), "x"), "glinty_session")
expect_error(send_custom_message(s, ""), "non-empty")
expect_error(send_custom_message(s, c("a", "b")), "non-empty")
expect_error(send_custom_message(s, 42), "non-empty")
session_end(s)

# --- normalize_value: JSON objects keep their names ---
# a JSON array of scalars still collapses to a vector
expect_equal(normalize_value(list("a", "b")), c("a", "b"))
expect_equal(normalize_value(list(1L, 2L, 3L)), c(1L, 2L, 3L))
# an empty array is an empty vector, not NULL: [] is an empty
# collection, and a multi select whose last item was deselected must
# read the same as one seeded empty (character(0), the array-at-
# every-length rule server-side)
expect_equal(normalize_value(list()), character(0))
# a JSON object survives intact: names kept, types not coerced
obj <- normalize_value(list(data = "AAAA", size = 1024L, type = "audio/webm"))
expect_true(is.list(obj))
expect_equal(names(obj), c("data", "size", "type"))
expect_equal(obj$size, 1024L)
expect_equal(obj$data, "AAAA")
# an empty object stays an empty named list, not NULL
empty_obj <- normalize_value(structure(list(), names = character(0)))
expect_true(is.list(empty_obj))
expect_equal(length(empty_obj), 0L)
# scalars and nested structures pass through
expect_equal(normalize_value("plain"), "plain")
expect_equal(normalize_value(list(list(1L, 2L))), list(list(1L, 2L)))

# --- an object-valued input round-trips through dispatch ---
s <- new_session("cm2")
dispatch(s, paste0('{"type":"input","id":"clip","value":',
                   '{"data":"QUJD","size":3,"index":0}}'))
val <- isolate(s$input$clip())
expect_true(is.list(val))
expect_equal(val$data, "QUJD")
expect_equal(val$size, 3L)
expect_equal(val$index, 0L)

# every write invalidates, so repeated identical values still fire
fires <- 0L
with_session(s, observe(function() {
    s$input$clip()
    fires <<- fires + 1L
}))
flush_reactions()
expect_equal(fires, 1L)
dispatch(s, '{"type":"input","id":"clip","value":{"data":"QUJD","size":3}}')
flush_reactions()
expect_equal(fires, 2L)
dispatch(s, '{"type":"input","id":"clip","value":{"data":"QUJD","size":3}}')
flush_reactions()
expect_equal(fires, 3L)
session_end(s)

# The value-carrying click bind tests lived here. Under v3 a click
# that carries a value is a component concern rather than a tag
# attribute, and tag() is now the raw_html escape hatch, so there is
# no tag-level binding left to assert.

# --- the client script exposes the documented surface ---
js <- readLines(system.file("www", "glinty.js", package = "glinty"),
                warn = FALSE)
js <- paste(js, collapse = "\n")
expect_true(grepl("window.Glinty", js, fixed = TRUE))
expect_true(grepl("setInputValue:", js, fixed = TRUE))
expect_true(grepl("addCustomMessageHandler:", js, fixed = TRUE))
expect_true(grepl("glinty:connected", js, fixed = TRUE))
expect_true(grepl('case "custom":', js, fixed = TRUE))
expect_true(grepl("data-g-value", js, fixed = TRUE) ||
            grepl("gValue", js, fixed = TRUE))
