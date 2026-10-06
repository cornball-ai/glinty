# audio_input: the microphone as a component. The recorder itself is
# browser code (its declarations are asserted here and its build in
# tools/jsbridge.js); this pins the schema, the lowering, the input
# contract, and the upload route's text-field columns the chunk index
# rides on.

component <- glinty:::component
component_to_html <- glinty:::component_to_html
INPUT_META <- glinty:::INPUT_META

# --- constructor and schema ---
x <- glinty::audio_input("take")
expect_equal(x$component, "audio_input")
expect_equal(x$label, "Record")
expect_null(x$chunk)
expect_null(x$mime)
y <- glinty::audio_input("live", "Dictate", chunk = 5,
                         mime = "audio/webm;codecs=opus")
expect_equal(y$chunk, 5)
expect_equal(y$mime, "audio/webm;codecs=opus")
expect_error(glinty::audio_input("x", chunk = 0), "positive")
expect_error(glinty::audio_input("x", chunk = -1), "positive")
expect_error(glinty::audio_input("x", chunk = "5"), "positive")
expect_error(glinty::audio_input("x", chunk = c(1, 2)), "positive")
expect_error(component("audio_input", id = "x", accept = ".wav"),
             "unknown field")

# it reports as an input whose value is files, like file_input
expect_equal(INPUT_META$audio_input$message, "input")
expect_equal(INPUT_META$audio_input$value_type, "files")
# and seeds nothing: no recording exists before one is made
expect_null(glinty:::input_seed_value(x))

# --- the browser lowering ---
html <- component_to_html(y)
expect_true(grepl("<button", html, fixed = TRUE))
expect_true(grepl('id="live"', html, fixed = TRUE))
expect_true(grepl('data-g-target="live"', html, fixed = TRUE))
expect_true(grepl('data-g-message="input"', html, fixed = TRUE))
expect_true(grepl('data-g-record="live"', html, fixed = TRUE))
expect_true(grepl('data-g-chunk="5"', html, fixed = TRUE))
expect_true(grepl('data-g-mime="audio/webm;codecs=opus"', html, fixed = TRUE))
expect_true(grepl('class="g-btn g-record"', html, fixed = TRUE))
expect_true(grepl(">Dictate</button>", html, fixed = TRUE))
# the button's text is its label: no <label for>
expect_false(grepl("<label", html, fixed = TRUE))
plain <- component_to_html(x)
expect_false(grepl("data-g-chunk", plain, fixed = TRUE))
expect_false(grepl("data-g-mime", plain, fixed = TRUE))
expect_true(grepl(">Record</button>", plain, fixed = TRUE))
# the label is escaped like any text
expect_true(grepl("&lt;", component_to_html(glinty::audio_input("t", "<rec>")),
                  fixed = TRUE))

# --- the browser client answers for it ---
js <- paste(readLines(system.file("www", "glinty.js", package = "glinty"),
                      warn = FALSE), collapse = "\n")
expect_true(grepl('"audio_input"', js, fixed = TRUE))
expect_true(grepl('"record"', js, fixed = TRUE))
expect_true(grepl("function toggleRecording", js, fixed = TRUE))
expect_true(grepl("data-g-record", js, fixed = TRUE))
expect_true(grepl('"_chunk"', js, fixed = TRUE))
expect_true(grepl('"_state"', js, fixed = TRUE))
# a fixture obliges every client to answer for it
fx <- glinty:::component_fixtures()
expect_true("audio_input" %in%
            vapply(fx, function(f) f$component$component, character(1L)))

# --- the upload route: text fields become columns (the chunk index) ---
handle_upload <- glinty:::handle_upload
issue_ticket <- glinty:::issue_ticket
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL
s <- glinty:::new_session("rec1")
seen <- NULL
glinty::observe_event(s$input$take_chunk, function(v) seen <<- v)
bytes <- as.raw(c(0x1A, 0x45, 0xDF, 0xA3, 1:32))
b <- "glintyRecBoundary"
crlf <- "\r\n"
body <- c(
    charToRaw(paste0("--", b, crlf,
        'Content-Disposition: form-data; name="file"; filename="chunk-3.webm"',
        crlf, "Content-Type: audio/webm", crlf, crlf)),
    bytes, charToRaw(crlf),
    charToRaw(paste0("--", b, crlf,
        'Content-Disposition: form-data; name="index"', crlf, crlf,
        "3", crlf)),
    charToRaw(paste0("--", b, crlf,
        'Content-Disposition: form-data; name="name"', crlf, crlf,
        "not-the-file-column", crlf)),
    charToRaw(paste0("--", b, "--", crlf))
)
req <- list(method = "POST", path = "/upload",
            query = paste0("ticket=",
                           issue_ticket(s, "take_chunk", "upload")$token),
            headers = c("content-type" = paste0(
                "multipart/form-data; boundary=", b)),
            body = body)
expect_true(grepl("200 OK", rawToChar(handle_upload(req))))
glinty::flush_reactions()
expect_true(is.data.frame(seen))
expect_equal(nrow(seen), 1L)
expect_equal(seen$name, "chunk-3.webm")
expect_equal(seen$index, "3")
expect_identical(readBin(seen$datapath, "raw", seen$size), bytes)
# a field named like a file column does not overwrite it
expect_false(identical(seen$name, "not-the-file-column"))
glinty:::session_end(s)
