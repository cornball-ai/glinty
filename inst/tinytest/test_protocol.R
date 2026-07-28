# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
dispatch <- glinty:::dispatch_client_message
output_msg <- glinty:::output_msg
error_msg <- glinty:::error_msg
welcome_msg <- glinty:::welcome_msg
input_update_msg <- glinty:::input_update_msg
normalize_value <- glinty:::normalize_value
component <- glinty:::component
ui_revision <- glinty:::ui_revision
unclass_recursive <- glinty:::unclass_recursive

# --- message builders produce exact JSON ---
expect_equal(
    output_msg("out", "text", "hi"),
    '{"type":"output","id":"out","kind":"text","value":"hi"}'
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
    input_update_msg("name", list(value = "x")),
    '{"type":"input_update","id":"name","value":"x"}'
)

# --- welcome carries the session, the protocol, the tree and its ---
# --- revision, exactly as the transcripts promise ---
.g$welcome_ui <- NULL
.g$welcome_revision <- NULL
expect_equal(
    welcome_msg("abc123"),
    '{"type":"welcome","session":"abc123","protocol":3}'
)
expect_equal(
    welcome_msg("abc123", resumed = TRUE),
    '{"type":"welcome","session":"abc123","protocol":3,"resumed":true}'
)

wui <- component("page", title = "T", children = list(
    component("heading", value = "T", level = 1L)
))
.g$welcome_ui <- unclass_recursive(wui)
.g$welcome_revision <- ui_revision(wui)
w <- jsonlite::fromJSON(welcome_msg("s9"), simplifyVector = FALSE)
expect_equal(w$type, "welcome")
expect_equal(w$session, "s9")
expect_equal(w$protocol, 3L)
expect_equal(w$ui$component, "page")
expect_equal(w$ui_revision, ui_revision(wui))
# a refused resume says so
wf <- jsonlite::fromJSON(welcome_msg("s10", resumed = FALSE),
                         simplifyVector = FALSE)
expect_false(wf$resumed)
.g$welcome_ui <- NULL
.g$welcome_revision <- NULL

# --- normalize_value collapses homogeneous lists ---
expect_equal(normalize_value(list("a", "b")), c("a", "b"))
expect_equal(normalize_value("a"), "a")
expect_equal(normalize_value(list(1L, 2L)), c(1L, 2L))
mixed <- list("a", list(b = 1))
expect_equal(normalize_value(mixed), mixed)

# --- dispatch: hello records capabilities and answers nothing ---
s <- new_session("p1")
s$outgoing <- list()
dispatch(s, paste0('{"type":"hello","protocol":3,"client":"glinty-js/0.5.0",',
                   '"components":["page","button"],"kinds":["text"],',
                   '"features":["modal"]}'))
expect_equal(s$client, "glinty-js/0.5.0")
expect_equal(s$capabilities$components, c("page", "button"))
expect_equal(s$capabilities$kinds, "text")
expect_equal(s$capabilities$features, "modal")
# hello is a declaration; the welcome comes from session start, so a
# redeclaring reconnect must not trigger a second bootstrap
expect_equal(length(s$outgoing), 0L)

# --- dispatch: input change reaches observers ---
seen <- NULL
observe_event(s$input$name, function(v) seen <<- v)
dispatch(s, '{"type":"input","id":"name","value":"jorge"}')
flush_reactions()
expect_equal(seen, "jorge")

# --- dispatch: events count up ---
dispatch(s, '{"type":"event","id":"go"}')
dispatch(s, '{"type":"event","id":"go"}')
flush_reactions()
expect_equal(isolate(s$input$go()), 2L)

# --- dispatch: a ticket request gets a scoped grant ---
s$outgoing <- list()
dispatch(s, '{"type":"ticket","id":"dataset","purpose":"upload"}')
tg <- jsonlite::fromJSON(s$outgoing[[1L]])
expect_equal(tg$type, "ticket")
expect_equal(tg$id, "dataset")
expect_equal(tg$purpose, "upload")
expect_true(startsWith(tg$token, "tk_"))
expect_true(tg$expires > 0)
# and the grant redeems, once, for its purpose only
grant <- glinty:::redeem_ticket(tg$token, "upload")
expect_equal(grant$id, "dataset")
expect_identical(grant$session, s)
expect_null(glinty:::redeem_ticket(tg$token, "upload"))
# a bad purpose never mints
s$outgoing <- list()
dispatch(s, '{"type":"ticket","id":"x","purpose":"delete_everything"}')
expect_equal(length(s$outgoing), 0L)

# --- dispatch: protocol 2 frames are unknown types now ---
s$outgoing <- list()
dispatch(s, '{"type":"init","inputs":{"name":"troy"}}')
m <- jsonlite::fromJSON(s$outgoing[[1L]])
expect_equal(m$type, "error")

s$outgoing <- list()
dispatch(s, '{"type":"click","id":"go"}')
m <- jsonlite::fromJSON(s$outgoing[[1L]])
expect_equal(m$type, "error")
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
