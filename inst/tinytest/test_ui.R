# tag construction
btn <- button("go", "Click me")
expect_equal(btn$tag, "button")
expect_equal(btn$attrs$id, "go")
expect_equal(btn$text, "Click me")
expect_equal(btn$bind$event, "click")
expect_equal(btn$bind$target, "go")

# text input
ti <- text_input("name", label = "Name", value = "Troy")
expect_equal(ti$tag, "div")
expect_equal(length(ti$children), 2L)
expect_equal(ti$children[[2]]$attrs$id, "name")
expect_equal(ti$children[[2]]$bind$event, "input")

# page wrapping
pg <- page(h1("Hi"))
expect_equal(pg$tag, "div")
expect_equal(length(pg$children), 1L)
expect_equal(pg$children[[1]]$tag, "h1")
expect_equal(pg$children[[1]]$text, "Hi")

# text output
to <- text_output("greeting")
expect_equal(to$tag, "span")
expect_equal(to$attrs$id, "greeting")

# paragraph and link
para <- p("hello world")
expect_equal(para$tag, "p")
expect_equal(para$text, "hello world")

lnk <- a("site", "https://example.org")
expect_equal(lnk$tag, "a")
expect_equal(lnk$attrs$href, "https://example.org")

# h4
expect_equal(h4("d")$tag, "h4")
