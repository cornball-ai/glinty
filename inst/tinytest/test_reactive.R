# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$ctx_id_counter <- 0L

# reactive caches and recomputes
counter <- 0L
rv <- reactive_val(5)
re <- reactive(function() {
  counter <<- counter + 1L
  rv() * 2
})

result <- NULL
observe(function() {
  result <<- re()
})
flush_reactions()
expect_equal(result, 10)

# change upstream, flush
rv(7)
flush_reactions()
expect_equal(result, 14)

# caching: repeated reads without invalidation do not recompute
runs_before <- counter
observe(function() {
  re()
})
flush_reactions()
expect_equal(counter, runs_before)

# isolate: reads inside isolate() do not register dependencies
.g$current_context <- NULL
.g$pending_flush <- list()

rv2 <- reactive_val(1)
runs <- 0L
observe(function() {
  runs <- isolate(rv2())
  runs <<- runs
})
flush_reactions()
rv2(99)
flush_reactions()
expect_equal(runs, 1)
