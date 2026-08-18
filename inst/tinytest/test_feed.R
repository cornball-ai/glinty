# The feed: delta messages against a server-held window.
#
# The server half is what R can assert: message shapes and order, the
# window's bound, the resume snapshot. The client halves (stick
# scroll, trim compensation, the jump chip) are asserted in the dart
# suite and the browser's DOM behaviour is checked live.

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

component <- glinty:::component
new_session <- glinty:::new_session
session_end <- glinty:::session_end
detach_session <- glinty:::detach_session
resume_session <- glinty:::resume_session
feed_declared_keep <- glinty:::feed_declared_keep

# outgoing carries JSON text (welcome_msg's convention); parse to look
json <- function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)
out_msgs <- function(s) lapply(s$outgoing, json)

# --- the component ---
f <- feed("log")
expect_equal(f$component, "feed")
expect_equal(f$keep, glinty:::FEED_KEEP_DEFAULT)
expect_equal(feed("room", keep = 500L, grow = 1L)$keep, 500L)
expect_error(feed("x", keep = 0L), "keep")
# no children field: the server's log is the one source of items
expect_error(component("feed", id = "x", children = list(txt("no"))),
             "unknown field")

# --- the lowering: an empty shell the messages fill ---
html <- glinty:::component_to_html(feed("log", keep = 50L))
expect_true(grepl('class="g-feed"', html, fixed = TRUE))
expect_true(grepl('id="log"', html, fixed = TRUE))
expect_true(grepl('data-g-keep="50"', html, fixed = TRUE))
expect_true(grepl('class="g-feed-items"', html, fixed = TRUE))
expect_true(grepl('class="g-feed-jump"', html, fixed = TRUE))
expect_true(grepl("hidden", html, fixed = TRUE))
# sized like a container
expect_true(grepl("g-sized", glinty:::component_to_html(
    feed("room", grow = 1L)), fixed = TRUE))

# --- append: one item on the wire, the window grows ---
s <- new_session("f1")
feed_append(s, "log", txt("one"))
expect_equal(length(s$outgoing), 1L)
m <- out_msgs(s)[[1L]]
expect_equal(m$type, "feed")
expect_equal(m$op, "append")
expect_equal(m$id, "log")
expect_equal(m$keep, glinty:::FEED_KEEP_DEFAULT)
expect_equal(m$item$component, "text")
expect_equal(m$item$value, "one")
expect_equal(length(s$feeds[["log"]]$items), 1L)

# --- patch rewrites the newest; patching nothing is an error ---
feed_patch(s, "log", txt("one!"))
expect_equal(length(s$feeds[["log"]]$items), 1L)
m <- out_msgs(s)[[2L]]
expect_equal(m$op, "patch")
expect_equal(m$item$value, "one!")
expect_error(feed_patch(s, "empty", txt("x")), "empty")

# --- items must be components ---
expect_error(feed_append(s, "log", "a bare string"), "component")
expect_error(feed_reset(s, "log", list(txt("ok"), 42)), "component")

# --- reset replaces the window in one message ---
feed_reset(s, "log", list(txt("a"), txt("b")))
m <- out_msgs(s)[[length(s$outgoing)]]
expect_equal(m$op, "reset")
expect_equal(length(m$items), 2L)
expect_equal(m$items[[2L]]$value, "b")
expect_equal(length(s$feeds[["log"]]$items), 2L)
# clearing is a reset to nothing, and the empty window is a JSON
# array, never null -- the array-at-every-length rule
feed_reset(s, "log")
expect_equal(length(s$feeds[["log"]]$items), 0L)
expect_true(grepl('"items":[]',
                  s$outgoing[[length(s$outgoing)]], fixed = TRUE))
session_end(s)

# --- the window is bounded; every message carries the bound ---
.g$welcome_ui <- glinty:::unclass_recursive(
    page(feed("tight", keep = 3L), title = "t"))
expect_equal(feed_declared_keep("tight"), 3L)
expect_equal(feed_declared_keep("elsewhere"), glinty:::FEED_KEEP_DEFAULT)
s <- new_session("f2")
for (i in 1:5) feed_append(s, "tight", txt(as.character(i)))
st <- s$feeds[["tight"]]
expect_equal(length(st$items), 3L)
expect_equal(vapply(st$items, function(x) x$value, character(1L)),
             c("3", "4", "5"))
expect_equal(out_msgs(s)[[5L]]$keep, 3L)
session_end(s)
.g$welcome_ui <- NULL

# --- resume replays one reset carrying the current window ---
s <- new_session("f3")
feed_append(s, "log", txt("kept"))
# the live append has been drained by the time a socket drops
s$outgoing <- list()
detach_session(s)
# while detached: state advances, nothing queues live
n_before <- length(s$outgoing)
feed_append(s, "log", txt("while away"))
expect_equal(length(s$outgoing), n_before)
expect_equal(length(s$feeds[["log"]]$items), 2L)
resume_session(s)
msgs <- out_msgs(s)
expect_equal(msgs[[1L]]$type, "welcome")
replayed <- Filter(function(m) identical(m$type, "feed"), msgs)
expect_equal(length(replayed), 1L)
expect_equal(replayed[[1L]]$op, "reset")
expect_equal(length(replayed[[1L]]$items), 2L)
expect_equal(replayed[[1L]]$items[[2L]]$value, "while away")
session_end(s)

# --- guards ---
expect_error(feed_append("not a session", "log", txt("x")),
             "glinty_session")
expect_error(feed_append(new_session("f4"), "", txt("x")), "non-empty")
