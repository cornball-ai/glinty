# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

is_truthy <- glinty:::is_truthy

# truthiness table
expect_false(is_truthy(NULL))
expect_false(is_truthy(character(0)))
expect_false(is_truthy(NA))
expect_false(is_truthy(FALSE))
expect_false(is_truthy(""))
expect_true(is_truthy(TRUE))
expect_true(is_truthy(0))
expect_true(is_truthy("x"))
expect_true(is_truthy(is_truthy))

# req() inside an observer aborts silently, no error escapes flush
rv <- reactive_val(NULL)
ran <- 0L
observe(function() {
    req(rv())
    ran <<- ran + 1L
})
flush_reactions()
expect_equal(ran, 0L)

rv("go")
flush_reactions()
expect_equal(ran, 1L)

# req() returns its first argument
rv2 <- reactive_val(7)
got <- NULL
observe(function() {
    got <<- req(rv2())
})
flush_reactions()
expect_equal(got, 7)

# req() suppresses output updates
s <- glinty:::new_session("req-test")
glinty:::with_session(s, {
    s$output$out <- function() {
        req(FALSE)
        "never"
    }
})
flush_reactions()
expect_equal(length(s$outgoing), 0L)
glinty:::session_end(s)
