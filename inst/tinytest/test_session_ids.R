# Session ids must be unique across consecutive calls. Regression:
# a save/restore-.Random.seed implementation replayed the same draw,
# colliding every session after the second (fresh connections were
# routed into detached strangers).

ids <- vapply(1:50, function(i) glinty:::new_session_id(), character(1L))
expect_equal(length(unique(ids)), 50L)
expect_true(all(nchar(ids) == 32L))
expect_true(all(grepl("^[0-9a-f]{32}$", ids)))

# and it does not touch the user's RNG stream
set.seed(42)
before <- .Random.seed
invisible(glinty:::new_session_id())
expect_identical(.Random.seed, before)
