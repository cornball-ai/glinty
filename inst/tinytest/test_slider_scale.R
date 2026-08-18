# The slider scale's three rules, pinned because three renderers
# implement them (R slider_ticks / JS sliderTicks / dart
# _sliderTicks) and the trio must agree.

# --- implied step: Shiny's findStepSize semantics for stepless sliders
st <- glinty:::slider_implied_step
expect_equal(st(1, 1000), 1)          # integer ends, range >= 2
expect_equal(st(0, 1), 0.01)          # short range: ~range/100 ladder
expect_equal(st(0.2, 2), 0.02)

# --- snap: stepless labels round to the implied precision
sn <- glinty:::slider_snap
expect_equal(sn(0.3, 1, 1000, NULL), 301)
expect_equal(sn(0.6, 1, 1000, NULL), 600)
expect_equal(sn(0, 1, 1000, NULL), 1)
expect_equal(sn(1, 1, 1000, NULL), 1000)
# a real step wins over the implied one
expect_equal(sn(0.55, 0.2, 2, 0.2), 1.2)

# --- a stepless slider's HTML materializes the implied step as its
#     drag granularity (a sample-count slider must not produce
#     394.326 samples); the tree field stays as the app set it
h <- glinty:::component_to_html(
    glinty::slider_input("n", "N:", min = 1, max = 1000, value = 500))
expect_true(grepl('step="1"', h, fixed = TRUE))
h2 <- glinty:::component_to_html(
    glinty::slider_input("bw", "BW:", min = 0, max = 1, value = 0.5))
expect_true(grepl('step="0.01"', h2, fixed = TRUE))

# --- ticks: step grid sits ON the stops, labels every stop up to 10
tk <- glinty:::slider_ticks(0.2, 2, 0.2)
labs <- vapply(Filter(function(t) t$major, tk),
    function(t) t$label, character(1L))
expect_equal(labs, c("0.2", "0.4", "0.6", "0.8", "1", "1.2", "1.4",
    "1.6", "1.8", "2"))

# --- ticks: continuous tenths grid, thinned to the label budget,
#     last stop always labeled, its crowded neighbor yields
tk3 <- glinty:::slider_ticks(1, 1000, NULL, max_labels = 3)
labs3 <- vapply(Filter(function(t) t$major && nzchar(t$label), tk3),
    function(t) t$label, character(1L))
expect_equal(labs3, c("1", "401", "1000"))

# default budget: labeled majors at every tenth
tk11 <- glinty:::slider_ticks(1, 1000, NULL)
labs11 <- vapply(Filter(function(t) t$major && nzchar(t$label), tk11),
    function(t) t$label, character(1L))
expect_equal(length(labs11), 11L)
expect_equal(labs11[[1L]], "1")
expect_equal(labs11[[11L]], "1000")
