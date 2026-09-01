# Protocol v3 component representation. See PROTOCOL.md.
#
# A component is a semantic description of a piece of UI -- text_input,
# column, plot_output -- not an HTML tag. Each frontend lowers it to
# its own primitives: the browser to DOM, dart/glinty_flutter to
# Flutter widgets. Nothing here knows about either.

#' The icon set every frontend must draw
#'
#' Closed on purpose. An icon name is a token each frontend supplies
#' artwork for, so the set has to be small enough that every frontend
#' can actually carry all of it -- and enumerated here so a name no
#' frontend draws fails where it was written rather than rendering
#' nothing at all.
#'
#' Adding one means adding artwork to `inst/www/glinty.css` and a case
#' to `_iconFor` in dart/glinty_flutter, and the fixtures make that
#' obligation fail loudly if either is skipped.
#'
#' @keywords internal
ICON_NAMES <- c("play", "stop", "rotate", "trash", "microphone",
                "bookmark", "download", "upload", "folder", "file")

#' The key names every frontend must recognise
#'
#' Closed for the same reason the icon set is. A browser calls the
#' escape key "Escape" and Flutter calls it `LogicalKeyboardKey.escape`;
#' a name outside this set is one each lowering guesses at, and a
#' shortcut that never fires is invisible in a way a missing button is
#' not. Enumerated here so a bad name fails where it was written.
#'
#' Adding one means adding a case to the browser lowering's key map and
#' to `_keyFor` in dart/glinty_flutter, and the fixtures make that
#' obligation fail loudly if either is skipped.
#'
#' Letters are lowercase and digits are the top row: a shortcut names
#' the key, not the character it would type, so "shift+1" is that and
#' never "exclam".
#'
#' @keywords internal
KEY_NAMES <- c(letters, as.character(0:9), paste0("f", 1:12), "space",
               "enter", "escape", "tab", "backspace", "delete", "insert",
               "home", "end", "pageup", "pagedown", "left", "right",
               "up", "down", "comma", "period", "slash", "backslash",
               "semicolon", "quote", "bracketleft", "bracketright",
               "minus", "equal", "backquote")

#' Declare one component field
#'
#' @param type character one of "string", "number", "int", "bool",
#'   "enum", "choices", "panels", "condition", "children", "any"
#' @param required logical must be supplied
#' @param default value filled in when absent; NULL means the field
#'   stays absent rather than becoming null on the wire
#' @param values character allowed values, for type "enum"
#' @param min,max numeric bounds, for "int" and "number"
#' @return a field spec
#' @keywords internal
field <- function(type, required = FALSE, default = NULL, values = NULL,
                  min = NULL, max = NULL) {
    list(type = type, required = required, default = default,
         values = values, min = min, max = max)
}

#' Default feed window, shared by the schema and the server-side log
#' @keywords internal
FEED_KEEP_DEFAULT <- 200L

#' The text variants
#'
#' One list for every place a string can carry a variant: `text`,
#' `text_output`, a table cell, a key_value item. It was spelled out
#' twice in the schema before a third consumer arrived; a variant
#' added here reaches all of them, and one added anywhere else is a
#' drift the vocabulary tests will name.
#'
#' @keywords internal
TEXT_VARIANTS <- c("normal", "muted", "strong", "heading", "mono",
                   "small", "success", "warning", "danger")

#' Component field schemas
#'
#' Every component's fields, with types, bounds and defaults.
#' Construction validates against this, so a malformed component fails
#' where it was written rather than in a client -- or worse, in one
#' client and not another.
#'
#' @keywords internal
COMPONENT_SCHEMA <- list(
                         # static content
                         text = list(
                                     value = field("string", required = TRUE),
                                     variant = field("enum", default = "normal", values = TEXT_VARIANTS),
                                     id = field("string")
    ),
                         heading = list(value = field("string", required = TRUE),
                                        level = field("int", default = 2L, min = 1, max = 4),
                                        id = field("string")),
                         link = list(
                                     # `value` is the usual case: a link is text. It stops
                                     # being required when `children` are given, because a
                                     # logo inside an <a> has no text to carry -- and a
                                     # link that can only be text is one both migrated apps
                                     # had to drop to raw markup for.
                                     value = field("string"),
                                     href = field("string", required = TRUE),
                                     children = field("children"),
                                     external = field("bool", default = FALSE)
    ),
                         icon = list(
                                     # A closed set, not free text. Every frontend has to
                                     # supply artwork per name, so a name no frontend
                                     # draws is a component that renders nothing --
                                     # which is what `field("string")` allowed, silently,
                                     # in both lowerings at once.
                                     name = field("enum", required = TRUE, values = ICON_NAMES),
                                     size = field("int", default = 16L, min = 8, max = 128)
    ),
                         # The inline-formatting leaf: a FLAT list of styled
                         # runs -- the one place the vocabulary says "bold" at
                         # all. Flat on purpose: runs never nest, so a client
                         # renders them with a loop, not a grammar. Mostly
                         # produced by markdown(), whose block half lowers to
                         # components that already exist.
                         rich_text = list(
        runs = field("runs", required = TRUE),
        id = field("string")
    ),
                         divider = list(
                                        label = field("string"),
                                        variant = field("enum", default = "line",
            values = c("line", "labelled"))
    ),
                         spacer = list(size = field("int", default = 1L, min = 0, max = 32)),

                         # layout
                         page = list(
                                     children = field("children", required = TRUE),
                                     title = field("string", default = "glinty app"),
                                     # "content" is the centred reading column;
                                     # "full" hands a workspace app the whole
                                     # viewport. An enum rather than a number:
                                     # the browser maps it to max-width, a
                                     # native frontend to padding, and neither
                                     # mapping survives the other's units.
                                     width = field("enum", default = "content",
            values = c("content", "full")),
                                     id = field("string")
    ),
                         # `grow` and `width` say how a container takes space
                         # inside its parent. Not a CSS concept borrowed: every
                         # layout system has the same pair -- flex-grow and
                         # flex-basis, Flutter's Expanded(flex:) and
                         # SizedBox(width:), and so on. Without them a
                         # fixed-width sidebar beside a filling centre column,
                         # which is the shape of both migrated apps, cannot be
                         # said at all.
                         row = list(
                                    children = field("children", required = TRUE),
                                    gap = field("int", min = 0, max = 128),
                                    align = field("enum", values = c("start", "center", "end", "stretch")),
                                    grow = field("int", min = 0, max = 32),
                                    width = field("int", min = 0, max = 4096),
                                    id = field("string")
    ),
                         column = list(
                                       children = field("children", required = TRUE),
                                       gap = field("int", min = 0, max = 128),
                                       grow = field("int", min = 0, max = 32),
                                       width = field("int", min = 0, max = 4096),
                                       # A column that scrolls its overflow
                                       # instead of growing the page: the
                                       # message-list / log shape. Pairs with
                                       # `grow` inside a filled panel.
                                       scroll = field("bool", default = FALSE),
                                       id = field("string")
    ),
                         panel = list(
                                      children = field("children", required = TRUE),
                                      variant = field("enum", default = "plain",
            values = c("plain", "card", "sidebar")),
                                      title = field("string"),
                                      grow = field("int", min = 0, max = 32),
                                      width = field("int", min = 0, max = 4096),
                                      # The vertical bound width's twin cannot
                                      # give. A cap rather than a fixed size:
                                      # the case that wants it (a monitor
                                      # panel whose media would otherwise
                                      # decide the row height) letterboxes
                                      # inside whatever it gets, and a fixed
                                      # height would hold the panel tall when
                                      # its content is short.
                                      max_height = field("int", min = 1, max = 4096),
                                      # The panel becomes a column that hands
                                      # its height to its children, so one of
                                      # them can grow and scroll. Without it a
                                      # panel is only ever as tall as its
                                      # content.
                                      fill = field("bool", default = FALSE),
                                      id = field("string")
    ),
                         # A picture that is part of the UI rather than an
                         # output a renderer produced. image_output is a slot
                         # the server fills; this is a logo in a header, and
                         # there was no way to say it.
                         image = list(
                                      src = field("string", required = TRUE),
                                      alt = field("string", default = ""),
                                      width = field("int", min = 1, max = 4096),
                                      height = field("int", min = 1, max = 4096)
    ),
                         # A section the user can fold away. <details> in the
                         # browser, ExpansionTile in Flutter -- the interaction
                         # is native to both, which is what makes it a
                         # component rather than app markup.
                         collapse = list(
        children = field("children", required = TRUE),
        title = field("string", required = TRUE),
        open = field("bool", default = FALSE),
        id = field("string")
    ),

                         # inputs
                         #
                         # `emit` is the one field every input shares, and it is
                         # deliberately about intent rather than mechanism: "live" means
                         # report while the value is being changed, "settle" means report
                         # once it has. The browser lowers those to input/change events with
                         # a debounce; Flutter would lower them to onChanged and
                         # onEditingComplete. Naming a DOM event here would have made the
                         # schema browser-shaped.
                         # `clear_on` names an event id: when this client emits that
                         # event, it clears the field locally and reports "" -- after
                         # the event frame, so the server handler still reads the full
                         # draft. Client-side by design: a server round trip to clear a
                         # focused composer races the next keystroke, and the browser's
                         # "never stomp live typing" guard (rightly) drops it. Requires
                         # emit = "live", or the clear could discard text the server
                         # never heard.
                         text_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("string", default = ""),
        placeholder = field("string"),
        emit = field("enum", default = "live", values = c("live", "settle")),
        clear_on = field("string")
    ),
                         password_input = list(
        # No `value` field, by schema. A field that cannot be expressed
        # cannot be rendered into page source.
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        placeholder = field("string"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         textarea_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("string", default = ""),
        rows = field("int", default = 4L, min = 1, max = 100),
        placeholder = field("string"),
        emit = field("enum", default = "live", values = c("live", "settle")),
        # same contract as text_input's clear_on
        clear_on = field("string")
    ),
                         number_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("number"),
        min = field("number"),
        max = field("number"),
        step = field("number"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         select_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        choices = field("choices", required = TRUE),
        # Strings, plural, because a multiple select has more than one
        # selection and a scalar field made "pick some" expressible
        # only as "pick one". How many are allowed depends on
        # `multiple`, which check_component() enforces.
        selected = field("strings"),
        multiple = field("bool", default = FALSE),
        # A filter-as-you-type view over the same closed choices: the
        # typed text filters, only a real choice ever reports. Single
        # only -- check_component() refuses search + multiple.
        search = field("bool", default = FALSE),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         checkbox_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("bool", default = FALSE),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         radio_buttons = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        choices = field("choices", required = TRUE),
        selected = field("string"),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         checkbox_group = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        choices = field("choices", required = TRUE),
        # the array of checked members' values -- at every length,
        # like a multiple select's `selected`
        selected = field("strings"),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         slider_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        min = field("number", required = TRUE),
        max = field("number", required = TRUE),
        value = field("number"),
        step = field("number"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         range_slider = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        min = field("number", required = TRUE),
        max = field("number", required = TRUE),
        # exactly [lo, hi]; the pair rule lives in check_component()
        # the way select_input's multiple/selected rule does
        value = field("numbers"),
        step = field("number"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         date_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("string"),
        min = field("string"),
        max = field("string"),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         file_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        accept = field("any"),
        multiple = field("bool", default = FALSE)
    ),

                         # events, not inputs: they carry no value the server keeps
                         button = list(
                                       # `value` rides along on the event, so one server
                                       # handler serves a list of rows: the row says which
                                       # entry it is. Without it every row needs its own id
                                       # and its own observer, which is impossible when the
                                       # rows are built per render.
                                       value = field("string"),
                                       id = field("string", required = TRUE),
                                       label = field("string", required = TRUE),
                                       variant = field("enum", default = "default",
            values = c("default", "primary", "secondary", "danger", "ghost",
                       "listing")),
                                       icon = field("string")
    ),
                         download_button = list(
        id = field("string", required = TRUE),
        label = field("string", default = "Download"),
        variant = field("enum", default = "default",
                        values = c("default", "primary", "secondary", "danger",
                                   "ghost", "listing")),
        icon = field("string")
    ),

                         # outputs
                         #
                         # An output component is a slot: it names an id and says how to
                         # present whatever value arrives for it. What that value *is*
                         # comes from the renderer, as `kind` on the output message, which
                         # is why none of these carry a value field.
                         text_output = list(
        id = field("string", required = TRUE),
        variant = field("enum", default = "normal", values = TEXT_VARIANTS)
    ),
                         verbatim_output = list(id = field("string", required = TRUE)),
                         table_output = list(id = field("string", required = TRUE)),
                         data_table = list(
        id = field("string", required = TRUE),
        page_length = field("int", default = 10L, min = 1),
        # page-size options offered; always an array on the wire
        length_menu = field("numbers", default = c(10, 25, 50, 100)),
        searchable = field("bool", default = TRUE),
        sortable = field("bool", default = TRUE),
        # Given a selection mode the table is also an input: the
        # client reports the keys of the chosen rows under the
        # table's id. Not `variant` on purpose -- selection is
        # behaviour, not look, and the variant machinery (CSS guard,
        # KNOWN_VARIANTS) should not have to answer for it.
        selection = field("enum", default = "none",
                          values = c("none", "single", "multiple"))
    ),
                         plot_output = list(
        id = field("string", required = TRUE),
        width = field("int", min = 1, max = 8192),
        height = field("int", min = 1, max = 8192),
        alt = field("string", default = "")
    ),
                         image_output = list(
        id = field("string", required = TRUE),
        alt = field("string", default = "")
    ),
                         audio_output = list(
        id = field("string", required = TRUE),
        controls = field("bool", default = TRUE),
        autoplay = field("bool", default = FALSE)
    ),
                         video_output = list(
        id = field("string", required = TRUE),
        controls = field("bool", default = TRUE),
        autoplay = field("bool", default = FALSE),
        muted = field("bool", default = FALSE),
        loop = field("bool", default = FALSE),
        # Opt-in, because most videos never need to phone home and a
        # report per timeupdate for every player is noise. With it the
        # player reports position and state through the input channel:
        # input[[id]] holds list(current_time =, playing =).
        report = field("bool", default = FALSE)
    ),
                         # Browser-only, like tag(): raw markup has no widget equivalent.
                         html_output = list(id = field("string", required = TRUE)),
                         ui_output = list(id = field("string", required = TRUE)),

                         # A server-fed item log: feed_append() adds one item
                         # without resending the rest, feed_patch() rewrites
                         # the newest (token streaming), feed_reset() replaces
                         # the window (history load, resume replay). Items are
                         # ordinary component trees. Starts empty on purpose:
                         # the server's log is the one source of what a feed
                         # holds, so there is no children field to disagree
                         # with it. `keep` bounds the window; every feed
                         # message carries the effective value, so no client
                         # reads it from a second place at runtime. The feed
                         # owns its scroll (stick to bottom while the reader
                         # is there, release on scroll-up, offer a way back),
                         # because apps hand-rolling that each get it subtly
                         # wrong.
                         feed = list(
                                     id = field("string", required = TRUE),
                                     keep = field("int", default = FEED_KEEP_DEFAULT, min = 1),
                                     grow = field("int"),
                                     width = field("int")
    ),

                         # composite layout
                         tabset = list(
                                       id = field("string", required = TRUE),
                                       panels = field("panels", required = TRUE),
                                       selected = field("string")
    ),
                         conditional_panel = list(
        condition = field("condition", required = TRUE),
        children = field("children", required = TRUE)
    ),

                         # keyboard
                         #
                         # Modifiers are three booleans rather than one packed
                         # string, and the key is a token from a closed set,
                         # because the alternative is every frontend parsing
                         # "ctrl+shift+k" for itself and two of them
                         # disagreeing about a case nobody wrote a test for.
                         # The R constructor does the parsing once.
                         shortcut = list(
        id = field("string", required = TRUE),
        key = field("enum", required = TRUE, values = KEY_NAMES),
        value = field("string"),
        ctrl = field("bool", default = FALSE),
        shift = field("bool", default = FALSE),
        alt = field("bool", default = FALSE),
        typing = field("bool", default = FALSE),
        hold = field("bool", default = FALSE)
    ),

                         # escape hatch
                         raw_html = list(html = field("string", required = TRUE))
)

#' Output components and the value kinds they accept
#'
#' A slot that receives a kind it cannot present is a bug worth naming
#' at render time rather than drawing nothing, so the pairing is data
#' rather than scattered through the lowerings.
#'
#' @keywords internal
OUTPUT_KINDS <- list(text_output = "text", verbatim_output = "text",
                     table_output = "table", data_table = "table",
                     plot_output = "image", image_output = "image",
                     audio_output = "audio", video_output = "video",
                     ui_output = "ui")

#' What each input emits, and of what type
#'
#' Kept beside the schema rather than inside it because it describes
#' the component's protocol behaviour, not a field the wire carries.
#'
#' `message` is which client-to-server message the component produces:
#' `input` for something whose value the server keeps, `event` for a
#' discrete action it merely observes. `value_type` is what that
#' message's value must be, and is what the conformance test holds
#' both lowerings to.
#'
#' A select is the one component whose value type depends on a field
#' rather than only on the component, so it declares both. Saying
#' only "string" was how a multiple select came to be scalar in three
#' separate places.
#'
#' @keywords internal
INPUT_META <- list(
                   text_input = list(message = "input", value_type = "string"),
                   password_input = list(message = "input", value_type = "string"),
                   textarea_input = list(message = "input", value_type = "string"),
                   number_input = list(message = "input", value_type = "number"),
                   select_input = list(message = "input", value_type = "string",
                                       value_type_multiple = "strings"),
                   checkbox_input = list(message = "input", value_type = "bool"),
                   radio_buttons = list(message = "input", value_type = "string"),
                   checkbox_group = list(message = "input", value_type = "strings"),
                   slider_input = list(message = "input", value_type = "number"),
                   range_slider = list(message = "input", value_type = "numbers"),
                   date_input = list(message = "input", value_type = "string"),
                   file_input = list(message = "input", value_type = "files"),
                   # A button's event carries a value when the component
                   # declared one, and carries none otherwise: the press
                   # is then the whole message. Two entries rather than
                   # one, because which it is depends on the component,
                   # exactly as with a select and `multiple`.
                   button = list(message = "event", value_type = NULL,
                                 value_type_valued = "string"),
                   download_button = list(message = "event", value_type = NULL),
                   # A shortcut is a button you cannot see: it emits the
                   # same frame, so the server observes it identically
                   # and an app can bind one id to both.
                   shortcut = list(message = "event", value_type = NULL,
                                   value_type_valued = "string")
)

#' Is this component an input or event emitter?
#'
#' @param name character component name
#' @return logical
#' @keywords internal
is_input_component <- function(name) {
    !is.null(INPUT_META[[name]])
}

#' Construct a component
#'
#' @param type character component name, present in COMPONENT_SCHEMA
#' @param ... fields for this component
#' @return a glinty_component
#' @keywords internal
component <- function(type, ...) {
    schema <- COMPONENT_SCHEMA[[type]]
    if (is.null(schema)) {
        stop("unknown component type: ", type, call. = FALSE)
    }
    fields <- list(...)

    if (length(fields) > 0L) {
        nms <- names(fields)
        if (is.null(nms) || any(!nzchar(nms))) {
            stop(type, "() fields must all be named", call. = FALSE)
        }
        # list(value = "a", value = "b") keeps both, and [[ returns the
        # first, so the second would be silently discarded.
        if (anyDuplicated(nms) > 0L) {
            stop(type, "() got duplicate field(s): ",
                 paste(unique(nms[duplicated(nms)]), collapse = ", "),
                 call. = FALSE)
        }
    }

    unknown <- setdiff(names(fields), names(schema))
    if (length(unknown) > 0L) {
        stop(type, "() got unknown field(s): ",
             paste(unknown, collapse = ", "), ". Allowed: ",
             paste(names(schema), collapse = ", "), call. = FALSE)
    }

    out <- list()
    for (nm in names(schema)) {
        spec <- schema[[nm]]
        value <- fields[[nm]]

        # An explicit NULL is an absent field, not a present one:
        # names(list(value = NULL)) is "value", so checking names alone
        # would accept it and then drop it, yielding a component with a
        # required field missing.
        if (is.null(value)) {
            if (isTRUE(spec$required)) {
                stop(type, "() requires field '", nm, "'", call. = FALSE)
            }
            if (!is.null(spec$default)) {
                out[[nm]] <- spec$default
            }
            next
        }
        out[[nm]] <- check_field(value, spec, type, nm)
    }
    out <- check_component(type, out)

    structure(c(list(component = type), out), class = "glinty_component")
}

#' Validate and normalize one field value
#'
#' @param value the supplied value
#' @param spec a field spec
#' @param type character component type, for the error message
#' @param nm character field name, for the error message
#' @return the value, coerced to its declared type
#' @keywords internal
check_field <- function(value, spec, type, nm) {
    where <- paste0(type, "(", nm, "=)")

    scalar <- function(ok, what) {
        if (length(value) != 1L || is.na(value) || !ok) {
            stop(where, " must be ", what, call. = FALSE)
        }
    }

    switch(spec$type,
           string = {
        scalar(is.character(value) || is.numeric(value), "a single string")
        return(as.character(value))
    },
           bool = {
        scalar(is.logical(value), "TRUE or FALSE")
        return(as.logical(value))
    },
           int =,
           number = {
        scalar(is.numeric(value) && is.finite(value), "a single number")
        if (identical(spec$type, "int")) {
            if (value != round(value)) {
                stop(where, " must be a whole number", call. = FALSE)
            }
            value <- as.integer(value)
        }
        if (!is.null(spec$min) && value < spec$min) {
            stop(where, " must be >= ", spec$min, call. = FALSE)
        }
        if (!is.null(spec$max) && value > spec$max) {
            stop(where, " must be <= ", spec$max, call. = FALSE)
        }
        return(value)
    },
           enum = {
        scalar(is.character(value), "a single string")
        if (!value %in% spec$values) {
            stop(where, " must be one of: ",
                 paste(spec$values, collapse = ", "), " (got '", value,
                 "')", call. = FALSE)
        }
        return(value)
    },
           panels = {
        # A tabset's panels are titled child lists rather than plain
        # components, because a tab has a name the frontend shows in
        # its own nav furniture -- Flutter builds a TabBar from these,
        # the browser builds buttons.
        if (!is.list(value) || length(value) == 0L) {
            stop(where, " must be a non-empty list of panels", call. = FALSE)
        }
        titles <- character(0L)
        out <- lapply(seq_along(value), function(i) {
            p <- value[[i]]
            if (!is.list(p) || is.null(p$title) || !nzchar(p$title)) {
                stop(where, " panel ", i, " needs a non-empty title",
                     call. = FALSE)
            }
            titles <<- c(titles, p$title)
            list(title = as.character(p$title),
                 children = check_children(
                    if (is.null(p$children)) list() else p$children,
                    paste0(type, " panel ", i)))
        })
        if (anyDuplicated(titles) > 0L) {
            stop(where, " titles must be unique; duplicated: ",
                 paste(unique(titles[duplicated(titles)]), collapse = ", "),
                 call. = FALSE)
        }
        return(unname(out))
    },
           condition = {
        if (!inherits(value, "glinty_condition")) {
            stop(where, " must be a condition from input_is(), cond_and(), ",
                 "cond_or() or cond_not()", call. = FALSE)
        }
        return(unclass(value))
    },
           choices = {
        # A named character vector is the R-idiomatic way to write
        # choices and the wire form is a list of {value, label}, so
        # normalize here rather than making every builder do it.
        if (is.character(value) || is.numeric(value)) {
            labels <- names(value)
            if (is.null(labels)) {
                labels <- as.character(value)
            }
            labels[!nzchar(labels)] <- as.character(value)[!nzchar(labels)]
            value <- lapply(seq_along(value), function(i) {
                list(value = as.character(value[[i]]),
                     label = as.character(labels[[i]]))
            })
        }
        if (!is.list(value) || length(value) == 0L) {
            stop(where, " must be a non-empty vector or list of choices",
                 call. = FALSE)
        }
        for (i in seq_along(value)) {
            ch <- value[[i]]
            if (!is.list(ch) || is.null(ch$value) || is.null(ch$label)) {
                stop(where, " choice ", i,
                     " must have both a value and a label", call. = FALSE)
            }
        }
        return(unname(value))
    },
           runs = {
        # rich_text's flat styled runs. Marks are present-and-TRUE or
        # absent on the wire -- FALSE is dropped, the same
        # absent-optionals-omitted rule the canonical serialization
        # keeps. href is scheme-restricted HERE, at the wire boundary,
        # so no client ever has to defend against javascript: on its
        # own -- markdown() pre-filters instead of erroring, because a
        # transcript must render whatever a model emitted, but a run
        # an app builds directly deserves the error.
        if (!is.list(value) || length(value) == 0L) {
            stop(where, " must be a non-empty list of runs", call. = FALSE)
        }
        out <- lapply(seq_along(value), function(i) {
            r <- value[[i]]
            if (!is.list(r) || is.null(r$text) || !is.character(r$text) ||
                      length(r$text) != 1L || is.na(r$text)) {
                stop(where, " run ", i, " needs text (a single string)",
                     call. = FALSE)
            }
            extra <- setdiff(names(r), c("text", "bold", "italic", "code",
                    "strike", "href"))
            if (length(extra) > 0L) {
                stop(where, " run ", i, " has unknown fields: ",
                     paste(extra, collapse = ", "), call. = FALSE)
            }
            keep <- list(text = r$text)
            for (mark in c("bold", "italic", "code", "strike")) {
                v <- r[[mark]]
                if (!is.null(v)) {
                    if (!is.logical(v) || length(v) != 1L || is.na(v)) {
                        stop(where, " run ", i, " ", mark,
                             " must be TRUE or FALSE", call. = FALSE)
                    }
                    if (isTRUE(v)) {
                        keep[[mark]] <- TRUE
                    }
                }
            }
            if (!is.null(r$href)) {
                if (!md_href_ok(r$href)) {
                    stop(where, " run ", i, " href must be http(s), ",
                         "mailto, #fragment or site-relative",
                         call. = FALSE)
                }
                keep$href <- r$href
            }
            keep
        })
        return(unname(out))
    },
           numbers = {
        # Zero or more finite numbers; arity rules that depend on the
        # component (a range's exactly-two) live in check_component().
        if (is.list(value)) {
            value <- unlist(value, use.names = FALSE)
        }
        if (!is.numeric(value) || anyNA(value) || !all(is.finite(value))) {
            stop(where, " must be finite numbers", call. = FALSE)
        }
        return(as.numeric(value))
    },
           strings = {
        # Zero or more strings. A field whose arity depends on a
        # sibling field cannot be settled here -- see
        # check_component(), which is where select_input's `selected`
        # gets held to whatever `multiple` says.
        if (is.list(value)) {
            value <- unlist(value, use.names = FALSE)
        }
        if (is.null(value)) {
            value <- character(0L)
        }
        if (!(is.character(value) || is.numeric(value)) || anyNA(value)) {
            stop(where, " must be strings", call. = FALSE)
        }
        return(as.character(value))
    },
           children = {
        if (!is.list(value)) {
            stop(where, " must be a list of components", call. = FALSE)
        }
        return(check_children(value, type))
    },
           any = return(value)
    )
    stop("unknown field type in schema: ", spec$type, call. = FALSE)
}

#' Validate the fields of a component against each other
#'
#' Per-field checks cannot see their siblings, and a few components
#' have rules that span two. Run after every field has been checked
#' and defaulted, so this sees the normalized values.
#'
#' It also fixes the wire arity where it is not fixed by the field
#' type. `selected` on a single select is one string; on a multiple
#' select it is an array, including when the array holds one element
#' or none. Left to auto_unbox that array would collapse to a bare
#' string whenever exactly one option was chosen, so a client parsing
#' it would see a list on Tuesday and a string on Wednesday.
#'
#' @param type character component name
#' @param out the checked field list
#' @return the field list, adjusted
#' @keywords internal
check_component <- function(type, out) {
    if (type %in% c("row", "column", "panel")) {
        # Contradictory instructions, and the two lowerings resolve
        # them differently: the browser lets the later CSS rule win
        # (width), Flutter lets Expanded win (grow). Rather than pick
        # one and have the other quietly disagree, refuse -- the app
        # meant one of them.
        if (!is.null(out$grow) && out$grow > 0L && !is.null(out$width)) {
            stop(type, "() takes grow= or width=, not both: a container ",
                 "cannot both fill the spare space and be a fixed size",
                 call. = FALSE)
        }
    }
    if (identical(type, "link")) {
        # One or the other, and at least one. `value` alone is a text
        # link, `children` alone wraps them. Neither is a link with
        # nothing in it, which renders as an invisible clickable
        # nothing; both at once has no defined order.
        has_value <- !is.null(out$value)
        has_children <- length(out$children) > 0L
        if (!has_value && !has_children) {
            stop("link() needs either value= (text) or children=",
                 call. = FALSE)
        }
        if (has_value && has_children) {
            stop("link() takes value= or children=, not both", call. = FALSE)
        }
    }
    if (identical(type, "select_input")) {
        selected <- out$selected
        if (isTRUE(out$multiple)) {
            # as.list() so toJSON() emits an array at every length.
            out$selected <- as.list(if (is.null(selected)) {
                    character(0L)
                } else {
                    selected
                })
        } else if (!is.null(selected)) {
            if (length(selected) != 1L) {
                stop("select_input(selected=) must be a single string ",
                     "unless multiple = TRUE (got ", length(selected), ")",
                     call. = FALSE)
            }
            out$selected <- selected[[1L]]
        }
        if (isTRUE(out$search) && isTRUE(out$multiple)) {
            # explicit refusal, not silent degradation: the combobox
            # is single-select, a multiple select filters natively
            stop("select_input(search=) is single-select; ",
                 "drop multiple = TRUE", call. = FALSE)
        }
    }
    if (type %in% c("text_input", "textarea_input") &&
        !is.null(out$clear_on) && identical(out$emit, "settle")) {
        # explicit refusal: a settle field's draft is unreported until
        # blur, so clearing at emit time would discard text the server
        # never heard -- the handler would read yesterday's value and
        # the user's message would be gone everywhere
        stop(type, "(clear_on=) needs emit = \"live\"; a settle field's ",
             "text is unreported when the event fires", call. = FALSE)
    }
    if (identical(type, "data_table")) {
        # as.list() so a one-option menu still emits an array
        out$length_menu <- as.list(out$length_menu)
    }
    if (identical(type, "checkbox_group")) {
        # as.list() so toJSON() emits an array at every length --
        # select_input's multiple rule; the group's value is always
        # plural even when one or zero boxes are checked
        out$selected <- as.list(if (is.null(out$selected)) {
                character(0L)
            } else {
                as.character(out$selected)
            })
    }
    if (identical(type, "range_slider")) {
        v <- out$value
        if (!is.null(v)) {
            if (length(v) != 2L) {
                stop("range_slider(value=) must be c(lo, hi) ",
                     "(got length ", length(v), ")", call. = FALSE)
            }
            if (v[[1L]] > v[[2L]]) {
                stop("range_slider(value=) must have lo <= hi", call. = FALSE)
            }
            if (v[[1L]] < out$min || v[[2L]] > out$max) {
                stop("range_slider(value=) must sit within [min, max]",
                     call. = FALSE)
            }
            # as.list() so toJSON() emits an array, the wire shape a
            # client expects for a pair
            out$value <- as.list(v)
        }
    }
    out
}

#' Is this a component?
#'
#' @param x any object
#' @return logical
#' @keywords internal
is_component <- function(x) {
    inherits(x, "glinty_component")
}

#' Validate a list of children
#'
#' NULLs are dropped so conditional children compose, but the index in
#' the error message is the caller's original one -- reporting a
#' post-filter index sends people looking at the wrong argument.
#'
#' Reached through check_field() rather than called directly, so a
#' builder cannot forget it.
#'
#' @param children list of candidate children
#' @param fn character calling function, for the error message
#' @return the list, filtered and unnamed
#' @keywords internal
check_children <- function(children, fn) {
    keep <- !vapply(children, is.null, logical(1L))
    for (i in seq_along(children)) {
        if (!keep[[i]] || is_component(children[[i]])) {
            next
        }
        stop(fn, "() child ", i, " is not a component (got ",
             paste(class(children[[i]]), collapse = "/"), "). ",
             "Wrap plain strings in text().", call. = FALSE)
    }
    unname(children[keep])
}

#' Print a component as its wire form
#'
#' Shows exactly what a client receives, which is the useful view when
#' the question is why a frontend rendered something unexpected.
#'
#' @param x a glinty_component
#' @param ... ignored
#' @return x, invisibly
#' @examples
#' \dontrun{
#' print(glinty:::component("text", value = "hello"))
#' }
#' @export
print.glinty_component <- function(x, ...) {
    cat(as.character(jsonlite::toJSON(unclass_recursive(x), auto_unbox = TRUE,
                                      pretty = TRUE)),
        "\n")
    invisible(x)
}

#' The protocol version this glinty speaks
#'
#' Carried in the fixture artifact and, from stage 2, in `hello` and
#' `welcome`, so a client can refuse a wire format it was not written
#' against rather than rendering half of it.
#'
#' @keywords internal
PROTOCOL_VERSION <- 4L
