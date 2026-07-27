# Wire transcripts: the frames, in order, that both clients replay.
#
# The component fixtures cover trees. These cover the conversation. A
# client that renders every component and fumbles the opening exchange
# is broken in a way no fixture would catch, so the exchange is an
# artifact too.

component <- glinty:::component
ui_revision <- glinty:::ui_revision
wire_transcripts <- glinty:::wire_transcripts
transcript_json <- glinty:::transcript_json
transcript_json_path <- glinty:::transcript_json_path
PROTOCOL_VERSION <- glinty:::PROTOCOL_VERSION

# --- ui_revision ---
ui1 <- component("page", title = "Demo", children = list(
    component("heading", value = "Demo", level = 1L)
))
rev1 <- ui_revision(ui1)
expect_true(is.character(rev1))
expect_equal(nchar(rev1), 64L)
expect_true(grepl("^[0-9a-f]{64}$", rev1))

# same tree, same revision: it has to be stable or hydration never
# adopts anything
expect_equal(ui_revision(ui1), rev1)
ui1b <- component("page", title = "Demo", children = list(
    component("heading", value = "Demo", level = 1L)
))
expect_equal(ui_revision(ui1b), rev1)

# any change to the tree changes it
ui2 <- component("page", title = "Demo", children = list(
    component("heading", value = "Demo!", level = 1L)
))
expect_true(ui_revision(ui2) != rev1)
ui3 <- component("page", title = "Other", children = list(
    component("heading", value = "Demo", level = 1L)
))
expect_true(ui_revision(ui3) != rev1)
# including a change of level only
ui4 <- component("page", title = "Demo", children = list(
    component("heading", value = "Demo", level = 2L)
))
expect_true(ui_revision(ui4) != rev1)

# a page carries assets off the wire, so they must not move the
# revision: the tree is what a client renders
p1 <- page(heading("Demo", level = 1L), title = "Demo")
p2 <- page(heading("Demo", level = 1L), title = "Demo",
    css = "/app.css")
expect_equal(ui_revision(p1), ui_revision(p2))

# --- transcript shape ---
tr <- wire_transcripts()
expect_true(length(tr) >= 6L)
nms <- vapply(tr, function(t) t$name, character(1L))
expect_equal(anyDuplicated(nms), 0L)
for (t in tr) {
    expect_true(is.character(t$name) && nzchar(t$name))
    expect_true(is.character(t$notes) && nzchar(t$notes))
    expect_true(length(t$frames) >= 1L)
    for (fr in t$frames) {
        expect_true(fr$dir %in% c("in", "out"))
        expect_true(is.character(fr$message$type) && nzchar(fr$message$type))
    }
}

# every transcript names an exchange, so it opens with a client frame
# and answers it
for (t in tr) {
    expect_equal(t$frames[[1L]]$dir, "in")
    expect_true(any(vapply(t$frames, function(fr) fr$dir == "out",
                           logical(1L))))
}

by_name <- function(name) {
    hit <- Filter(function(t) identical(t$name, name), tr)
    if (length(hit) == 0L) NULL else hit[[1L]]
}

# --- the opening exchange ---
hw <- by_name("hello-welcome")
expect_true(!is.null(hw))
hello <- hw$frames[[1L]]$message
expect_equal(hello$type, "hello")
expect_equal(hello$protocol, PROTOCOL_VERSION)
# capability declaration, not negotiation: the client says what it can
# draw and the server sends the tree regardless
expect_true(length(hello$components) > 0L)
expect_true("page" %in% as.character(hello$components))

welcome <- hw$frames[[2L]]$message
expect_equal(welcome$type, "welcome")
expect_equal(welcome$protocol, PROTOCOL_VERSION)
expect_equal(welcome$ui$component, "page")
# the revision in welcome is the revision of the tree in welcome; a
# transcript that lies about this teaches every client the wrong thing
expect_equal(welcome$ui_revision, ui_revision(welcome$ui))
# the theme is the full default token set, and it does not move the
# revision: tokens ride beside the tree, like a stylesheet would
expect_equal(welcome$theme, glinty:::theme_wire(app_theme()))
expect_equal(welcome$theme$colors$primary, "#2456d6")

# --- hydration cases ---
hyd <- by_name("hello-welcome-hydrated")
expect_true(!is.null(hyd))
# adoption case: what the client already has matches what it is sent
expect_equal(hyd$frames[[1L]]$message$prerendered,
             hyd$frames[[2L]]$message$ui_revision)
# and the client sends nothing further: adoption is not interaction,
# so no input frames follow
after <- hyd$frames[seq_along(hyd$frames) > 2L]
expect_equal(length(Filter(function(fr) fr$dir == "in", after)), 0L)

mis <- by_name("revision-mismatch")
expect_true(!is.null(mis))
expect_true(mis$frames[[1L]]$message$prerendered !=
                mis$frames[[2L]]$message$ui_revision)
# The mismatching value is realistic (revisions are opaque to
# clients, so a client must not shape-check its way past this case;
# the fixture being hash-shaped keeps that temptation unrewarded).
expect_true(grepl("^[0-9a-f]{64}$", mis$frames[[1L]]$message$prerendered))

pm <- by_name("protocol-mismatch")
expect_true(!is.null(pm))
expect_equal(pm$frames[[1L]]$message$protocol, PROTOCOL_VERSION)
expect_true(pm$frames[[2L]]$message$protocol > PROTOCOL_VERSION)
# it carries a tree the client would otherwise render happily: the
# refusal has to come from the version, not from failing to parse
expect_equal(pm$frames[[2L]]$message$ui$component, "page")

# --- inputs and outputs ---
io <- by_name("input-then-output")
expect_true(!is.null(io))
expect_equal(io$frames[[1L]]$message$type, "input")
expect_equal(io$frames[[2L]]$message$type, "output")
expect_true(io$frames[[2L]]$message$kind %in% unlist(glinty:::OUTPUT_KINDS))

au <- by_name("hello-authenticated")
expect_true(!is.null(au))
expect_true(is.character(au$frames[[1L]]$message$token))
expect_equal(au$frames[[2L]]$message$type, "welcome")

tg <- by_name("ticket-grant")
expect_true(!is.null(tg))
treq <- tg$frames[[1L]]$message
tgrant <- tg$frames[[2L]]$message
expect_equal(treq$type, "ticket")
expect_true(treq$purpose %in% c("upload", "download"))
expect_null(treq$token)
expect_equal(tgrant$type, "ticket")
expect_equal(tgrant$id, treq$id)
expect_equal(tgrant$purpose, treq$purpose)
expect_true(is.character(tgrant$token) && nzchar(tgrant$token))
# expires is a relative TTL in seconds, not an absolute clock
expect_true(is.numeric(tgrant$expires) && tgrant$expires > 0 &&
                tgrant$expires < 3600)

ev <- by_name("button-event")
expect_true(!is.null(ev))
expect_equal(ev$frames[[1L]]$message$type, "event")
expect_true(is.character(ev$frames[[1L]]$message$id))
# an event carries no value field at all
expect_null(ev$frames[[1L]]$message$value)

ms <- by_name("measure-then-image")
expect_true(!is.null(ms))
expect_equal(ms$frames[[1L]]$message$type, "measure")
expect_true(ms$frames[[1L]]$message$width > 0L)
expect_true(ms$frames[[1L]]$message$height > 0L)
expect_equal(ms$frames[[2L]]$message$kind, "image")

# every message type used is one PROTOCOL.md declares
known <- c("hello", "welcome", "input", "output", "measure", "event",
           "input_update", "ticket", "modal", "progress", "custom",
           "error", "ping", "pong")
for (t in tr) {
    for (fr in t$frames) {
        expect_true(fr$message$type %in% known)
    }
}

# --- the checked-in JSON matches the R definition ---
path <- transcript_json_path()
if (nzchar(path) && file.exists(path)) {
    on_disk <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_equal(trimws(on_disk), trimws(transcript_json()))

    parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    expect_equal(parsed$protocol, PROTOCOL_VERSION)
    expect_equal(length(parsed$transcripts), length(tr))
    for (i in seq_along(tr)) {
        expect_equal(parsed$transcripts[[i]]$name, tr[[i]]$name)
        expect_equal(length(parsed$transcripts[[i]]$frames),
                     length(tr[[i]]$frames))
    }

    # capability lists must survive as arrays, not collapse to scalars
    # on the way out; a client indexing them would break on a
    # one-element list
    ph <- parsed$transcripts[[1L]]$frames[[1L]]$message
    expect_true(is.list(ph$kinds))
    expect_equal(length(ph$kinds), 1L)
} else {
    exit_file("transcript JSON not installed")
}
