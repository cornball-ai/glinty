full_page_html <- glinty:::full_page_html
page_head <- glinty:::page_head
head_html <- glinty:::head_html
body_scripts_html <- glinty:::body_scripts_html
serve_static <- glinty:::serve_static

# --- page() carries the head spec, and stays NULL when unused ---
plain <- page(h1("Hi"))
expect_null(plain$head)
expect_equal(plain$title, "glinty app")

pg <- page(h1("Hi"), title = "My app", css = "/static/styles.css",
           js = "/static/app.js", favicon = "/static/logo.png")
expect_equal(pg$head$css, "/static/styles.css")
expect_equal(pg$head$js, "/static/app.js")
expect_equal(pg$head$favicon, "/static/logo.png")
expect_null(pg$head$extra)
# the children are untouched by the new arguments
expect_equal(length(pg$children), 1L)
expect_equal(pg$children[[1]]$tag, "h1")

# --- head_html: favicon, then stylesheets, in order ---
expect_equal(head_html(NULL), "")
html <- head_html(page_head(css = c("/static/a.css", "/static/b.css"),
                            favicon = "/static/icon.png"))
expect_true(grepl("<link rel=\"icon\" href=\"/static/icon.png\">", html,
                  fixed = TRUE))
expect_true(grepl("/static/a.css", html, fixed = TRUE))
expect_true(grepl("/static/b.css", html, fixed = TRUE))
expect_true(regexpr("a.css", html, fixed = TRUE) <
            regexpr("b.css", html, fixed = TRUE))
expect_true(regexpr("icon.png", html, fixed = TRUE) <
            regexpr("a.css", html, fixed = TRUE))

# --- URLs are escaped, not interpolated blindly ---
esc <- head_html(page_head(css = "/static/a\".css"))
expect_false(grepl("a\".css", esc, fixed = TRUE))
expect_true(grepl("&quot;", esc, fixed = TRUE))

# --- the escape hatch takes a tag tree or raw markup ---
tagged <- head_html(page_head(extra = tag("meta",
                                          attrs = list(name = "robots",
                                                       content = "noindex"))))
expect_true(grepl("<meta name=\"robots\" content=\"noindex\">", tagged,
                  fixed = TRUE))
raw <- head_html(page_head(extra = "<meta name=\"x\" content=\"y\">"))
expect_true(grepl("<meta name=\"x\" content=\"y\">", raw, fixed = TRUE))
expect_error(head_html(page_head(extra = 42)), "glinty_tag")

# --- scripts render at the end of the body, not in head ---
expect_equal(body_scripts_html(NULL), "")
expect_equal(body_scripts_html(page_head(css = "/static/a.css")), "")
scripts <- body_scripts_html(page_head(js = c("/static/a.js", "/static/b.js")))
expect_true(grepl("<script src=\"/static/a.js\"></script>", scripts,
                  fixed = TRUE))
expect_true(grepl("<script src=\"/static/b.js\"></script>", scripts,
                  fixed = TRUE))

# --- full document: ordering guarantees the API promises ---
doc <- full_page_html("<p>body</p>", "My app",
                      page_head(css = "/static/styles.css",
                                js = "/static/app.js",
                                favicon = "/static/logo.png"))
expect_true(grepl("<title>My app</title>", doc, fixed = TRUE))
# app css after glinty's own, so it wins on equal specificity
expect_true(regexpr("/glinty/glinty.css", doc, fixed = TRUE) <
            regexpr("/static/styles.css", doc, fixed = TRUE))
# app js after the client, so window.Glinty exists when it runs
expect_true(regexpr("/glinty/glinty.js", doc, fixed = TRUE) <
            regexpr("/static/app.js", doc, fixed = TRUE))
# scripts belong to the body, not the head
expect_true(regexpr("</head>", doc, fixed = TRUE) <
            regexpr("/static/app.js", doc, fixed = TRUE))
# stylesheets and the icon belong to the head
expect_true(regexpr("/static/styles.css", doc, fixed = TRUE) <
            regexpr("</head>", doc, fixed = TRUE))
expect_true(regexpr("/static/logo.png", doc, fixed = TRUE) <
            regexpr("</head>", doc, fixed = TRUE))

# --- a page with no assets emits the same shell as before ---
bare <- full_page_html("<p>body</p>", "Plain", NULL)
expect_false(grepl("<script src=\"/static", bare, fixed = TRUE))
expect_true(grepl("<div id=\"glinty-root\"><p>body</p></div>", bare,
                  fixed = TRUE))

# --- media and font MIME types resolve ---
tmp <- tempfile("assets")
dir.create(tmp)
mimes <- c(webm = "audio/webm", m4a = "audio/mp4", ogg = "audio/ogg",
           flac = "audio/flac", woff2 = "font/woff2", wav = "audio/wav",
           webp = "image/webp")
for (ext in names(mimes)) {
    writeBin(as.raw(1:4), file.path(tmp, paste0("clip.", ext)))
    resp <- rawToChar(serve_static(paste0("clip.", ext), tmp))
    expect_true(grepl(paste0("Content-Type: ", mimes[[ext]]), resp,
                      fixed = TRUE))
}

# extension matching is case-insensitive
writeBin(as.raw(1:4), file.path(tmp, "LOUD.WAV"))
expect_true(grepl("Content-Type: audio/wav",
                  rawToChar(serve_static("LOUD.WAV", tmp)), fixed = TRUE))

# unknown extensions still fall back rather than erroring
writeBin(as.raw(1:4), file.path(tmp, "thing.xyz"))
expect_true(grepl("Content-Type: application/octet-stream",
                  rawToChar(serve_static("thing.xyz", tmp)), fixed = TRUE))

unlink(tmp, recursive = TRUE)
