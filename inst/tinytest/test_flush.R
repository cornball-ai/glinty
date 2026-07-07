# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$ctx_id_counter <- 0L

# priority ordering: higher priority runs first
order <- integer(0)
rv <- reactive_val(1)

observe(function() {
  rv()
  order <<- c(order, 1L)
}, priority = 1)

observe(function() {
  rv()
  order <<- c(order, 2L)
}, priority = 10)

# Initial run happens in creation order, clear and test flush order
order <- integer(0)
rv(2)
flush_reactions()
# Higher priority (10) should run before lower (1)
expect_equal(order, c(2L, 1L))
