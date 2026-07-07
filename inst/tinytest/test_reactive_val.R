# basic get/set
rv <- reactive_val(10)
expect_equal(rv(), 10)
rv(20)
expect_equal(rv(), 20)

# NULL initial value
rv2 <- reactive_val()
expect_null(rv2())
rv2("hello")
expect_equal(rv2(), "hello")

# dependency tracking: reading in a context registers dependency
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$ctx_id_counter <- 0L

rv3 <- reactive_val("a")
log <- character(0)
observe(function() {
  log <<- c(log, rv3())
})
flush_reactions()
# Observer runs once on creation, establishing deps
expect_true(length(log) >= 1)
expect_equal(log[length(log)], "a")

rv3("b")
flush_reactions()
expect_equal(log[length(log)], "b")
