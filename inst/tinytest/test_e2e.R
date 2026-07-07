# End-to-end: spawn a real server child and drive it over base R
# sockets with glinty's own frame codec as the (masked) client.
# Local-only: needs sockets, a spawnable Rscript, and wall-clock time.

if (!at_home()) exit_file("e2e runs at home only")
if (!capabilities("sockets")) exit_file("no socket support")

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

# --- spawn the counter example in a child R process ---
pid_file <- tempfile("glinty-e2e-pid-")
log_file <- tempfile("glinty-e2e-log-")
app_file <- system.file("examples", "counter", "app.R",
    package = "glinty")
script <- tempfile("glinty-e2e-", fileext = ".R")
writeLines(c(
    sprintf('writeLines(as.character(Sys.getpid()), "%s")', pid_file),
    sprintf('app_obj <- source("%s", local = new.env())$value', app_file),
    sprintf("glinty::run_app(app_obj, port = %dL, quiet = TRUE)", port)
), script)

system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", script),
    wait = FALSE, stdout = log_file, stderr = log_file)

kill_child <- function() {
    if (file.exists(pid_file)) {
        pid <- suppressWarnings(as.integer(readLines(pid_file)[1L]))
        if (!is.na(pid)) {
            tools::pskill(pid)
        }
    }
}
on.exit(kill_child(), add = TRUE)

# --- wait for the port to open ---
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

# --- 1. GET / serves the page ---
writeBin(charToRaw("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"), con)
buf <- raw(0L)
repeat {
    chunk <- readBin(con, "raw", 65536L)
    if (length(chunk) == 0L) break
    buf <- c(buf, chunk)
}
close(con)
page_txt <- rawToChar(buf)
expect_true(grepl("200 OK", page_txt))
expect_true(grepl("glinty-root", page_txt))
expect_true(grepl("glinty counter", page_txt))
expect_true(grepl('data-g-event="click"', page_txt))

# --- WebSocket helpers (used for the initial and resumed sockets) ---
buf <- raw(0L)
ws_handshake <- function() {
    c2 <- connect()
    if (is.null(c2)) stop("could not connect for handshake")
    writeBin(charToRaw(paste0(
        "GET /ws HTTP/1.1\r\nHost: localhost\r\n",
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
    head_txt <- rawToChar(hbuf[seq_len(pos - 1L)])
    stopifnot(grepl("101 Switching Protocols", head_txt))
    buf <<- if (length(hbuf) > pos + 3L) {
        hbuf[(pos + 4L):length(hbuf)]
    } else {
        raw(0L)
    }
    c2
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
        if (Sys.time() > deadline) {
            stop("timeout waiting for frame")
        }
        b <- c(b, readBin(con, "raw", 8192L))
    }
}
next_json <- function(timeout = 5) {
    jsonlite::fromJSON(rawToChar(read_frame(timeout)$payload))
}

# --- 2. handshake; sessions start on the first client message ---
con <- ws_handshake()
writeBin(text_frame('{"type":"init","inputs":{}}', mask = TRUE), con)

# --- 3. config first (protocol 2), then the initial count update ---
msg <- next_json()
expect_equal(msg$type, "config")
expect_equal(msg$protocol, 2L)
expect_true(nchar(msg$session_id) == 32L)
sid <- msg$session_id

msg <- next_json()
expect_equal(msg$type, "update")
expect_equal(msg$id, "count")
expect_equal(msg$value, "0")

# --- 4. clicks bump the counter ---
writeBin(text_frame('{"type":"click","id":"inc"}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$id, "count")
expect_equal(msg$value, "1")

writeBin(text_frame('{"type":"click","id":"inc"}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$value, "2")

# --- 5. ping -> pong ---
writeBin(encode(0x9L, charToRaw("marco"), mask = TRUE), con)
f <- read_frame()
expect_equal(f$opcode, 10L)
expect_equal(rawToChar(f$payload), "marco")

# --- 6. drop the connection (no clean close: simulate a cut) ---
close(con)
Sys.sleep(0.5)

# --- 7. reconnect and resume: state survived ---
con <- ws_handshake()
writeBin(text_frame(
    sprintf('{"type":"resume","session_id":"%s"}', sid),
    mask = TRUE
), con)
msg <- next_json()
expect_equal(msg$type, "config")
expect_true(msg$resumed)
expect_equal(msg$session_id, sid)

# replayed output state: count is still 2, no clicks needed
msg <- next_json()
expect_equal(msg$type, "update")
expect_equal(msg$id, "count")
expect_equal(msg$value, "2")

# and the session is live: another click lands on the same counter
writeBin(text_frame('{"type":"click","id":"inc"}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$value, "3")

# --- 8. clean close -> close echo ---
writeBin(encode(0x8L, as.raw(c(0x03, 0xE8)), mask = TRUE), con)
f <- read_frame()
expect_equal(f$opcode, 8L)
close(con)

# --- 9. resume with a bogus id gets an honest resumed=false ---
con <- ws_handshake()
writeBin(text_frame(
    '{"type":"resume","session_id":"deadbeefdeadbeefdeadbeefdeadbeef"}',
    mask = TRUE
), con)
msg <- next_json()
expect_equal(msg$type, "config")
expect_false(msg$resumed)
close(con)

kill_child()
