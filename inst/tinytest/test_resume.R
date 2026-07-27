# Detach / resume lifecycle

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL
.g$timers <- list()

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session
detach_session <- glinty:::detach_session
resume_session <- glinty:::resume_session
handle_input <- glinty:::handle_input
run_due_timers <- glinty:::run_due_timers

# welcome_msg's shape is pinned in test_protocol.R; here it only
# matters that a resume opens with one

# --- outputs record last_sent while attached ---
s <- new_session("r1")
with_session(s, {
    s$output$echo <- render_text(function() paste("v", s$input$x()))
})
flush_reactions()
expect_equal(length(s$outgoing), 1L)
expect_true(grepl("echo", s$last_sent[["echo"]]))

# --- detached: observers stay alive, outputs update last_sent only ---
s$outgoing <- list()
detach_session(s)
expect_true(s$detached)
expect_false(s$ended)
expect_equal(length(.g$timers), 1L)

handle_input(s, "x", "42")
flush_reactions()
expect_equal(length(s$outgoing), 0L)
expect_true(grepl("v 42", s$last_sent[["echo"]]))

# non-output messages buffer while detached
update_text_input(s, "x", label = "X:")
expect_equal(length(s$outgoing), 1L)

# drain is a no-op while detached
expect_equal(length(glinty:::drain_session(s)), 0L)
expect_equal(length(s$outgoing), 1L)

# --- resume: welcome + replayed output state + buffered messages ---
resume_session(s)
expect_false(s$detached)
expect_equal(length(.g$timers), 0L)
msgs <- lapply(s$outgoing, jsonlite::fromJSON)
expect_equal(msgs[[1L]]$type, "welcome")
expect_true(msgs[[1L]]$resumed)
expect_equal(msgs[[2L]]$id, "echo")
expect_equal(msgs[[2L]]$value, "v 42")
expect_equal(msgs[[3L]]$type, "update_input")
session_end(s)

# --- grace expiry ends the session ---
.g$timers <- list()
s2 <- new_session("r2")
ended <- FALSE
s2$on_ended(function() ended <<- TRUE)
detach_session(s2)
run_due_timers(now = as.numeric(Sys.time()) +
    getOption("glinty.resume_grace", 60) + 1)
expect_true(s2$ended)
expect_true(ended)
# resuming an ended session is a no-op
resume_session(s2)
expect_equal(length(s2$outgoing), 0L)

# --- detach buffer cap drops oldest ---
s3 <- new_session("r3")
detach_session(s3)
old_opt <- options(glinty.detach_buffer = 3L)
for (i in 1:5) s3$send(sprintf('{"n":%d}', i))
options(old_opt)
expect_equal(length(s3$outgoing), 3L)
expect_true(grepl('"n":5', s3$outgoing[[3L]]))
expect_true(grepl('"n":3', s3$outgoing[[1L]]))
session_end(s3)
.g$timers <- list()

# --- transport_rebind moves the conn mapping ---
REG <- glinty:::REG
glinty:::reg_reset()
entry <- new.env(parent = emptyenv())
entry$session_id <- "new-sid"
REG$conns[["c99"]] <- entry
REG$sessions[["new-sid"]] <- "c99"

expect_true(glinty:::transport_rebind("new-sid", "old-sid"))
expect_null(REG$sessions[["new-sid"]])
expect_equal(REG$sessions[["old-sid"]], "c99")
expect_equal(entry$session_id, "old-sid")

# rebinding an unknown sid fails cleanly
expect_false(glinty:::transport_rebind("ghost", "x"))
glinty:::reg_reset()
