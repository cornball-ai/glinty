# Static mounts: one directory at /static/, or several, each under
# its own name, so a page assembled from parts can serve every part's
# assets instead of the first one's.

static_mounts <- glinty::static_mounts
serve_mounted <- glinty:::serve_mounted
route_http <- glinty:::route_http

a <- tempfile("fleet")
dir.create(a)
writeLines("a { color: red }", file.path(a, "fleet.css"))
b <- tempfile("notes")
dir.create(b)
writeLines("b { color: blue }", file.path(b, "notes.css"))
writeLines("shared", file.path(b, "fleet.css"))

# --- normalisation ---
expect_null(static_mounts(NULL))
expect_null(static_mounts(character(0L)))
# the unnamed default is a convenience: absent means nothing is served
expect_null(static_mounts(tempfile("absent")))
one <- static_mounts(a)
expect_equal(unname(one), a)
expect_equal(names(one), "")
two <- static_mounts(c(fleet = a, notes = b))
expect_equal(names(two), c("fleet", "notes"))
expect_equal(unname(two), c(a, b))
mixed <- static_mounts(c(a, notes = b))
expect_equal(names(mixed), c("", "notes"))

# a named directory was named on purpose, so its absence is refused
expect_error(static_mounts(c(fleet = tempfile("gone"))), "not a directory")
expect_error(static_mounts(c(fleet = tempfile("gone"))), "fleet")
# at most one root mount
expect_error(static_mounts(c(a, b)), "one unnamed")
# names are path segments
expect_error(static_mounts(c("bad name" = a)), "path segments")
expect_error(static_mounts(c("a/b" = a)), "path segments")
expect_error(static_mounts(c(fleet = a, fleet = b)), "unique")
expect_error(static_mounts(42), "static_dir must be")

# --- serving ---
req <- function(path, range = NULL) {
    list(method = "GET", path = path, query = "",
         headers = if (is.null(range)) character(0L) else c(range = range),
         body = NULL)
}
page <- "<html></html>"
pkg_www <- system.file("www", package = "glinty")
get <- function(path, mounts) {
    rawToChar(route_http(req(path), page, pkg_www, mounts))
}

# one directory keeps meaning /static/
expect_true(grepl("200 OK", get("/static/fleet.css", one)))
expect_true(grepl("color: red", get("/static/fleet.css", one)))
expect_true(grepl("404", get("/static/notes/notes.css", one)))

# named mounts serve under their names and nowhere else
expect_true(grepl("color: red", get("/static/fleet/fleet.css", two)))
expect_true(grepl("color: blue", get("/static/notes/notes.css", two)))
expect_true(grepl("404", get("/static/fleet.css", two)))
expect_true(grepl("404", get("/static/notes/fleet.css", two)) ||
            grepl("shared", get("/static/notes/fleet.css", two)))
expect_true(grepl("shared", get("/static/notes/fleet.css", two)))
expect_true(grepl("404", get("/static/fleet/notes.css", two)))
expect_true(grepl("404", get("/static/other/fleet.css", two)))
expect_true(grepl("404", get("/static/fleet", two)))
expect_true(grepl("404", get("/static/fleet/", two)))

# the root mount answers for what no name claims; a name shadows it
expect_true(grepl("color: red", get("/static/fleet.css", mixed)))
expect_true(grepl("color: blue", get("/static/notes/notes.css", mixed)))
expect_true(grepl("404", get("/static/notes.css", mixed)))

# traversal is refused inside a mount, and across mounts
expect_true(grepl("403", get("/static/notes/../fleet.css", two)))
expect_true(grepl("403", get("/static/../fleet.css", one)))

# nothing mounted: nothing served
expect_true(grepl("404", get("/static/fleet.css", NULL)))

# byte ranges still reach serve_static()
r <- rawToChar(route_http(req("/static/fleet/fleet.css", "bytes=0-3"),
                          page, pkg_www, two))
expect_true(grepl("206 Partial Content", r))
expect_true(endsWith(r, "a { "))

# serve_mounted() directly: the mount wins over the root on its segment
expect_true(grepl("color: blue",
                  rawToChar(serve_mounted("notes/notes.css", mixed))))
expect_true(grepl("color: red",
                  rawToChar(serve_mounted("fleet.css", mixed))))
