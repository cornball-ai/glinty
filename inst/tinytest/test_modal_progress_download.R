# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL
.g$progress <- list()

new_session <- glinty:::new_session
session_end <- glinty:::session_end
handle_download <- glinty:::handle_download
mime_type <- glinty:::mime_type
modal_close_msg <- glinty:::modal_close_msg
current_progress <- glinty:::current_progress
clamp_progress <- glinty:::clamp_progress

json <- function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)

# --- mime_type ---
expect_equal(mime_type("wav"), "audio/wav")
expect_equal(mime_type("WAV"), "audio/wav")
expect_equal(mime_type("webm"), "audio/webm")
expect_equal(mime_type("zip"), "application/zip")
expect_equal(mime_type("nope"), "application/octet-stream")
expect_equal(mime_type(""), "application/octet-stream")

# --- modals ---
s <- new_session("m1")
show_modal(s, p("Really?"), title = "Confirm",
           footer = row(modal_button("Cancel"), button("ok", "OK")))
expect_equal(length(s$outgoing), 1L)
m <- json(s$outgoing[[1]])
expect_equal(m$type, "modal")
expect_equal(m$action, "show")
expect_equal(m$title, "Confirm")
expect_true(m$easy_close)
# the body is a list of tag trees, stripped of their R classes
expect_equal(length(m$body), 1L)
expect_equal(m$body[[1]]$tag, "p")
expect_equal(m$body[[1]]$text, "Really?")
# footer binds survive, so a button in a dialog is a normal input
expect_equal(m$footer$tag, "div")
ok_btn <- m$footer$children[[2]]
expect_equal(ok_btn$bind$target, "ok")
expect_equal(ok_btn$bind$event, "click")

s$outgoing <- list()
show_modal(s, p("x"), easy_close = FALSE)
expect_false(json(s$outgoing[[1]])$easy_close)
expect_null(json(s$outgoing[[1]])$title)

s$outgoing <- list()
remove_modal(s)
expect_equal(s$outgoing[[1]], modal_close_msg())
expect_equal(json(s$outgoing[[1]])$action, "hide")

expect_error(show_modal(list()), "glinty_session")
expect_error(remove_modal(list()), "glinty_session")

# modal_button closes client-side, so it carries no bind
mb <- modal_button("Cancel")
expect_null(mb$bind)
expect_equal(mb$attrs[["data-g-modal-close"]], "1")
session_end(s)

# --- progress ---
expect_null(current_progress())
# calls outside with_progress() are inert, so instrumented code still
# runs from a plain script
expect_silent(inc_progress(0.5))
expect_silent(set_progress(0.5))

expect_equal(clamp_progress(-1), 0)
expect_equal(clamp_progress(2), 1)
expect_equal(clamp_progress(0.25), 0.25)
expect_equal(clamp_progress("nonsense"), 0)
expect_equal(clamp_progress(NA), 0)

# with_progress() flushes as it goes, which is its whole purpose, so
# outgoing is empty by the time it returns. Capture at the transport
# instead: that also proves the messages really left the queue.
sent <- character(0L)
s <- new_session("p1", send_fn = function(msg) sent <<- c(sent, msg))
result <- with_progress(s, message = "Working", value = 0.1, {
    inc_progress(0.4, detail = "Half")
    set_progress(0.9, message = "Nearly")
    42L
})
expect_equal(result, 42L)
# nothing was left queued behind the blocking work
expect_equal(length(s$outgoing), 0L)
# show, update, update, hide
msgs <- lapply(sent, json)
kinds <- vapply(msgs, function(m) m$action, character(1L))
expect_equal(kinds, c("show", "update", "update", "hide"))
expect_equal(msgs[[1]]$message, "Working")
expect_equal(msgs[[1]]$value, 0.1)
expect_equal(msgs[[2]]$value, 0.5)
expect_equal(msgs[[2]]$detail, "Half")
expect_equal(msgs[[3]]$value, 0.9)
expect_equal(msgs[[3]]$message, "Nearly")
# detail carries forward when only the message changes
expect_equal(msgs[[3]]$detail, "Half")
# every message is for the same bar
expect_equal(length(unique(vapply(msgs, function(m) m$id, character(1L)))), 1L)

# the stack is empty again, even though expr returned normally
expect_null(current_progress())

# an error inside expr still tears the bar down
sent <- character(0L)
expect_error(with_progress(s, stop("boom")), "boom")
expect_null(current_progress())
expect_equal(json(sent[[length(sent)]])$action, "hide")

# nesting pops the right handle
sent <- character(0L)
with_progress(s, message = "outer", {
    with_progress(s, message = "inner", {
        set_progress(0.5)
    })
    expect_equal(current_progress()$message, "outer")
})
expect_null(current_progress())

expect_error(with_progress(list(), 1), "glinty_session")
session_end(s)

# --- downloads ---
db <- download_button("dl", "Get it")
expect_equal(db$tag, "a")
expect_equal(db$attrs[["data-g-download"]], "dl")
expect_true(grepl("g-download", db$attrs$class, fixed = TRUE))

s <- new_session("d1")
download_handler(s, "dl",
                 filename = function() "speech.wav",
                 content = function(file) writeBin(charToRaw("RIFFDATA"), file))

req <- function(q) list(method = "GET", path = "/download", query = q)
resp <- rawToChar(handle_download(req("session=d1&id=dl")))
expect_true(grepl("200 OK", resp, fixed = TRUE))
expect_true(grepl("Content-Type: audio/wav", resp, fixed = TRUE))
expect_true(grepl('Content-Disposition: attachment; filename="speech.wav"',
                  resp, fixed = TRUE))
expect_true(grepl("RIFFDATA", resp, fixed = TRUE))

# a plain string filename works too
download_handler(s, "dl2", filename = "notes.txt",
                 content = function(file) writeLines("hi", file))
resp2 <- rawToChar(handle_download(req("session=d1&id=dl2")))
expect_true(grepl("Content-Type: text/plain", resp2, fixed = TRUE))

# a path in the filename is stripped, so a handler cannot suggest a
# traversal target to the browser
download_handler(s, "dl3", filename = "../../etc/passwd",
                 content = function(file) writeLines("x", file))
resp3 <- rawToChar(handle_download(req("session=d1&id=dl3")))
expect_true(grepl('filename="passwd"', resp3, fixed = TRUE))
expect_false(grepl("..", resp3, fixed = TRUE))

# failures answer honestly instead of hanging or leaking
expect_true(grepl("400", rawToChar(handle_download(req("id=dl"))),
                  fixed = TRUE))
expect_true(grepl("404", rawToChar(handle_download(req("session=nope&id=dl"))),
                  fixed = TRUE))
expect_true(grepl("404", rawToChar(handle_download(req("session=d1&id=ghost"))),
                  fixed = TRUE))

download_handler(s, "boom", filename = "x.txt",
                 content = function(file) stop("write failed"))
expect_true(grepl("500", rawToChar(handle_download(req("session=d1&id=boom"))),
                  fixed = TRUE))

download_handler(s, "badname", filename = function() stop("nope"),
                 content = function(file) writeLines("x", file))
expect_true(grepl("500",
                  rawToChar(handle_download(req("session=d1&id=badname"))),
                  fixed = TRUE))

expect_error(download_handler(list(), "x", "f", function(f) f),
             "glinty_session")
expect_error(download_handler(s, "", "f", function(f) f), "non-empty")
expect_error(download_handler(s, "x", "f", "not a function"),
             "content must be a function")
expect_error(download_handler(s, "x", 42, function(f) f), "filename must be")

# the HTTP router actually dispatches /download, not just the handler
route_http <- glinty:::route_http
routed <- rawToChar(route_http(req("session=d1&id=dl"), "<html></html>",
                               tempdir(), NULL))
expect_true(grepl("200 OK", routed, fixed = TRUE))
expect_true(grepl("RIFFDATA", routed, fixed = TRUE))
# and still serves the page at /
root_resp <- rawToChar(route_http(
    list(method = "GET", path = "/", query = ""),
    "<html>page</html>", tempdir(), NULL
))
expect_true(grepl("<html>page</html>", root_resp, fixed = TRUE))

# an ended session serves nothing
session_end(s)
expect_true(grepl("404", rawToChar(handle_download(req("session=d1&id=dl"))),
                  fixed = TRUE))

# --- the client script handles the new message types ---
js <- paste(readLines(system.file("www", "glinty.js", package = "glinty"),
                      warn = FALSE), collapse = "\n")
expect_true(grepl('case "modal":', js, fixed = TRUE))
expect_true(grepl('case "progress":', js, fixed = TRUE))
expect_true(grepl("data-g-download", js, fixed = TRUE))
expect_true(grepl("data-g-modal-close", js, fixed = TRUE))
