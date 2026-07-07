# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
dispatch <- glinty:::dispatch_client_message
update_msg <- glinty:::update_msg
error_msg <- glinty:::error_msg
config_msg <- glinty:::config_msg
update_input_msg <- glinty:::update_input_msg
normalize_value <- glinty:::normalize_value

# --- message builders produce exact JSON ---
expect_equal(
    update_msg("out", "textContent", "hi"),
    '{"type":"update","id":"out","property":"textContent","value":"hi"}'
)
expect_equal(
    error_msg("out", "bad"),
    '{"type":"error","id":"out","message":"bad"}'
)
expect_equal(
    error_msg(NULL, "bad"),
    '{"type":"error","id":null,"message":"bad"}'
)
expect_equal(
    config_msg("abc123"),
    '{"type":"config","session_id":"abc123","protocol":2}'
)
expect_equal(
    update_input_msg("name", list(value = "x")),
    '{"type":"update_input","id":"name","value":"x"}'
)

# --- normalize_value collapses homogeneous lists ---
expect_equal(normalize_value(list("a", "b")), c("a", "b"))
expect_equal(normalize_value("a"), "a")
expect_equal(normalize_value(list(1L, 2L)), c(1L, 2L))
mixed <- list("a", list(b = 1))
expect_equal(normalize_value(mixed), mixed)

# --- dispatch: init seeds inputs ---
s <- new_session("p1")
dispatch(s, '{"type":"init","inputs":{"name":"troy","n":3,"tags":["a","b"]}}')
flush_reactions()
expect_equal(isolate(s$input$name()), "troy")
expect_equal(isolate(s$input$n()), 3L)
expect_equal(isolate(s$input$tags()), c("a", "b"))

# --- dispatch: input change reaches observers ---
seen <- NULL
observe_event(s$input$name, function(v) seen <<- v)
dispatch(s, '{"type":"input","id":"name","value":"jorge"}')
flush_reactions()
expect_equal(seen, "jorge")

# --- dispatch: clicks count up ---
dispatch(s, '{"type":"click","id":"go"}')
dispatch(s, '{"type":"click","id":"go"}')
flush_reactions()
expect_equal(isolate(s$input$go()), 2L)

# --- dispatch: malformed JSON and unknown types answer with errors ---
s$outgoing <- list()
dispatch(s, "{not json")
m <- jsonlite::fromJSON(s$outgoing[[1L]])
expect_equal(m$type, "error")

s$outgoing <- list()
dispatch(s, '{"type":"warp"}')
m <- jsonlite::fromJSON(s$outgoing[[1L]])
expect_equal(m$type, "error")
expect_true(grepl("warp", m$message))

session_end(s)
