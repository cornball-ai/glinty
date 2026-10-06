# Namespaces: keeping independently written subtrees apart on a page
# whose ids are global.
#
# Every input$x, output$x <-, data_table("x") and tabset(id = "x") on
# a page resolves against one flat map, and when two subtrees both
# use "x" the last renderer wins and nothing says so. A namespace is
# an id builder: ns("x") is "stt_x", and scoped() hands a subtree's
# server code input, output and session proxies that apply it, so the
# code reads input$x and gets stt_x. The wire does not change; the
# namespace is a convention the server keeps for the subtree.

#' An id builder for one subtree
#'
#' `ns <- namespace("stt")` makes `ns("file")` return `"stt_file"`.
#' Build a subtree's UI with it, and hand its server code the proxies
#' from \code{\link{scoped}} so `input$file` reads the same id.
#'
#' @param name a short word: letters, digits and underscores, starting
#'   with a letter
#' @param parent another namespace to nest under, so the prefix is
#'   `parent_name_`
#' @return a function(id) prefixing ids, of class `glinty_namespace`;
#'   called with no argument it returns the prefix
#' @examples
#' ns <- namespace("stt")
#' ns("file")
#' ns(c("go", "stop"))
#' ns()
#' inner <- namespace("logs", parent = ns)
#' inner("tail")
#' @export
namespace <- function(name, parent = NULL) {
    if (!is.character(name) || length(name) != 1L || is.na(name) ||
        !grepl("^[A-Za-z][A-Za-z0-9_]*$", name)) {
        stop("a namespace name is one word: letters, digits and ",
             "underscores, starting with a letter", call. = FALSE)
    }
    if (!is.null(parent) && !inherits(parent, "glinty_namespace")) {
        stop("parent must come from namespace(), or be NULL", call. = FALSE)
    }
    prefix <- paste0(if (is.null(parent)) "" else parent(), name, "_")
    f <- function(id = NULL) {
        if (is.null(id)) {
            return(prefix)
        }
        if (!is.character(id) || anyNA(id) || !all(nzchar(id))) {
            stop("ids must be non-empty strings", call. = FALSE)
        }
        paste0(prefix, id)
    }
    structure(f, class = c("glinty_namespace", "function"))
}

#' @export
print.glinty_namespace <- function(x, ...) {
    cat("<glinty namespace ", x(), "*>\n", sep = "")
    invisible(x)
}

#' Proxies that apply a namespace
#'
#' The server-side half of \code{\link{namespace}}: returns `input`,
#' `output` and `session` proxies under which `input$file`,
#' `output$table <-`, `download_handler(session, "md", ...)`,
#' `update_text_input(session, "file", ...)`, the feed verbs and
#' `path_picker()` all address `ns("...")` ids. `session$ns` is the
#' namespace, for ids built inside `render_ui()`; everything else on
#' the session reads and writes through to the real one, so
#' `session$id`, `session$principal`, `run_job(scope = "session")`
#' and `on_ended()` behave as before.
#'
#' The proxies passed in may be the server function's own or ones
#' already scoped: scoping starts from the real session each time,
#' and the namespace carries the whole prefix, so nesting is
#' `scoped(namespace("b", parent = ns), ...)`.
#'
#' @param ns a namespace from \code{\link{namespace}}
#' @param input the server function's input proxy
#' @param output the server function's output proxy
#' @param session the server function's session
#' @return list(input, output, session)
#' @examples
#' \dontrun{
#' ns <- namespace("stt")
#' ui <- column(file_input(ns("file")), text_output(ns("status")))
#' server <- function(input, output, session) {
#'     sc <- scoped(ns, input, output, session)
#'     sc$output$status <- render_text(function() {
#'         f <- sc$input$file()
#'         if (is.null(f)) "waiting" else f$name
#'     })
#' }
#' }
#' @export
scoped <- function(ns, input, output, session) {
    if (!inherits(ns, "glinty_namespace")) {
        stop("ns must come from namespace()", call. = FALSE)
    }
    if (!inherits(input, "glinty_input")) {
        stop("input must be the server function's input proxy", call. = FALSE)
    }
    if (!inherits(output, "glinty_output")) {
        stop("output must be the server function's output proxy",
             call. = FALSE)
    }
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    real <- real_session(session)
    list(input = scope_input(input, ns),
         output = scope_output(output, ns),
         session = scope_session(real, ns))
}

#' The real session behind a scoped one
#' @param session a session or a scoped session
#' @return the glinty_session environment
#' @keywords internal
real_session <- function(session) {
    if (inherits(session, "glinty_scoped_session")) {
        .subset2(session, ".session")
    } else {
        session
    }
}

#' An input proxy over the same environment with no namespace
#' @param input an input proxy, scoped or not
#' @return a plain glinty_input
#' @keywords internal
unscoped_input <- function(input) {
    structure(list(.env = .subset2(input, ".env")), class = "glinty_input")
}

#' A namespaced id for a session helper
#'
#' The id a helper such as download_handler() was given, prefixed
#' when the session is a scoped one and left alone otherwise.
#' @param session a session, scoped or not
#' @param id character id
#' @return character
#' @keywords internal
scoped_id <- function(session, id) {
    if (inherits(session, "glinty_scoped_session")) {
        .subset2(session, ".ns")(id)
    } else {
        id
    }
}

scope_input <- function(input, ns) {
    structure(list(.env = .subset2(input, ".env"), .ns = ns),
              class = c("glinty_scoped_input", "glinty_input"))
}

#' @export
`$.glinty_scoped_input` <- function(x, name) {
    `$.glinty_input`(x, .subset2(x, ".ns")(name))
}

#' @export
`[[.glinty_scoped_input` <- function(x, name) {
    `$.glinty_input`(x, .subset2(x, ".ns")(name))
}

scope_output <- function(output, ns) {
    # .base is the session's own registrar, kept so scoping an already
    # scoped proxy starts from it: the namespace carries the whole
    # prefix, and applying two would double it.
    base <- .subset2(output, ".base")
    if (is.null(base)) {
        base <- .subset2(output, ".reg")
    }
    structure(list(.reg = function(id, value) base(ns(id), value),
                   .base = base, .env = .subset2(output, ".env")),
              class = "glinty_output")
}

scope_session <- function(session, ns) {
    structure(list(.session = session, .ns = ns),
              class = c("glinty_scoped_session", "glinty_session"))
}

#' @export
`$.glinty_scoped_session` <- function(x, name) {
    real <- .subset2(x, ".session")
    ns <- .subset2(x, ".ns")
    switch(name,
           ns = ns,
           input = scope_input(real$input, ns),
           output = scope_output(real$output, ns),
           real[[name]])
}

#' @export
`[[.glinty_scoped_session` <- function(x, name) {
    `$.glinty_scoped_session`(x, name)
}

#' @export
`$<-.glinty_scoped_session` <- function(x, name, value) {
    assign(name, value, envir = .subset2(x, ".session"))
    x
}

#' @export
`[[<-.glinty_scoped_session` <- function(x, name, value) {
    assign(name, value, envir = .subset2(x, ".session"))
    x
}

#' @export
print.glinty_scoped_session <- function(x, ...) {
    cat("<glinty session ", .subset2(x, ".session")$id, " scoped ",
        .subset2(x, ".ns")(), "*>\n", sep = "")
    invisible(x)
}

#' Every id in a component tree
#'
#' Walks a tree from \code{\link{page}} and friends, panels of a
#' tabset included, and returns every component's `id` in order of
#' appearance, named by component kind. A host mounting several
#' subtrees runs its collision check on this; \code{\link{app}} runs
#' its own.
#'
#' @param x a component, or a tree in its unclassed list form
#' @return a character vector of ids, named by component kind
#' @examples
#' component_ids(column(text_input("name"), button("go", "Go"),
#'                      tabset(tab_panel("A", text_output("a")), id = "tabs")))
#' @export
component_ids <- function(x) {
    out <- character(0L)
    walk <- function(node) {
        if (!is.list(node) || is.data.frame(node)) {
            return(invisible(NULL))
        }
        if (is.character(node$component) && length(node$component) == 1L &&
            is.character(node$id) && length(node$id) == 1L &&
            !is.na(node$id)) {
            id <- node$id
            names(id) <- node$component
            out <<- c(out, id)
        }
        for (part in node) {
            if (is.list(part)) {
                walk(part)
            }
        }
        invisible(NULL)
    }
    walk(x)
    out
}

# Components that emit events rather than hold a value or render one.
# Several may share an id on purpose: a Save button and its ctrl+s
# shortcut, or one listing button per row. Every other id names one
# thing, and two of them is the silent collision app() refuses.
EMITTER_KINDS <- c("button", "download_button", "shortcut")

#' Refuse a tree whose ids collide
#'
#' @param ui the app's UI tree
#' @return invisible(NULL), or an error naming the ids
#' @keywords internal
check_tree_ids <- function(ui) {
    ids <- component_ids(ui)
    if (!length(ids)) {
        return(invisible(NULL))
    }
    kinds <- names(ids)
    emits <- kinds %in% EMITTER_KINDS
    named <- ids[!emits]
    dup <- unique(named[duplicated(named)])
    if (length(dup)) {
        stop("an id appears more than once in the UI: ",
             paste(dup, collapse = ", "),
             " (buttons and shortcuts may share an id; inputs, outputs, ",
             "tabsets and containers may not; see namespace())",
             call. = FALSE)
    }
    both <- intersect(ids[emits], named)
    if (length(both)) {
        stop("an id is both an event and a value or output: ",
             paste(both, collapse = ", "), call. = FALSE)
    }
    invisible(NULL)
}
