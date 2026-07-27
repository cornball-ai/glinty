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

# --- 0. /healthz answers before any session exists ---
hz_con <- connect()
writeBin(charToRaw("GET /healthz HTTP/1.1\r\nHost: localhost\r\n\r\n"),
    hz_con)
hz <- raw(0L)
repeat {
    chunk <- readBin(hz_con, "raw", 65536L)
    if (length(chunk) == 0L) break
    hz <- c(hz, chunk)
}
close(hz_con)
hz_txt <- rawToChar(hz)
expect_true(grepl("200 OK", hz_txt))
expect_true(grepl('"status":"ok"', hz_txt, fixed = TRUE))
expect_true(grepl('"sessions":0', hz_txt, fixed = TRUE))

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
# buttons declare themselves as event emitters
expect_true(grepl('data-g-message="event"', page_txt))
# and the served page carries the revision the welcome will repeat
rev_meta <- regmatches(page_txt,
    regexpr('name="g-ui-revision" content="[0-9a-f]{64}"', page_txt))
expect_equal(length(rev_meta), 1L)
page_rev <- sub('.*content="([0-9a-f]{64})".*', "\\1", rev_meta)

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
writeBin(text_frame('{"type":"hello","protocol":3,"client":"e2e/1"}', mask = TRUE), con)

# --- 3. welcome first (protocol 3), then the initial count update ---
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_equal(msg$protocol, 3L)
expect_true(nchar(msg$session) == 32L)
sid <- msg$session
# the welcome carries the tree and repeats the served revision
expect_equal(msg$ui$component, "page")
expect_equal(msg$ui_revision, page_rev)

msg <- next_json()
expect_equal(msg$type, "output")
expect_equal(msg$id, "count")
expect_equal(msg$value, "0")

# --- 4. clicks bump the counter ---
writeBin(text_frame('{"type":"event","id":"inc"}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$id, "count")
expect_equal(msg$value, "1")

writeBin(text_frame('{"type":"event","id":"inc"}', mask = TRUE), con)
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

# --- 7. reconnect and resume: hello carries the old session id ---
con <- ws_handshake()
writeBin(text_frame(
    sprintf('{"type":"hello","protocol":3,"client":"e2e/1","resume":"%s"}',
            sid),
    mask = TRUE
), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_true(msg$resumed)
expect_equal(msg$session, sid)

# replayed output state: count is still 2, no clicks needed
msg <- next_json()
expect_equal(msg$type, "output")
expect_equal(msg$id, "count")
expect_equal(msg$value, "2")

# and the session is live: another click lands on the same counter
writeBin(text_frame('{"type":"event","id":"inc"}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$value, "3")

# --- 8. clean close -> close echo ---
writeBin(encode(0x8L, as.raw(c(0x03, 0xE8)), mask = TRUE), con)
f <- read_frame()
expect_equal(f$opcode, 8L)
close(con)

# --- 8b. a first frame that is not a hello is refused outright ---
con <- ws_handshake()
writeBin(text_frame('{"type":"input","id":"x","value":1}', mask = TRUE),
    con)
msg <- next_json()
expect_equal(msg$type, "error")
expect_true(grepl("hello", msg$message))
close(con)

# --- 9. resume with a bogus id gets an honest resumed=false ---
con <- ws_handshake()
writeBin(text_frame(
    paste0('{"type":"hello","protocol":3,"client":"e2e/1",',
           '"resume":"deadbeefdeadbeefdeadbeefdeadbeef"}'),
    mask = TRUE
), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_false(msg$resumed)
close(con)

# --- 10. multipart upload via a ticket minted over the socket ---
# fresh WS session for the upload test
con <- ws_handshake()
writeBin(text_frame('{"type":"hello","protocol":3,"client":"e2e/1"}', mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
next_json() # initial count update, ignore

writeBin(text_frame('{"type":"ticket","id":"f","purpose":"upload"}',
    mask = TRUE), con)
grant <- next_json()
expect_equal(grant$type, "ticket")
expect_equal(grant$purpose, "upload")
expect_true(startsWith(grant$token, "tk_"))

payload <- as.raw(c(137, 80, 78, 71, 13, 10, 26, 10, 0:63))
bnd <- "glintyE2Eboundary"
mp_body <- c(
    charToRaw(paste0(
        "--", bnd, "\r\n",
        "Content-Disposition: form-data; name=\"file\"; ",
        "filename=\"blob.bin\"\r\n\r\n"
    )),
    payload,
    charToRaw(paste0("\r\n--", bnd, "--\r\n"))
)
post_con <- connect()
writeBin(c(charToRaw(paste0(
    "POST /upload?ticket=", grant$token, " HTTP/1.1\r\n",
    "Host: localhost\r\n",
    "Content-Type: multipart/form-data; boundary=", bnd, "\r\n",
    "Content-Length: ", length(mp_body), "\r\n\r\n"
)), mp_body), post_con)
up_resp <- raw(0L)
repeat {
    chunk <- readBin(post_con, "raw", 65536L)
    if (length(chunk) == 0L) break
    up_resp <- c(up_resp, chunk)
}
close(post_con)
expect_true(grepl("200 OK", rawToChar(up_resp)))
expect_true(grepl('"ok":true', rawToChar(up_resp)))

# replaying the consumed ticket gets a refusal, not a second upload
post_con2 <- connect()
writeBin(c(charToRaw(paste0(
    "POST /upload?ticket=", grant$token, " HTTP/1.1\r\n",
    "Host: localhost\r\n",
    "Content-Type: multipart/form-data; boundary=", bnd, "\r\n",
    "Content-Length: ", length(mp_body), "\r\n\r\n"
)), mp_body), post_con2)
replay <- raw(0L)
repeat {
    chunk <- readBin(post_con2, "raw", 65536L)
    if (length(chunk) == 0L) break
    replay <- c(replay, chunk)
}
close(post_con2)
expect_true(grepl("403", rawToChar(replay), fixed = TRUE))
close(con)

kill_child()

# --- 11. run_app(auth = ): the gate holds over a real socket ---
auth_port <- NULL
for (i in 1:20) {
    candidate <- sample(18000:19999, 1L)
    srv <- tryCatch(serverSocket(candidate), error = function(e) NULL)
    if (!is.null(srv)) {
        close(srv)
        auth_port <- candidate
        break
    }
}
if (is.null(auth_port)) exit_file("no free port for the auth server")

auth_pid <- tempfile("glinty-e2e-authpid-")
auth_log <- tempfile("glinty-e2e-authlog-")
auth_script <- tempfile("glinty-e2e-auth-", fileext = ".R")
writeLines(c(
    sprintf('writeLines(as.character(Sys.getpid()), "%s")', auth_pid),
    "library(glinty)",
    'a <- app(ui = page(text_output("who"), title = "gated"),',
    "         server = function(input, output, session) {",
    '             output$who <- render_text(function()',
    '                 session$principal$id)',
    "         })",
    sprintf(paste0(
        "run_app(a, port = %dL, quiet = TRUE,\n",
        "        auth = function(token) {\n",
        '            if (identical(token, "letmein")) list(id = "u_42")\n',
        '            else if (identical(token, "letmein2")) list(id = "u_43")\n',
        "        })"), auth_port)
), auth_script)
system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", auth_script),
    wait = FALSE, stdout = auth_log, stderr = auth_log)
kill_auth <- function() {
    if (file.exists(auth_pid)) {
        pid <- suppressWarnings(as.integer(readLines(auth_pid)[1L]))
        if (!is.na(pid)) tools::pskill(pid)
    }
}
on.exit(kill_auth(), add = TRUE)

connect_auth <- function() {
    tryCatch(
        suppressWarnings(socketConnection("127.0.0.1", auth_port,
            open = "r+b", blocking = TRUE, timeout = 5)),
        error = function(e) NULL
    )
}
con <- NULL
deadline <- Sys.time() + 15
while (Sys.time() < deadline) {
    con <- connect_auth()
    if (!is.null(con)) break
    Sys.sleep(0.25)
}
if (is.null(con)) {
    exit_file(paste("auth server never came up:",
        paste(readLines(auth_log, warn = FALSE), collapse = " | ")))
}
close(con)

ws_handshake_auth <- function() {
    c2 <- connect_auth()
    if (is.null(c2)) stop("could not connect for auth handshake")
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
    buf <<- if (length(hbuf) > pos + 3L) {
        hbuf[(pos + 4L):length(hbuf)]
    } else {
        raw(0L)
    }
    c2
}

# no token: one error frame, then the server closes the socket
con <- ws_handshake_auth()
writeBin(text_frame('{"type":"hello","protocol":3,"client":"e2e/1"}',
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "error")
expect_true(grepl("authentication", msg$message))
# the connection is closed: the next read hits EOF, not a welcome
eof <- tryCatch({
    deadline <- Sys.time() + 5
    got <- raw(0L)
    while (Sys.time() < deadline && length(got) == 0L) {
        got <- readBin(con, "raw", 8192L)
        f <- glinty:::ws_decode_frame(c(buf, got))
        if (!is.null(f) && f$opcode == 8L) {
            got <- raw(0L)
            break
        }
        if (length(got) == 0L) break
    }
    length(got) == 0L
}, error = function(e) TRUE)
expect_true(eof)
close(con)

# the wrong token is refused the same way
con <- ws_handshake_auth()
writeBin(text_frame(
    '{"type":"hello","protocol":3,"client":"e2e/1","token":"guess"}',
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "error")
close(con)

# the right token gets a welcome, and the principal reaches the app
con <- ws_handshake_auth()
writeBin(text_frame(
    '{"type":"hello","protocol":3,"client":"e2e/1","token":"letmein"}',
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
a_sid <- msg$session
msg <- next_json()
expect_equal(msg$type, "output")
expect_equal(msg$id, "who")
expect_equal(msg$value, "u_42")
# cut the socket so user A's session detaches with state to steal
close(con)
Sys.sleep(0.5)

# resume is principal-bound: user B's valid token plus user A's
# session id gets a fresh session, never A's replay
con <- ws_handshake_auth()
writeBin(text_frame(sprintf(
    paste0('{"type":"hello","protocol":3,"client":"e2e/1",',
           '"token":"letmein2","resume":"%s"}'), a_sid),
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_false(msg$resumed)
expect_true(msg$session != a_sid)
close(con)
Sys.sleep(0.3)

# while A's own refreshed token resumes A's session
con <- ws_handshake_auth()
writeBin(text_frame(sprintf(
    paste0('{"type":"hello","protocol":3,"client":"e2e/1",',
           '"token":"letmein","resume":"%s"}'), a_sid),
    mask = TRUE), con)
msg <- next_json()
expect_equal(msg$type, "welcome")
expect_true(msg$resumed)
expect_equal(msg$session, a_sid)
close(con)

kill_auth()
