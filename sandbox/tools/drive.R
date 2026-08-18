# In-process driver for gallery ports: boots an app the way the live
# event loop does (seed inputs from the tree, run the server function),
# then lets a script send measure/input/event frames and inspect the
# outgoing protocol messages. No socket, no browser.

drive_boot <- function(app_path, name = "drv") {
    a <- source(app_path, local = new.env())$value
    s <- glinty:::new_session(name)
    glinty:::seed_session_inputs(s, a$ui)
    # Mirror run_app()'s dispatch exactly: server(input, output[, session]),
    # Shiny's order. A driver that invents its own order agrees with a
    # wrongly-declared app and hides the bug (learned on 01-faithful).
    glinty:::with_session(s, {
        if (length(formals(a$server)) >= 3L) {
            a$server(s$input, s$output, s)
        } else {
            a$server(s$input, s$output)
        }
    })
    glinty::flush_reactions()
    # deliberately stops here: this is the queued state of the first
    # flush, before the loop's post-drain steps. drive_settle() is
    # the explicit "let the event loop spin" that fires on_flushed
    # and runs due timers, so a check can look at both phases.
    list(app = a, session = s, input = s$input)
}

# Run timers, flushes and on_flushed rounds until nothing moves --
# the in-process equivalent of letting the event loop spin until
# quiet. Deferred work (invalidate_later, on_flushed chains) lands
# here.
drive_settle <- function(d, max_spins = 20L) {
    repeat {
        n <- glinty:::run_due_timers()
        glinty::flush_reactions()
        f <- glinty:::fire_on_flushed()
        max_spins <- max_spins - 1L
        if ((n == 0L && f == 0L) || max_spins <= 0L) {
            break
        }
    }
    invisible(d)
}

drive_measure <- function(d, id, width, height, dpr = 1) {
    glinty:::handle_measure(d$session,
        list(id = id, width = width, height = height, dpr = dpr))
    glinty::flush_reactions()
    invisible(d)
}

drive_input <- function(d, id, value) {
    # Through normalize_value like the live dispatch (protocol.R), or
    # the harness feeds raw lists where the server never sees them --
    # which is how a NULL-vs-character(0) seam stayed hidden.
    glinty:::handle_input(d$session, id, glinty:::normalize_value(value))
    glinty::flush_reactions()
    invisible(d)
}

drive_event <- function(d, id, value = NULL) {
    glinty:::handle_event(d$session, id, value)
    glinty::flush_reactions()
    invisible(d)
}

drive_msgs <- function(d, type = NULL, id = NULL) {
    m <- lapply(d$session$outgoing,
        function(x) jsonlite::fromJSON(x, simplifyVector = FALSE))
    if (!is.null(type)) m <- Filter(function(x) identical(x$type, type), m)
    if (!is.null(id)) m <- Filter(function(x) identical(x$id, id), m)
    m
}

# Serialize the app's UI tree for the Flutter renderer harness.
drive_tree_json <- function(d, path) {
    tree <- glinty:::unclass_recursive(d$app$ui)
    writeLines(jsonlite::toJSON(tree, auto_unbox = TRUE, null = "null"), path)
    invisible(path)
}
