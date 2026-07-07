# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$ctx_id_counter <- 0L

# observer fires on flush
log <- character(0)
rv <- reactive_val("a")
observe(function() {
  log <<- c(log, rv())
})
flush_reactions()
expect_true(length(log) >= 1)
expect_equal(log[length(log)], "a")

rv("b")
flush_reactions()
expect_equal(log[length(log)], "b")

# destroy stops re-execution
.g$current_context <- NULL
.g$pending_flush <- list()
.g$ctx_id_counter <- 0L

rv2 <- reactive_val(1)
count <- 0L
obs <- observe(function() {
  rv2()
  count <<- count + 1L
})
flush_reactions()
prev_count <- count

obs$destroy()
rv2(2)
flush_reactions()
expect_equal(count, prev_count)
