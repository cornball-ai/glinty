# The served file browser: pure helpers, then the wired picker driven
# through a real session -- unit-correct pieces can still be wired
# into a picker that disables itself, so the wiring is what the
# session half exercises (open, step, choose, and open AGAIN).

path_picker <- glinty::path_picker
picker_entries <- glinty:::picker_entries
picker_crumbs <- glinty:::picker_crumbs
picker_step <- glinty:::picker_step
path_within <- glinty:::path_within

# --- a tempdir tree to walk ---
base <- file.path(tempdir(), "picker-test")
unlink(base, recursive = TRUE)
dir.create(file.path(base, "alpha", "inner"), recursive = TRUE)
dir.create(file.path(base, "Beta"))
dir.create(file.path(base, ".hid"))
writeLines("x", file.path(base, "notes.txt"))
writeLines("x", file.path(base, "alpha", "clip.mp4"))
writeLines("x", file.path(base, ".secret"))
base <- normalizePath(base, winslash = "/")
alpha <- normalizePath(file.path(base, "alpha"), winslash = "/")
inner <- normalizePath(file.path(base, "alpha", "inner"), winslash = "/")

# --- entries: dirs sorted case-insensitively, dotfiles hidden ---
e <- picker_entries(base)
expect_equal(e$dirs, c("alpha", "Beta"))
expect_equal(e$files, character(0L))
expect_equal(picker_entries(base, kind = "file")$files, "notes.txt")
e3 <- picker_entries(base, kind = "file", hidden = TRUE)
expect_true(".secret" %in% e3$files)
expect_true(".hid" %in% e3$dirs)
expect_equal(picker_entries(base, kind = "file",
                            pattern = "\\.mp4$")$files, character(0L))
expect_equal(picker_entries(alpha, kind = "file",
                            pattern = "\\.mp4$")$files, "clip.mp4")
# absent directory: empty, not an error
expect_equal(picker_entries(file.path(base, "gone"))$dirs, character(0L))
expect_equal(picker_entries(NULL)$dirs, character(0L))

# --- crumbs: root first, stopping at root when one is set ---
cr <- picker_crumbs(inner, root = base)
expect_equal(cr$path[[1L]], base)
expect_equal(cr$name, c(basename(base), "alpha", "inner"))
expect_equal(cr$path[[3L]], inner)
cr_all <- picker_crumbs(inner)
expect_equal(cr_all$name[[1L]], "/")
expect_equal(cr_all$path[[1L]], "/")
expect_equal(nrow(picker_crumbs(NULL)), 0L)

# --- step: canonical, bounded, stays put on nonsense ---
expect_equal(picker_step(base, file.path(base, "alpha")), alpha)
expect_equal(picker_step(base, file.path(base, "gone")), base)
expect_equal(picker_step(base, ""), base)
expect_equal(picker_step(base, NULL), base)
expect_equal(picker_step(base, 42), base)
# ".." resolves before the root check, so it cannot sneak below root
expect_equal(picker_step(inner, file.path(inner, "..", ".."), root = inner),
             inner)
expect_equal(picker_step(inner, file.path(inner, "..", "..")), base)
expect_equal(picker_step(base, dirname(base), root = base), base)

expect_true(path_within(base, base))
expect_true(path_within(inner, base))
expect_false(path_within(dirname(base), base))
expect_true(path_within(inner, "/"))
# a sibling that shares the prefix is not containment
dir.create(paste0(base, "-evil"))
expect_false(path_within(paste0(base, "-evil"), base))

# --- the wired picker, driven through a real session ---
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
handle_event <- glinty:::handle_event
handle_input <- glinty:::handle_input
json <- function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)
modals <- function(s) {
    Filter(function(m) identical(m$type, "modal"), lapply(s$outgoing, json))
}
last_modal <- function(s) {
    m <- modals(s)
    m[[length(m)]]
}
# the listing rides as the table's value, the frame right behind the
# modal: its keys are the entries' absolute paths
last_rows <- function(s, id = "proj_rows") {
    ms <- Filter(function(m) identical(m$type, "output") && identical(m$id, id),
                 lapply(s$outgoing, json))
    if (!length(ms)) {
        return(character(0L))
    }
    m <- ms[[length(ms)]]
    vapply(m$value$keys, identity, "")
}
last_table <- function(s, id = "proj_rows") {
    ms <- Filter(function(m) identical(m$type, "output") && identical(m$id, id),
                 lapply(s$outgoing, json))
    ms[[length(ms)]]$value
}
# every button value in a frame, flattened out of the component
# trees; `id` narrows to one event id (nav rows vs commit rows)
frame_values <- function(m, id = NULL) {
    out <- character(0L)
    walk <- function(x) {
        if (!is.list(x)) {
            return(invisible(NULL))
        }
        if (identical(x$component, "button") && !is.null(x$value) &&
            (is.null(id) || identical(x$id, id))) {
            out[[length(out) + 1L]] <<- x$value
        }
        for (ch in x) walk(ch)
        invisible(NULL)
    }
    walk(m$body)
    walk(m$footer)
    out
}

s <- new_session("pk1")
input <- glinty:::make_input_proxy(s)
pk <- path_picker(s, input, "proj", kind = "dir", root = base)
expect_null(pk$value())

# stray nav and choose events before the first open() conjure and
# commit nothing
handle_event(s, "proj_go", alpha)
flush_reactions()
handle_event(s, "proj_choose", alpha)
flush_reactions()
expect_equal(length(s$outgoing), 0L)
expect_null(pk$value())

pk$open()
m <- last_modal(s)
expect_equal(m$action, "show")
expect_equal(m$title, "Choose a folder")
# a file dialog is a large modal of fixed size, not a shrink-wrapped
# column
expect_equal(m$size, "large")
# the listing is a selectable data_table whose rows key on the
# entries' absolute paths, folders first, with what each one is and
# when it changed
rows_cmp <- Filter(function(x) identical(x$component, "data_table"), m$body)
expect_equal(length(rows_cmp), 1L)
expect_equal(rows_cmp[[1]]$id, "proj_rows")
expect_equal(rows_cmp[[1]]$selection, "single")
tbl <- last_table(s)
expect_equal(unlist(tbl$header), c("Name", "Kind", "Modified", "Size"))
expect_equal(last_rows(s), c(alpha, normalizePath(file.path(base, "Beta"), winslash = "/")))
expect_equal(tbl$rows[[1]][[2]], "folder")
expect_true(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} ", tbl$rows[[1]][[3]]))
expect_equal(unlist(tbl$align), c("text", "text", "right", "right"))
# dates and sizes sit right: a text sort on a formatted column

# step into alpha: the frame a row click sends, the table's one key
handle_input(s, "proj_rows", list(alpha))
flush_reactions()
m2 <- last_modal(s)
expect_equal(m2$action, "show")
expect_true(any(grepl("inner", last_rows(s), fixed = TRUE)))
# crumbs offer the way back
expect_true(base %in% frame_values(m2))
# a second click on the same row clears the selection, which means
# nothing: no step, no frame
n_frames <- length(s$outgoing)
handle_input(s, "proj_rows", list())
flush_reactions()
expect_equal(length(s$outgoing), n_frames)
# the crumbs step too
handle_input(s, "proj_rows", list(inner))
flush_reactions()
expect_true(alpha %in% frame_values(last_modal(s)))
handle_event(s, "proj_go", alpha)
flush_reactions()
expect_true(inner %in% last_rows(s))

# a forged target outside root: stays put, sends nothing
n_frames <- length(s$outgoing)
handle_event(s, "proj_go", dirname(base))
flush_reactions()
expect_equal(length(s$outgoing), n_frames)

# crumb back up, then the footer press, which carries the on-screen
# directory as its value
handle_event(s, "proj_go", base)
flush_reactions()
# valueless choose first -- a forged frame -- commits nothing
handle_event(s, "proj_choose")
flush_reactions()
expect_null(pk$value())
handle_event(s, "proj_choose", base)
flush_reactions()
expect_equal(pk$value(), base)
expect_equal(last_modal(s)$action, "hide")
# valueless AFTER valued: handle_event's counter restarts from the
# string instead of erroring on "path" + 1L, which would have closed
# the connection over one stray click
handle_event(s, "proj_choose")
flush_reactions()
expect_equal(pk$value(), base)
# a file's path on the dir picker's choose id commits nothing
handle_event(s, "proj_choose", file.path(base, "notes.txt"))
flush_reactions()
expect_equal(pk$value(), base)

# the two-press case: choosing must not disable the picker, so a
# second open() shows a second dialog
n_frames <- length(s$outgoing)
pk$open()
m3 <- last_modal(s)
expect_equal(m3$action, "show")
expect_true(length(s$outgoing) > n_frames)
# and stepping still works after a completed pick
handle_event(s, "proj_go", alpha)
flush_reactions()
expect_equal(last_modal(s)$action, "show")

# --- kind = "file": a file row picks, forged paths are refused ---
s2 <- new_session("pk2")
input2 <- glinty:::make_input_proxy(s2)
pk2 <- path_picker(s2, input2, "med", kind = "file", root = base,
                   pattern = "\\.(txt|mp4)$")
pk2$open()
expect_equal(last_modal(s2)$title, "Choose a file")
notes <- normalizePath(file.path(base, "notes.txt"), winslash = "/")
expect_true(notes %in% last_rows(s2, "med_rows"))
tbl2 <- last_table(s2, "med_rows")
i <- match(notes, last_rows(s2, "med_rows"))
expect_equal(tbl2$rows[[i]][[2]], "txt")
expect_equal(tbl2$rows[[i]][[4]], "2 B")

# a file target on the nav id does not pick: navigation is
# directories only
handle_event(s2, "med_go", notes)
flush_reactions()
expect_null(pk2$value())
# a file row click picks
handle_input(s2, "med_rows", list(notes))
flush_reactions()
expect_equal(pk2$value(), notes)
expect_equal(last_modal(s2)$action, "hide")
# and the choose id picks a file too (a shortcut's path)
pk2$open()
handle_event(s2, "med_choose", notes)
flush_reactions()
expect_equal(pk2$value(), notes)
expect_equal(last_modal(s2)$action, "hide")

# a forged file outside root is refused
outside <- file.path(dirname(base), "outside.txt")
writeLines("x", outside)
handle_event(s2, "med_choose", outside)
flush_reactions()
expect_equal(pk2$value(), notes)
# a directory on a file picker's choose id commits nothing
handle_event(s2, "med_choose", base)
flush_reactions()
expect_equal(pk2$value(), notes)

# --- open(start =) says where to open, never what to return ---
s3 <- new_session("pk3")
input3 <- glinty:::make_input_proxy(s3)
pk3 <- path_picker(s3, input3, "out", kind = "dir", root = base)
pk3$open(start = alpha)
expect_true(inner %in% last_rows(s3, "out_rows"))
expect_null(pk3$value())
# a start outside root falls back inside it
pk3$open(start = dirname(base))
expect_true(alpha %in% last_rows(s3, "out_rows"))

# --- the listing helpers ---
expect_equal(glinty:::picker_size(c(NA, 0, 1023, 1024, 1536, 1048576, 5e9)),
             c("", "0 B", "1023 B", "1.0 KB", "1.5 KB", "1.0 MB", "4.7 GB"))
lst <- glinty:::picker_listing(base, picker_entries(base, kind = "file"))
expect_equal(row.names(lst), file.path(base, c("alpha", "Beta", "notes.txt")))
expect_equal(lst$Kind, c("folder", "folder", "txt"))
expect_equal(lst$Size[1:2], c("", ""))
expect_equal(nrow(glinty:::picker_listing(base, list(dirs = character(0L),
                                                     files = character(0L)))), 0L)
# an empty directory says so instead of drawing an empty table
s_empty <- new_session("pk_empty")
empty_dir <- file.path(base, "Beta")
pk_e <- path_picker(s_empty, glinty:::make_input_proxy(s_empty), "e",
                    kind = "dir", root = empty_dir)
pk_e$open()
expect_true(any(vapply(last_modal(s_empty)$body, function(x) {
    identical(x$component, "text") && identical(x$value, "nothing in here")
}, logical(1L))))
expect_equal(length(last_rows(s_empty, "e_rows")), 0L)

# --- shortcuts: app-supplied places above the tree ---
s4 <- new_session("pk4")
input4 <- glinty:::make_input_proxy(s4)
gone <- file.path(base, "gone-away")
pk4 <- path_picker(s4, input4, "sc", kind = "dir", root = base,
                   shortcuts = c("Alpha" = alpha,
                                 "Gone" = gone,
                                 "Outside" = dirname(base)))
pk4$open()
vals <- frame_values(last_modal(s4))
expect_true(alpha %in% vals)
# entries that no longer exist or sit outside root are left out of
# the dialog, never rendered dead
expect_false(gone %in% vals)
expect_false(dirname(base) %in% vals)
# selecting a shortcut resolves the picker like a tree choice
handle_event(s4, "sc_choose", alpha)
flush_reactions()
expect_equal(pk4$value(), alpha)
expect_equal(last_modal(s4)$action, "hide")

# a function is asked at each show, so a recents list stays current
s5 <- new_session("pk5")
input5 <- glinty:::make_input_proxy(s5)
recents <- new.env(parent = emptyenv())
recents$v <- c("first" = alpha)
pk5 <- path_picker(s5, input5, "rc", kind = "dir", root = base,
                   shortcuts = function() recents$v)
pk5$open()
beta <- normalizePath(file.path(base, "Beta"), winslash = "/")
expect_true(alpha %in% frame_values(last_modal(s5), id = "rc_choose"))
expect_false(beta %in% frame_values(last_modal(s5), id = "rc_choose"))
recents$v <- c("newest" = beta, "first" = alpha)
pk5$open()
expect_true(beta %in% frame_values(last_modal(s5), id = "rc_choose"))

# file kind: only file entries survive the filter
s6 <- new_session("pk6")
input6 <- glinty:::make_input_proxy(s6)
pk6 <- path_picker(s6, input6, "fs", kind = "file", root = base,
                   shortcuts = c("notes" = file.path(base, "notes.txt"),
                                 "a folder" = alpha))
pk6$open()
# narrowed to the commit id: alpha still shows in the TREE (as a nav
# row), but must not be offered as a pickable shortcut
v6 <- frame_values(last_modal(s6), id = "fs_choose")
expect_true(file.path(base, "notes.txt") %in% v6)
expect_false(alpha %in% v6)
handle_event(s6, "fs_choose", file.path(base, "notes.txt"))
flush_reactions()
expect_equal(pk6$value(), notes)

# --- construction refuses what it cannot honor ---
expect_error(path_picker(s, input, "y", shortcuts = c("/no/label")),
             "shortcuts")
expect_error(path_picker(s, input, "y", shortcuts = 42), "shortcuts")
expect_error(path_picker(s, input, ""), "id")
expect_error(path_picker(s, input, "x", root = file.path(base, "gone")),
             "root")
expect_error(path_picker(s, input, "x", limit = 0L), "limit")
expect_error(path_picker(list(), input, "x"), "session")
expect_error(path_picker(s, list(), "x"), "input proxy")

unlink(c(base, paste0(base, "-evil")), recursive = TRUE)
unlink(outside)
