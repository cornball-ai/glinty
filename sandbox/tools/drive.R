# In-process driver for gallery ports: boots an app the way the live
# event loop does (seed inputs from the tree, run the server function),
# then lets a script send measure/input/event frames and inspect the
# outgoing protocol messages. No socket, no browser.

drive_boot <- function(app_path, name = "drv") {
    a <- source(app_path, local = new.env())$value
    s <- glinty:::new_session(name)
    input <- glinty:::make_input_proxy(s)
    glinty:::seed_session_inputs(s, a$ui)
    glinty:::with_session(s, a$server(s, input, s$output))
    glinty::flush_reactions()
    list(app = a, session = s, input = input)
}

drive_measure <- function(d, id, width, height, dpr = 1) {
    glinty:::handle_measure(d$session,
        list(id = id, width = width, height = height, dpr = dpr))
    glinty::flush_reactions()
    invisible(d)
}

drive_input <- function(d, id, value) {
    glinty:::handle_input(d$session, id, value)
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
