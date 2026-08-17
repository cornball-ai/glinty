# Picking a path on the machine running R (#47).
#
# file_input() uploads bytes from the machine holding the keyboard.
# This is the other job: naming a directory or file on the machine
# running the server -- opening a project, choosing an output folder,
# pointing at media already on disk. No browser dialog can do it: a
# browser browses the client's disk and hands over contents, never a
# server path. So the server offers a listing and the user walks it,
# the shape shinyFiles has served in the Shiny ecosystem for years.
#
# Deliberately a helper over existing vocabulary -- buttons carrying
# values, a modal rebuilt per step -- not a component with a listing
# protocol message. A listing message would move the browser UI into
# each frontend: breadcrumbs and rows drawn twice, drifting twice,
# for no capability the modal lacks. If a native client ever wants
# the platform dialog against a local server, the seam is an embedder
# callback on a field component, not a listing message.

#' The entries of a directory, as the picker shows them
#'
#' Directories always list -- they are the way through -- and sort
#' case-insensitively. Files list only for kind = "file", filtered by
#' `pattern`. Dotfiles stay hidden unless asked for. A missing or
#' unreadable directory is empty rather than an error, so a listing
#' that raced a deletion degrades to "nothing in here".
#'
#' @param dir character directory path
#' @param kind "dir" or "file"
#' @param pattern character regex files must match, or NULL
#' @param hidden logical include dotfiles
#' @return list(dirs, files) of bare names
#' @keywords internal
picker_entries <- function(dir, kind = "dir", pattern = NULL, hidden = FALSE) {
    empty <- list(dirs = character(0L), files = character(0L))
    if (is.null(dir) || !nzchar(dir) || !dir.exists(dir)) {
        return(empty)
    }
    dirs <- list.dirs(dir, full.names = FALSE, recursive = FALSE)
    dirs <- dirs[nzchar(dirs)]
    if (!hidden) {
        dirs <- dirs[!startsWith(dirs, ".")]
    }
    dirs <- dirs[order(tolower(dirs))]
    files <- character(0L)
    if (identical(kind, "file")) {
        files <- list.files(dir, pattern = pattern, all.files = hidden,
                            no.. = TRUE)
        files <- files[!dir.exists(file.path(dir, files))]
        files <- files[order(tolower(files))]
    }
    list(dirs = dirs, files = files)
}

#' The path split into the pieces you can jump back to, root first
#'
#' What makes going up four levels one press instead of four. Stops
#' at `root` when one is set, so the crumbs never offer a step the
#' navigation would refuse.
#'
#' @param dir character directory path
#' @param root character topmost crumb, or NULL for the filesystem root
#' @return data.frame(name, path)
#' @keywords internal
picker_crumbs <- function(dir, root = NULL) {
    if (is.null(dir) || !nzchar(dir)) {
        return(data.frame(name = character(0L), path = character(0L),
                          stringsAsFactors = FALSE))
    }
    names <- character(0L)
    paths <- character(0L)
    cur <- dir
    repeat {
        names <- c(basename(cur), names)
        paths <- c(cur, paths)
        if (!is.null(root) && identical(cur, root)) {
            break
        }
        up <- dirname(cur)
        if (identical(up, cur)) {
            break
        }
        cur <- up
    }
    # basename("/") is "": name the root something pressable rather
    # than an empty label
    names[!nzchar(names)] <- "/"
    data.frame(name = names, path = paths, stringsAsFactors = FALSE)
}

#' Is a path `root` itself, or inside it?
#'
#' Both arguments must already be canonical (normalizePath). String
#' prefixing alone would call "/srv/data-evil" inside "/srv/data";
#' the appended separator is what makes containment mean containment.
#'
#' @param path,root character canonical paths
#' @return logical
#' @keywords internal
path_within <- function(path, root) {
    if (identical(path, root)) {
        return(TRUE)
    }
    if (endsWith(root, "/")) {
        prefix <- root
    } else {
        prefix <- paste0(root, "/")
    }
    startsWith(path, prefix)
}

#' One navigation step, canonicalized and bounded
#'
#' Button values arrive from the client, so no target is trusted:
#' anything that is not an existing directory leaves the picker where
#' it stands, and canonicalizing before the root check means a ".."
#' or a symlink pointing out of `root` is refused, not followed.
#'
#' @param cur character current directory (canonical)
#' @param target character proposed directory
#' @param root character boundary, or NULL for none
#' @return character the new current directory
#' @keywords internal
picker_step <- function(cur, target, root = NULL) {
    if (is.null(target) || !is.character(target) || length(target) != 1L ||
        !nzchar(target) || !dir.exists(target)) {
        return(cur)
    }
    target <- normalizePath(target, winslash = "/")
    if (!is.null(root) && !path_within(target, root)) {
        return(cur)
    }
    target
}

#' Require a well-formed shortcuts vector
#'
#' Shape only: every entry labelled, every path a non-empty string.
#' Existence, kind and root containment are show-time facts and are
#' filtered at show time instead.
#'
#' @param x candidate shortcuts value
#' @return the vector, invisibly validated
#' @keywords internal
check_shortcut_shape <- function(x) {
    if (!is.character(x) || length(x) == 0L || is.null(names(x)) ||
        any(!nzchar(names(x))) || anyNA(x) || any(!nzchar(x))) {
        stop("shortcuts must be a named character vector of labels to paths",
             call. = FALSE)
    }
    x
}

#' A served file browser, from existing vocabulary
#'
#' Picks a directory or file on the machine running the server -- the
#' job \code{file_input()} cannot do, since a browser dialog browses
#' the client's disk and uploads contents rather than naming a server
#' path. The dialog is ordinary components in a modal: breadcrumbs
#' and one row per entry, every one a \code{button()} carrying its
#' target path as the value. Two observers serve all of it, split by
#' meaning: one id navigates (crumbs and directory rows), the other
#' commits a result (file rows, shortcuts, and the footer's confirm
#' button, which carries the on-screen directory).
#'
#' Call once in the server function and keep the handle:
#' \code{open()} shows the dialog -- always; \code{start} says where
#' to open, never what to return -- and \code{value} is a
#' \code{reactive_val()} holding the chosen absolute path, NULL until
#' the user picks one. An explicit selection in the dialog is the
#' only writer. (Both halves are deliberate: a typed-path field that
#' short-circuits the dialog, combined with a picker that writes that
#' field back, is how a picker quietly disables itself after one
#' use.)
#'
#' \code{shortcuts} are the places every real file dialog offers
#' beside the tree -- GTK calls them Places, macOS Favorites, editors
#' Recent. A named character vector of labels to paths, or a zero-arg
#' function returning one, called at each show so a recents list
#' stays current. Selecting one resolves the picker exactly as
#' choosing in the tree does: a shortcut names a \emph{result}, not a
#' place to browse (where to browse is \code{start}). Entries that do
#' not exist, do not match \code{kind}, or sit outside \code{root}
#' are left out of the dialog rather than rendered dead. A shortcut
#' is a visible control naming exactly what it opens; app state may
#' feed the list, but the picker never writes app state back.
#'
#' Button values arrive from the client, so navigation trusts none of
#' them: every step is canonicalized and, when \code{root} is set,
#' refused if it leaves it -- which also refuses symlinks pointing
#' out. \code{root} is a browsing boundary, not the app's security
#' boundary (the input channel is same-origin, and any path input the
#' app offers elsewhere is as reachable): NULL browses the whole
#' filesystem, which is what a personal tool usually means, and a
#' deployment with a real boundary states one.
#'
#' The picker binds \code{paste0(id, "_go")} and
#' \code{paste0(id, "_choose")} on the wire; leave those ids to it.
#'
#' @param session a glinty_session
#' @param input the server function's input proxy
#' @param id character stem for the picker's event ids
#' @param kind "dir" to choose a directory, "file" to choose a file
#' @param root character topmost browsable directory, or NULL for the
#'   whole filesystem
#' @param start character directory to open in; defaults to `root`,
#'   else the working directory
#' @param shortcuts named character vector of labels to paths shown
#'   above the tree, or a zero-arg function returning one, called at
#'   each show; selecting one resolves the picker
#' @param title character dialog title, or NULL for a default named
#'   by kind
#' @param pattern character regex shown files must match; directories
#'   always show, or there is no way through them
#' @param hidden logical show dotfiles
#' @param limit integer most rows shown; the rest are counted in a
#'   note -- step deeper to narrow down
#' @return list(open = function(start = NULL), value = reactive_val)
#' @examples
#' \dontrun{
#' server <- function(input, output, session) {
#'     picker <- path_picker(session, input, "proj", kind = "dir")
#'     observe_event(input$open_project, function() picker$open())
#'     observe_event(picker$value, function(path) {
#'         open_project(path)
#'     })
#' }
#' }
#' @export
path_picker <- function(session, input, id, kind = c("dir", "file"),
                        root = NULL, start = NULL, shortcuts = NULL,
                        title = NULL, pattern = NULL, hidden = FALSE,
                        limit = 60L) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    if (!inherits(input, "glinty_input")) {
        stop("input must be the server function's input proxy", call. = FALSE)
    }
    if (!is.character(id) || length(id) != 1L || !nzchar(id)) {
        stop("id must be a non-empty string", call. = FALSE)
    }
    kind <- match.arg(kind)
    if (!is.null(root)) {
        if (!is.character(root) || length(root) != 1L || !dir.exists(root)) {
            stop("root must be an existing directory, or NULL", call. = FALSE)
        }
        root <- normalizePath(root, winslash = "/")
    }
    limit <- suppressWarnings(as.integer(limit))
    if (length(limit) != 1L || is.na(limit) || limit < 1L) {
        stop("limit must be a positive integer", call. = FALSE)
    }
    if (!is.null(shortcuts) && !is.function(shortcuts)) {
        shortcuts <- check_shortcut_shape(shortcuts)
    }
    if (is.null(title)) {
        title <- if (identical(kind, "dir")) {
            "Choose a folder"
        } else {
            "Choose a file"
        }
    }

    nav_id <- paste0(id, "_go")
    choose_id <- paste0(id, "_choose")
    cwd <- reactive_val(NULL)
    chosen <- reactive_val(NULL)

    # Where to open: the first of these that exists and sits inside
    # root. The fallback chain ends at root itself (or "/"), so the
    # dialog never opens somewhere it would refuse to step to.
    landing <- function(extra) {
        for (d in list(extra, start, root, getwd())) {
            if (is.null(d) || !is.character(d) || length(d) != 1L ||
                !nzchar(d) || !dir.exists(d)) {
                next
            }
            d <- normalizePath(d, winslash = "/")
            if (is.null(root) || path_within(d, root)) {
                return(d)
            }
        }
        if (is.null(root)) {
            "/"
        } else {
            root
        }
    }

    # The shortcut set as of this show: a function is asked fresh, so
    # a recents list stays current, and only entries the tree itself
    # could commit are offered -- existing, kind-matched, inside root
    # -- rather than rendered dead.
    shortcuts_now <- function() {
        sc <- shortcuts
        if (is.function(sc)) {
            sc <- sc()
            if (is.null(sc) || length(sc) == 0L) {
                return(character(0L))
            }
            sc <- check_shortcut_shape(sc)
        }
        if (is.null(sc)) {
            return(character(0L))
        }
        keep <- vapply(sc, function(p) {
            ok <- if (identical(kind, "dir")) {
                dir.exists(p)
            } else {
                file.exists(p) && !dir.exists(p)
            }
            ok && (is.null(root) ||
                       path_within(normalizePath(p, winslash = "/"), root))
        }, logical(1L), USE.NAMES = FALSE)
        sc[keep]
    }

    # The dialog, rebuilt on every show and every step, because its
    # contents ARE the current directory. show_modal() replaces an
    # open dialog, so a step is one call.
    show <- function() {
        d <- isolate(cwd())
        e <- picker_entries(d, kind = kind, pattern = pattern, hidden = hidden)
        cr <- picker_crumbs(d, root = root)
        crumbs <- lapply(seq_len(nrow(cr)), function(i) {
            button(nav_id, cr$name[[i]], variant = "ghost",
                   value = cr$path[[i]])
        })
        shown_dirs <- utils::head(e$dirs, limit)
        shown_files <- utils::head(e$files, max(0L, limit - length(shown_dirs)))
        rows <- c(
                  lapply(shown_dirs, function(nm) {
            button(nav_id, paste0(nm, "/"), variant = "ghost",
                   value = file.path(d, nm))
        }),
                  lapply(shown_files, function(nm) {
            button(choose_id, nm, variant = "secondary",
                   value = file.path(d, nm))
        })
        )
        left_out <- (length(e$dirs) - length(shown_dirs)) +
        (length(e$files) - length(shown_files))
        if (length(rows) == 0L) {
            rows <- list(txt("nothing in here", variant = "muted"))
        } else if (left_out > 0L) {
            rows <- c(rows, list(txt(
                                     sprintf("%d more not shown -- step into a folder to narrow down",
                            left_out), variant = "small")))
        }
        sc <- shortcuts_now()
        quick <- lapply(seq_along(sc), function(i) {
            button(choose_id, names(sc)[[i]], variant = "secondary",
                   value = sc[[i]])
        })
        footer <- c(list(modal_button("Cancel")),
            if (identical(kind, "dir")) {
                # Carries the on-screen directory, so every press of
                # choose_id commits the path it names -- one meaning,
                # and never a valueless event on an id that also
                # carries values.
                list(button(choose_id, "Choose this folder",
                            variant = "primary", value = d))
            },
                    list(gap = 8L))
        body <- c(
            if (length(quick) > 0L) {
                list(do.call(row, c(quick, list(gap = 2L))), divider())
            },
                  list(do.call(row, c(crumbs, list(gap = 2L))),
                       divider(),
                       do.call(column, c(rows, list(gap = 2L))))
        )
        do.call(show_modal, c(list(session), body,
                              list(title = title, footer = do.call(row, footer))))
        invisible(NULL)
    }

    # Two observers, split by meaning rather than by widget. nav_id
    # only ever navigates: crumbs and directory rows share it, and
    # the press says which target through the button value. Both are
    # gated on cwd, so a stray event before the first open() cannot
    # conjure the dialog or commit a value.
    observe_event(input[[nav_id]], function(target) {
        now <- isolate(cwd())
        if (is.null(now)) {
            return(invisible(NULL))
        }
        stepped <- picker_step(now, target, root = root)
        if (!identical(stepped, now)) {
            cwd(stepped)
            show()
        }
        invisible(NULL)
    })

    # choose_id commits the path its press carries: a file row, a
    # shortcut, or the footer's confirm with the on-screen directory.
    # The value is client-supplied, so it is held to exactly what the
    # tree could commit -- existing, kind-matched, inside root.
    observe_event(input[[choose_id]], function(target) {
        if (is.null(isolate(cwd()))) {
            return(invisible(NULL))
        }
        if (!is.character(target) || length(target) != 1L || !nzchar(target)) {
            return(invisible(NULL))
        }
        ok <- if (identical(kind, "dir")) {
            dir.exists(target)
        } else {
            file.exists(target) && !dir.exists(target)
        }
        if (!ok) {
            return(invisible(NULL))
        }
        picked <- normalizePath(target, winslash = "/")
        if (!is.null(root) && !path_within(picked, root)) {
            return(invisible(NULL))
        }
        chosen(picked)
        remove_modal(session)
        invisible(NULL)
    })

    list(
         open = function(start = NULL) {
        cwd(landing(start))
        show()
        invisible(NULL)
    },
         value = chosen
    )
}
