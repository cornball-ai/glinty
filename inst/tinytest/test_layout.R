# row()/column() layout tags: browser shape + native mapping

tag_to_html <- getFromNamespace("tag_to_html", "glinty")

# --- browser side: flex classes, gap style, data attr ---
r <- row(button("a", "A"), button("b", "B"), gap = 24, align = "center")
expect_equal(r$tag, "div")
expect_equal(r$attrs$class, "g-layout-row")
html <- tag_to_html(r)
expect_true(grepl('class="g-layout-row"', html))
expect_true(grepl("gap:24px;", html, fixed = TRUE))
expect_true(grepl("align-items:center;", html, fixed = TRUE))
expect_true(grepl('data-g-gap="24"', html, fixed = TRUE))

# defaults: no inline style, CSS defaults apply
r2 <- row(span("x"))
expect_null(r2$attrs$style)

co <- column(h3("t"), text_output("o"), gap = 4)
expect_equal(co$attrs$class, "g-layout-col")
expect_true(grepl("gap:4px;", tag_to_html(co), fixed = TRUE))

expect_error(row(span("x"), align = "sideways"))

# --- native side: maps to flitR row/column with gap ---
if (requireNamespace("flitR", quietly = TRUE) &&
    "render_dirty" %in% getNamespaceExports("flitR")) {
    .g <- getFromNamespace(".globals", "glinty")
    .g$current_context <- NULL
    .g$pending_flush <- list()
    .g$current_session <- NULL

    s <- glinty:::new_session("layout-test")
    values <- new.env(parent = emptyenv())

    flatten <- function(x) {
        if (is.list(x) && !is.null(x$op)) {
            return(list(x))
        }
        if (is.list(x)) {
            return(do.call(c, c(lapply(x, flatten), list(list()))))
        }
        list()
    }

    ui <- page(row(button("l", "L"), button("r", "R"), gap = 30))
    ops <- flatten(glinty:::build_native_ops(ui, s, values))
    hits <- Filter(function(o) identical(o$op, "hit"), ops)
    expect_equal(length(hits), 2L)
    ids <- vapply(hits, function(h) h$id, character(1L))
    lx <- hits[[which(ids == "l")]]$x
    rx <- hits[[which(ids == "r")]]$x
    # same row: right button offset horizontally, same y
    expect_true(rx > lx)
    expect_equal(hits[[1L]]$y, hits[[2L]]$y)
    # gap honored: right starts at left's width + 30
    lw <- hits[[which(ids == "l")]]$w
    expect_equal(rx, lx + lw + 30)

    ui2 <- page(column(button("t", "T"), button("b", "B"), gap = 6))
    ops2 <- flatten(glinty:::build_native_ops(ui2, s, values))
    hits2 <- Filter(function(o) identical(o$op, "hit"), ops2)
    ids2 <- vapply(hits2, function(h) h$id, character(1L))
    ty <- hits2[[which(ids2 == "t")]]$y
    by <- hits2[[which(ids2 == "b")]]$y
    th <- hits2[[which(ids2 == "t")]]$h
    expect_equal(by, ty + th + 6)

    glinty:::session_end(s)
}
