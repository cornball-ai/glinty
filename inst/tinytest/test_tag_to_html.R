# tag_to_html tests

tag_to_html <- getFromNamespace("tag_to_html", "glinty")
full_page_html <- getFromNamespace("full_page_html", "glinty")

# Simple heading
expect_equal(tag_to_html(h1("Hello")), "<h1>Hello</h1>")

# HTML escaping in text
expect_equal(tag_to_html(h1("a<b&c")), "<h1>a&lt;b&amp;c</h1>")

# Nested tags
ui <- page(h1("Title"), h2("Sub"))
html <- tag_to_html(ui)
expect_true(grepl('<div class="g-page">', html))
expect_true(grepl("<h1>Title</h1>", html))
expect_true(grepl("<h2>Sub</h2>", html))

# page stores its title on the tag object
expect_equal(page(title = "My app")$title, "My app")

# Void element (input) has no closing tag
ti <- text_input("name", label = "Name:", value = "Troy")
html <- tag_to_html(ti)
expect_true(grepl("<input ", html))
expect_false(grepl("</input>", html))

# Bind attributes on input
expect_true(grepl('data-g-event="input"', html))
expect_true(grepl('data-g-target="name"', html))

# Bind attributes on button
btn <- button("go", "Click")
html <- tag_to_html(btn)
expect_true(grepl('data-g-event="click"', html))
expect_true(grepl('data-g-target="go"', html))
expect_true(grepl(">Click</button>", html))

# text_output renders as span with id
out <- text_output("greeting")
html <- tag_to_html(out)
expect_equal(html, '<span id="greeting" class="g-output"></span>')

# table_output renders as div with id
tout <- table_output("tbl")
html <- tag_to_html(tout)
expect_equal(html, '<div id="tbl" class="g-table-output"></div>')

# NULL returns empty string
expect_equal(tag_to_html(NULL), "")

# Character input returns escaped string
expect_equal(tag_to_html("hello"), "hello")
expect_equal(tag_to_html("<script>"), "&lt;script&gt;")

# full_page_html wraps body in document
body <- "<h1>Hi</h1>"
doc <- full_page_html(body, title = "Test")
expect_true(grepl("<!DOCTYPE html>", doc, fixed = TRUE))
expect_true(grepl("<title>Test</title>", doc, fixed = TRUE))
expect_true(grepl('<div id="glinty-root"><h1>Hi</h1></div>', doc, fixed = TRUE))
expect_true(grepl("/glinty/glinty.js", doc, fixed = TRUE))
expect_true(grepl("/glinty/glinty.css", doc, fixed = TRUE))

# Attribute value escaping
tag_obj <- tag("div", attrs = list(title = 'say "hi"'))
html <- tag_to_html(tag_obj)
expect_true(grepl('title="say &quot;hi&quot;"', html))

# print method emits HTML
expect_stdout(print(h1("x")), "<h1>x</h1>")
