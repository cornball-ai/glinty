# Package globals are initialized on load

g <- glinty:::.globals
expect_true(is.environment(g))
expect_identical(g$pending_flush, list())
expect_false(g$flush_scheduled)
expect_identical(g$ctx_id_counter, 0L)
expect_true(is.environment(g$sessions))
