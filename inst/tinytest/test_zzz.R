# Package globals are initialized on load

g <- glinty:::.globals
expect_true(is.environment(g))
expect_true(is.list(g$pending_flush))
expect_true(is.integer(g$ctx_id_counter))
expect_true(is.environment(g$sessions))
