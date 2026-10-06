# End-to-end over the civetwebR transport: the same child-process
# drive as test_e2e.R, with run_app(host = "127.0.0.1"). The hand-
# rolled client speaks RFC 6455 to CivetWeb exactly as it does to the
# base transport; what differs is who parses it. Local-only: needs
# sockets, a spawnable Rscript, civetwebR, and wall-clock time.

if (!at_home()) exit_file("e2e runs at home only")
if (!capabilities("sockets")) exit_file("no socket support")
if (!requireNamespace("civetwebR", quietly = TRUE)) {
    exit_file("civetwebR not installed")
}

decode <- glinty:::ws_decode_frame
text_frame <- glinty:::ws_text_frame
encode <- glinty:::ws_encode_frame
find_end <- glinty:::find_header_end

# --- find a free port ---
port <- NULL
for (i in 1:20) {
    candidate <- sample(18000:19999, 1L)
    srv <- tryCatch(serverSocket(candidate), error = function(e) NULL)
    if (!is.null(srv)) {
        close(srv)
        port <- candidate
        break
    }
}
if (is.null(port)) exit_file("no free port")

# --- spawn the counter example bound to loopback through civetwebR ---
pid_file <- tempfile("glinty-cw-pid-")
log_file <- tempfile("glinty-cw-log-")
app_file <- system.file("examples", "counter", "app.R", package = "glinty")
script <- tempfile("glinty-cw-", fileext = ".R")
writeLines(c(
    sprintf('writeLines(as.character(Sys.getpid()), "%s")', pid_file),
    sprintf('app_obj <- source("%s", local = new.env())$value', app_file),
    sprintf(paste0('glinty::run_app(app_obj, port = %dL, host = "127.0.0.1", ',
                   "quiet = TRUE)"), port)
), script)
system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", script),
    wait = FALSE, stdout = log_file, stderr = log_file)

kill_child <- function() {
    if (file.exists(pid_file)) {
        pid <- suppressWarnings(as.integer(readLines(pid_file)[1L]))
        if (!is.na(pid)) tools::pskill(pid)
    }
}
on.exit(kill_child(), add = TRUE)

connect <- function() {
    tryCatch(
        suppressWarnings(socketConnection("127.0.0.1", port, open = "r+b",
            blocking = TRUE, timeout = 5)),
        error = function(e) NULL
    )
}
con <- NULL
deadline <- Sys.time() + 15
while (Sys.time() < deadline) {
    con <- connect()
    if (!is.null(con)) break
    Sys.sleep(0.25)
}
if (is.null(con)) {
    exit_file(paste("server never came up:",
        paste(readLines(log_file, warn = FALSE), collapse = " | ")))
}
close(con)

http_exchange <- function(bytes) {
    c2 <- connect()
    writeBin(bytes, c2)
    out <- raw(0L)
    repeat {
        chunk <- readBin(c2, "raw", 65536L)
        if (length(chunk) == 0L) break
        out <- c(out, chunk)
    }
    close(c2)
    rawToChar(out)
}

# --- 0. /healthz through CivetWeb's parser and glinty's router ---
hz_txt <- http_exchange(charToRaw(
    "GET /healthz HTTP/1.1\r\nHost: localhost\r\n\r\n"))
expect_true(grepl("200 OK", hz_txt))
expect_true(grepl('"status":"ok"', hz_txt, fixed = TRUE))
expect_true(grepl("Content-Type: application/json", hz_txt, fixed = TRUE))

# --- 1. GET / serves the page, with the revision the welcome repeats ---
page_txt <- http_exchange(charToRaw("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"))
expect_true(grepl("200 OK", page_txt))
expect_true(grepl("glinty-root", page_txt))
expect_true(grepl("glinty counter", page_txt))
rev_meta <- regmatches(page_txt,
    regexpr('name="g-ui-revision" content="[0-9a-f]{64}"', page_txt))
expect_equal(length(rev_meta), 1L)
page_rev <- sub('.*content="([0-9a-f]{64})".*', "\\1", rev_meta)

# --- 1b. a framework asset, with a byte range, through serve_static() ---
js_txt <- http_exchange(charToRaw(paste0(
    "GET /glinty/glinty.js HTTP/1.1\r\nHost: localhost\r\n",
    "Range: bytes=0-9\r\n\r\n")))
expect_true(grepl("206 Partial Content", js_txt))
expect_true(grepl("Content-Range: bytes 0-9/", js_txt, fixed = TRUE))
expect_equal(nchar(sub("^.*\r\n\r\n", "", js_txt)), 10L)

# --- 1c. an unknown path is glinty's 404, not CivetWeb's ---
expect_true(grepl("404", http_exchange(charToRaw(
    "GET /nope HTTP/1.1\r\nHost: localhost\r\n\r\n"))))

# --- WebSocket helpers ---
buf <- raw(0L)
upgrade <- function(origin = NULL) {
    c2 <- connect()
    if (is.null(c2)) stop("could not connect for handshake")
    writeBin(charToRaw(paste0(
        "GET /ws HTTP/1.1\r\nHost: localhost:", port, "\r\n",
        if (is.null(origin)) "" else paste0("Origin: ", origin, "\r\n"),
        "Upgrade: websocket\r\nConnection: keep-alive, Upgrade\r\n",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n",
        "Sec-WebSocket-Version: 13\r\n\r\n"
    )), c2)
    hbuf <- raw(0L)
    pos <- -1L
    deadline <- Sys.time() + 5
    while (Sys.time() < deadline) {
        hbuf <- c(hbuf, readBin(c2, "raw", 8192L))
        pos <- find_end(hbuf)
        if (pos > 0L) break
    }
    stopifnot(pos > 0L)
    buf <<- if (length(hbuf) > pos + 3L) hbuf[(pos + 4L):length(hbuf)] else raw(0L)
    list(con = c2, head = rawToChar(hbuf[seq_len(pos - 1L)]))
}
ws_handshake <- function() {
    u <- upgrade()
    stopifnot(grepl("101 Switching Protocols", u$head))
    u$con
}
read_frame <- function(timeout = 5) {
    deadline <- Sys.time() + timeout
    b <- buf
    repeat {
        f <- decode(b)
        if (!is.null(f)) {
            buf <<- f$rest
            return(f)
        }
        if (Sys.time() > deadline) stop("timeout waiting for frame")
        b <- c(b, readBin(con, "raw", 8192L))
    }
}
next_json <- function(timeout = 5) {
    jsonlite::fromJSON(rawToChar(read_frame(timeout)$payload))
}

# --- 2. the Origin policy runs before the handshake: a foreign page
# is refused with 403, never upgraded ---
u <- upgrade(origin = "http://evil.example")
expect_true(grepl("403", u$head))
close(u$con)
# the page's own origin is fine
u <- upgrade(origin = paste0("http://localhost:", port))
expect_true(grepl("101", u$head))
close(u$con)

# --- 3. hello -> welcome, then the initial count ---
con <- ws_handshake()
writeBin(text_frame('{"type":"hello","protocol":4,"client":"e2e/1"}',
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_equal(msg$protocol, 4L)
expect_equal(msg$ui_revision, page_rev)
sid <- msg$session
msg <- next_json()
expect_equal(msg$type, "output")
expect_equal(msg$value, "0")

# --- 4. a click, whole; then a click fragmented over two frames ---
writeBin(text_frame('{"type":"event","id":"inc"}', mask = TRUE), con)
expect_equal(next_json()$value, "1")
writeBin(c(encode(1L, charToRaw('{"type":"event",'), mask = TRUE, fin = FALSE),
           encode(0L, charToRaw('"id":"inc"}'), mask = TRUE, fin = TRUE)), con)
expect_equal(next_json()$value, "2")

# --- 5. ping -> pong, answered by CivetWeb ---
writeBin(encode(0x9L, charToRaw("marco"), mask = TRUE), con)
f <- read_frame()
expect_equal(f$opcode, 10L)
expect_equal(rawToChar(f$payload), "marco")

# --- 6. cut the connection, then resume on a new one ---
close(con)
Sys.sleep(0.5)
con <- ws_handshake()
writeBin(text_frame(sprintf(
    '{"type":"hello","protocol":4,"client":"e2e/1","resume":"%s"}', sid),
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_true(msg$resumed)
expect_equal(msg$session, sid)
msg <- next_json()
expect_equal(msg$value, "2")
writeBin(text_frame('{"type":"event","id":"inc"}', mask = TRUE), con)
expect_equal(next_json()$value, "3")

# --- 7. a clean close is echoed with the client's code ---
writeBin(encode(0x8L, as.raw(c(0x03, 0xE8)), mask = TRUE), con)
f <- read_frame()
expect_equal(f$opcode, 8L)
expect_equal(f$payload, as.raw(c(0x03, 0xE8)))
close(con)

# --- 8. a first frame that is not a hello is refused outright ---
con <- ws_handshake()
writeBin(text_frame('{"type":"input","id":"x","value":1}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "error")
expect_true(grepl("hello", msg$message))
close(con)

# --- 9. multipart upload: a POST body through CivetWeb to handle_upload() ---
con <- ws_handshake()
writeBin(text_frame('{"type":"hello","protocol":4,"client":"e2e/1"}',
    mask = TRUE), con)
expect_equal(next_json()$type, "welcome")
next_json()
writeBin(text_frame('{"type":"ticket","id":"f","purpose":"upload"}',
    mask = TRUE), con)
grant <- next_json()
expect_equal(grant$purpose, "upload")

payload <- as.raw(c(137, 80, 78, 71, 13, 10, 26, 10, 0:63))
bnd <- "glintyCWboundary"
mp_body <- c(
    charToRaw(paste0("--", bnd, "\r\n",
        "Content-Disposition: form-data; name=\"file\"; ",
        "filename=\"blob.bin\"\r\n\r\n")),
    payload,
    charToRaw(paste0("\r\n--", bnd, "--\r\n"))
)
post <- function() {
    http_exchange(c(charToRaw(paste0(
        "POST /upload?ticket=", grant$token, " HTTP/1.1\r\n",
        "Host: localhost\r\n",
        "Content-Type: multipart/form-data; boundary=", bnd, "\r\n",
        "Content-Length: ", length(mp_body), "\r\n\r\n")), mp_body))
}
up <- post()
expect_true(grepl("200 OK", up))
expect_true(grepl('"ok":true', up, fixed = TRUE))
# the consumed ticket is refused on replay
expect_true(grepl("403", post(), fixed = TRUE))
close(con)

kill_child()
