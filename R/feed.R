# The feed: a server-fed item log with delta messages.
#
# The one output semantics everywhere else is "a message replaces the
# slot's whole value", and for a message log that is O(n) bytes per
# event plus a DOM replacement that yanks the reader's scroll. The
# feed's messages are deltas instead: append one item, patch the
# newest, reset the window. Items are ordinary component trees, so
# anything the vocabulary can say can be a feed item.
#
# The server keeps the item log per (session, feed id) -- bounded by
# `keep` -- because a resumed session must be able to receive the
# whole window again without the app replaying its own history. The
# snapshot rides the same last_sent mechanism outputs use, so resume
# replays one reset message per feed, current state, no re-render.

#' Create a feed
#'
#' A scrolling item log fed by the server: [feed_append()] adds an
#' item without resending the rest, [feed_patch()] rewrites the newest
#' (token streaming into the message being generated), [feed_reset()]
#' replaces the window (history load). A feed starts empty on purpose
#' -- the server's log is the one source of what it holds -- so an app
#' loads history with feed_reset() from its server function.
#'
#' The feed owns its scroll: it stays pinned to the bottom while the
#' reader is there, releases when they scroll up, and offers a way
#' back down. `keep` bounds the window; older items fall off the top.
#'
#' @param id character feed ID
#' @param keep integer items retained; the window shown and replayed
#' @param grow integer flex-grow inside the parent, like column()
#' @param width integer fixed width in pixels
#' @return A UI component
#' @examples
#' feed("log")
#' feed("room", keep = 500L, grow = 1L)
#' @export
feed <- function(id, keep = 200L, grow = NULL, width = NULL) {
    component("feed", id = id, keep = keep, grow = grow, width = width)
}

#' Append one item to a feed
#'
#' Sends the item alone; clients add it to the end and drop items past
#' `keep` from the top. While the reader is at the bottom the feed
#' stays pinned there.
#'
#' @param session a glinty_session
#' @param id character feed ID
#' @param item a component, the new entry
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' feed_append(session, "room", text("hello", variant = "muted"))
#' }
#' @export
feed_append <- function(session, id, item) {
    st <- feed_state(session, id)
    item <- feed_check_item(item, "feed_append")
    st$items <- c(st$items, list(item))
    feed_trim(st)
    feed_send(session, id, st,
              list(type = "feed", id = id, op = "append", keep = st$keep,
                   item = item))
}

#' Rewrite the newest item of a feed
#'
#' The streaming case: the message being generated is appended once,
#' then patched as tokens arrive. Patching an empty feed is an error
#' -- there is nothing the patch could mean.
#'
#' @param session a glinty_session
#' @param id character feed ID
#' @param item a component, replacing the newest entry
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' feed_append(session, "room", text(""))
#' feed_patch(session, "room", text(draft_so_far))
#' }
#' @export
feed_patch <- function(session, id, item) {
    st <- feed_state(session, id)
    if (length(st$items) == 0L) {
        stop("feed_patch(): feed '", id, "' is empty; ",
             "append the item it should rewrite first", call. = FALSE)
    }
    item <- feed_check_item(item, "feed_patch")
    st$items[[length(st$items)]] <- item
    feed_send(session, id, st,
              list(type = "feed", id = id, op = "patch", keep = st$keep, item = item))
}

#' Replace a feed's window
#'
#' One message carrying the whole (trimmed) list: loading a room's
#' history at boot, or clearing with `items = list()`. The reader is
#' pinned back to the bottom.
#'
#' @param session a glinty_session
#' @param id character feed ID
#' @param items list of components
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' feed_reset(session, "room", lapply(history, message_row))
#' }
#' @export
feed_reset <- function(session, id, items = list()) {
    st <- feed_state(session, id)
    items <- check_children(items, "feed_reset")
    st$items <- lapply(items, unclass_recursive)
    feed_trim(st)
    feed_send(session, id, st, feed_reset_msg(id, st))
}

# ---- internals ----

#' Validate and strip one feed item
#' @keywords internal
feed_check_item <- function(item, fn) {
    if (!is_component(item)) {
        stop(fn, "(): item must be a component, got ", class(item)[[1L]],
             call. = FALSE)
    }
    unclass_recursive(item)
}

#' Per-session feed state, created on first touch
#'
#' `keep` comes from the feed's declaration in the static UI tree when
#' the id is found there, and from the schema default otherwise (a
#' feed born inside render_ui() is not in that tree). Held server-side
#' so the log and the clients trim to the same bound -- every feed
#' message carries it, so no client reads a second source at runtime.
#'
#' @keywords internal
feed_state <- function(session, id) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    if (!is.character(id) || length(id) != 1L || !nzchar(id)) {
        stop("feed id must be a single non-empty string", call. = FALSE)
    }
    if (is.null(session$feeds)) {
        session$feeds <- new.env(parent = emptyenv())
    }
    st <- session$feeds[[id]]
    if (is.null(st)) {
        st <- new.env(parent = emptyenv())
        st$items <- list()
        st$keep <- feed_declared_keep(id)
        session$feeds[[id]] <- st
    }
    st
}

#' The `keep` a static tree declares for this feed id, or the default
#' @keywords internal
feed_declared_keep <- function(id) {
    found <- NULL
    walk <- function(x) {
        if (!is.list(x)) {
            return(invisible(NULL))
        }
        if (identical(x$component, "feed") && identical(x$id, id)) {
            found <<- x$keep
            return(invisible(NULL))
        }
        for (part in x) {
            walk(part)
        }
        invisible(NULL)
    }
    walk(.globals$welcome_ui)
    if (is.numeric(found) && length(found) == 1L) {
        return(as.integer(found))
    }
    FEED_KEEP_DEFAULT
}

#' Drop items past keep, oldest first
#' @keywords internal
feed_trim <- function(st) {
    extra <- length(st$items) - st$keep
    if (extra > 0L) {
        st$items <- st$items[-seq_len(extra)]
    }
    invisible(NULL)
}

#' The reset message carrying a feed's whole window
#' @keywords internal
feed_reset_msg <- function(id, st) {
    list(type = "feed", id = id, op = "reset", keep = st$keep, items = st$items)
}

#' Serialize one feed message, the way every outgoing message is
#'
#' Messages enter the queue as JSON text (welcome_msg() sets the
#' convention); the drain writes them as-is.
#'
#' @keywords internal
feed_json <- function(msg) {
    as.character(jsonlite::toJSON(msg, auto_unbox = TRUE, null = "null"))
}

#' Queue a live feed message and record the replay snapshot
#'
#' Mirrors send_output()'s contract: the snapshot (a reset carrying
#' the current window) is always recorded under a key no app id can
#' collide with -- ".." ids are refused on the input path -- and the
#' live delta is queued only while attached, because a resume replays
#' the snapshot instead.
#'
#' @keywords internal
feed_send <- function(session, id, st, msg) {
    if (session$ended) {
        return(invisible(NULL))
    }
    session$last_sent[[paste0("..feed:", id)]] <- feed_json(
        feed_reset_msg(id, st))
    if (!isTRUE(session$detached)) {
        session$outgoing <- c(session$outgoing, list(feed_json(msg)))
    }
    invisible(NULL)
}
