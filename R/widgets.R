# Input builders. Each is one component() call; validation, defaults
# and the wire format live in the schema.
#
# Every input takes `emit`, which says *when* it reports rather than
# how: "live" while the value is changing, "settle" once it has. The
# browser spends that on input/change events, Flutter on onChanged and
# onEditingComplete. Naming a DOM event here would make the API
# browser-shaped.

#' Create a text input
#'
#' @param id character input ID
#' @param label character label text
#' @param value character initial value
#' @param placeholder character placeholder text
#' @param emit character "live" to report while typing, "settle" to
#'   report when the field is committed
#' @param clear_on character event id; when the client emits that
#'   event it empties this field and reports "", after the event
#'   frame, so the event's handler still reads the full draft. The
#'   composer pattern: pair with a button or shortcut carrying the
#'   named id. Requires emit = "live".
#' @return A UI component
#' @examples
#' text_input("name", "Name:")
#' @export
text_input <- function(id, label = "", value = "", placeholder = NULL,
                       emit = "live", clear_on = NULL) {
    component("text_input", id = id, label = label, value = value,
              placeholder = placeholder, emit = emit, clear_on = clear_on)
}

#' Create a password input
#'
#' There is deliberately no value argument. A prefilled password is
#' rendered into the page source in plain text, where masking does
#' nothing, so a secret put here would be published. Read it
#' server-side and let an empty field mean "use the configured one".
#'
#' @param id character input ID
#' @param label character label text
#' @param placeholder character placeholder text; a good place to name
#'   the environment variable in play, without echoing it
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' password_input("api_key", "API Key:",
#'                placeholder = "using OPENAI_API_KEY")
#' @export
password_input <- function(id, label = "", placeholder = NULL, emit = "live") {
    component("password_input", id = id, label = label,
              placeholder = placeholder, emit = emit)
}

#' Create a multi-line text input
#'
#' @param id character input ID
#' @param label character label text
#' @param value character initial value
#' @param rows integer visible rows
#' @param placeholder character placeholder text
#' @param emit character "live" or "settle"
#' @param clear_on character event id; when the client emits that
#'   event it empties this field and reports "", after the event
#'   frame, so the event's handler still reads the full draft. The
#'   chat composer: \code{textarea_input("draft", clear_on = "send")}
#'   beside \code{shortcut("send", "enter", typing = TRUE)}. Requires
#'   emit = "live".
#' @return A UI component
#' @examples
#' textarea_input("notes", "Notes:", rows = 6L)
#' @export
textarea_input <- function(id, label = "", value = "", rows = 4L,
                           placeholder = NULL, emit = "live",
                           clear_on = NULL) {
    component("textarea_input", id = id, label = label, value = value,
              rows = rows, placeholder = placeholder, emit = emit,
              clear_on = clear_on)
}

#' Create a numeric input
#'
#' @param id character input ID
#' @param label character label text
#' @param value numeric initial value
#' @param min,max numeric bounds
#' @param step numeric step size
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' number_input("k", "Clusters:", value = 3, min = 1, max = 10)
#' @export
number_input <- function(id, label = "", value = NULL, min = NULL,
                         max = NULL, step = NULL, emit = "live") {
    component("number_input", id = id, label = label, value = value,
              min = min, max = max, step = step, emit = emit)
}

#' Create a select dropdown
#'
#' With `search = TRUE` the control is a combobox: typing filters the
#' same closed choice list, and only picking a real choice reports a
#' value -- the typed text is a view, never a value, so the input's
#' domain stays exactly the declared choices. Single-select only;
#' a multiple select already filters by scrolling and refuses the
#' flag. Long lists (dozens up) are where it earns the extra control.
#'
#' @param id character input ID
#' @param label character label text
#' @param choices character vector of choices; names are display
#'   labels. A list of value/label pairs also works.
#' @param selected character value selected initially
#' @param multiple logical allow several selections
#' @param search logical filter-as-you-type over the choices
#'   (single-select only)
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' select_input("engine", "Engine:", c(Fast = "fast", Slow = "slow"))
#' select_input("state", "State:", datasets::state.name, search = TRUE)
#' @export
select_input <- function(id, label = "", choices = character(0),
                         selected = NULL, multiple = FALSE, search = FALSE,
                         emit = "settle") {
    component("select_input", id = id, label = label, choices = choices,
              selected = selected, multiple = multiple, search = search,
              emit = emit)
}

#' Create a checkbox
#'
#' @param id character input ID
#' @param label character label text
#' @param value logical initial state
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' checkbox_input("save", "Save results", value = TRUE)
#' @export
checkbox_input <- function(id, label = "", value = FALSE, emit = "settle") {
    component("checkbox_input", id = id, label = label, value = value,
              emit = emit)
}

#' Create a radio button group
#'
#' One input value shared by the group: the selected member's value.
#'
#' @param id character input ID
#' @param label character group label
#' @param choices character vector of choices; names are display labels
#' @param selected character value selected initially
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' radio_buttons("mode", "Mode:", c(Fast = "fast", Careful = "careful"))
#' @export
radio_buttons <- function(id, label = "", choices = character(0),
                          selected = NULL, emit = "settle") {
    if (is.null(selected) && length(choices) > 0L) {
        selected <- unname(choices[[1L]])
    }
    component("radio_buttons", id = id, label = label, choices = choices,
              selected = selected, emit = emit)
}

#' Create a checkbox group input
#'
#' One id, many boxes: the value is the array of checked members'
#' values, an array at every length -- `["a"]`, never `"a"` -- the
#' same rule as a multiple select. Order follows the choices, not
#' the clicks. Unlike [radio_buttons()], nothing is selected unless
#' `selected` says so: an empty selection is a real state here.
#'
#' @param id character input ID
#' @param label character label text
#' @param choices choices in any of the usual shapes
#' @param selected character values checked at start; NULL for none
#' @param emit character "settle" (default) or "live"
#' @return A UI component
#' @examples
#' checkbox_group("show_vars", "Columns:",
#'     choices = c("carat", "cut", "color"),
#'     selected = c("carat", "cut"))
#' @export
checkbox_group <- function(id, label = "", choices = character(0),
                           selected = NULL, emit = "settle") {
    component("checkbox_group", id = id, label = label, choices = choices,
              selected = selected, emit = emit)
}

#' Create a range slider
#'
#' @param id character input ID
#' @param label character label text
#' @param min,max numeric bounds
#' @param value numeric initial value; defaults to the midpoint, which
#'   is where an HTML range input sits when given no value. Filling it
#'   in here puts the position on the wire, so every frontend starts
#'   the thumb in the same place instead of each applying its own
#'   default.
#' @param step numeric step size; a frontend may derive its own
#'   division count from it, which is why it is a number
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' slider_input("n", "Points:", min = 10, max = 500, value = 100, step = 10)
#' @export
slider_input <- function(id, label = "", min = 0, max = 1, value = NULL,
                         step = NULL, emit = "live") {
    if (is.null(value)) {
        value <- slider_default(min, max)
    }
    component("slider_input", id = id, label = label, min = min, max = max,
              value = value, step = step, emit = emit)
}

#' Create a two-thumb range slider
#'
#' One component, two thumbs: its value is the pair `c(lo, hi)` and
#' arrives server-side as a length-2 numeric vector. With no `value`
#' the thumbs start at the ends. `step` and `emit` behave exactly as
#' in [slider_input()]; a stepless range still drags at the implied
#' precision.
#'
#' @param id character input ID
#' @param label character label text
#' @param min,max numeric bounds
#' @param value numeric `c(lo, hi)` initial pair; NULL means the ends
#' @param step numeric step size; NULL for the implied precision
#' @param emit character "live" (default) or "settle"
#' @return A UI component
#' @examples
#' range_slider("years", "Years:", min = 1990, max = 2030,
#'     value = c(2000, 2015), step = 1)
#' @export
range_slider <- function(id, label = "", min = 0, max = 1, value = NULL,
                         step = NULL, emit = "live") {
    if (is.null(value)) {
        value <- c(min, max)
    }
    component("range_slider", id = id, label = label, min = min, max = max,
              value = value, step = step, emit = emit)
}

#' Create a date input
#'
#' The value arrives server-side as a "YYYY-MM-DD" string; convert
#' with as.Date() at the point of use. No hidden coercion.
#'
#' @param id character input ID
#' @param label character label text
#' @param value character initial date, "YYYY-MM-DD"
#' @param min,max character selectable range
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' date_input("start", "Start:", value = "2026-07-27")
#' @export
date_input <- function(id, label = "", value = NULL, min = NULL, max = NULL,
                       emit = "settle") {
    component("date_input", id = id, label = label, value = value,
              min = min, max = max, emit = emit)
}

#' Create a file input
#'
#' Files upload over HTTP rather than the socket; when the upload
#' completes the input value becomes a data.frame with one row per
#' file: name, size, type, datapath.
#'
#' @param id character input ID
#' @param label character label text
#' @param accept character vector of accepted types or extensions
#' @param multiple logical allow several files
#' @return A UI component
#' @examples
#' file_input("dataset", "CSV:", accept = ".csv")
#' @export
file_input <- function(id, label = "", accept = NULL, multiple = FALSE) {
    component("file_input", id = id, label = label, accept = accept,
              multiple = multiple)
}

#' Create a button
#'
#' A button emits an event rather than an input: there is no value the
#' server keeps. observe_event(input$id, ...) fires once per press.
#'
#' @param id character button ID
#' @param label character button label
#' @param variant character "default", "primary", "secondary",
#'   "danger" or "ghost"
#' @param icon character icon name shown before the label
#' @param value character carried on the event this button emits, so
#'   one `observe_event()` can serve a whole list: the press says which
#'   row. `input$id()` is then that value rather than a press count.
#'   An id is valued everywhere or nowhere: give every button sharing
#'   it a value, or none of them, since one observer cannot serve an
#'   `input$id()` that is sometimes a value and sometimes a count
#' @return A UI component
#' @examples
#' button("go", "Run", variant = "primary")
#' button("history_view", "12:04", value = "entry_7")
#' @export
button <- function(id, label, variant = "default", icon = NULL, value = NULL) {
    component("button", id = id, label = label, variant = variant,
              icon = icon, value = value)
}

# Modifier spellings a key spec may use, mapped onto the three the wire
# carries. cmd/meta/super fold into ctrl on purpose: an app that means
# "the platform's command modifier" should not have to say it twice, and
# every frontend already knows which key that is locally.
KEY_MODIFIERS <- c(ctrl = "ctrl", control = "ctrl", cmd = "ctrl",
                   command = "ctrl", meta = "ctrl", super = "ctrl",
                   shift = "shift", alt = "alt", option = "alt")

# Spellings for keys whose obvious name is not the token. Everything
# else has to BE a token, so a typo fails here rather than binding a
# shortcut that can never fire.
KEY_ALIASES <- c(esc = "escape", del = "delete", ins = "insert",
                 spacebar = "space", `return` = "enter", pgup = "pageup",
                 pgdn = "pagedown", pagedown = "pagedown",
                 arrowleft = "left", arrowright = "right", arrowup = "up",
                 arrowdown = "down", `,` = "comma", `.` = "period",
                 `/` = "slash", `\\` = "backslash", `;` = "semicolon",
                 `'` = "quote", `[` = "bracketleft", `]` = "bracketright",
                 `-` = "minus", `=` = "equal", `\`` = "backquote")

#' Parse a key spec into its wire fields
#'
#' @param spec character like "ctrl+shift+k", "space", "f5"
#' @return list(key, ctrl, shift, alt)
#' @keywords internal
parse_key <- function(spec) {
    if (!is.character(spec) || length(spec) != 1L || is.na(spec) ||
        !nzchar(spec)) {
        stop("shortcut(): key must be one non-empty string", call. = FALSE)
    }
    # "+" is the separator, so the key it would otherwise name is
    # spelled by its own token: "ctrl+=" or "ctrl+equal", never "ctrl++".
    parts <- strsplit(tolower(trimws(spec)), "+", fixed = TRUE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0L) {
        stop("shortcut(): key '", spec, "' names no key", call. = FALSE)
    }
    mods <- parts[-length(parts)]
    key <- parts[length(parts)]
    key <- unname(if (key %in% names(KEY_ALIASES)) KEY_ALIASES[[key]] else key)
    if (!key %in% KEY_NAMES) {
        stop("shortcut(): '", key, "' is not a key name; see KEY_NAMES",
             call. = FALSE)
    }
    bad <- setdiff(mods, names(KEY_MODIFIERS))
    if (length(bad) > 0L) {
        stop("shortcut(): unknown modifier(s): ",
             paste(bad, collapse = ", "), call. = FALSE)
    }
    on <- unique(unname(KEY_MODIFIERS[mods]))
    list(key = key, ctrl = "ctrl" %in% on, shift = "shift" %in% on,
         alt = "alt" %in% on)
}

#' Bind a key to an event
#'
#' A shortcut is a button you cannot see. It emits the same event frame
#' a `button()` does, so `observe_event(input$id, ...)` serves both and
#' one id can carry the visible control and its accelerator together.
#'
#' It renders nothing. Put it anywhere in the tree; a client that has
#' never heard of it says so where it sits, which is the point of
#' putting it in the tree rather than smuggling it in as a script.
#'
#' `key` is a spec like `"ctrl+shift+k"`, `"space"` or `"f5"`, parsed
#' here into the fields the wire carries. `ctrl` also means Command on a
#' Mac: an app that means "the platform's command modifier" should not
#' have to say it twice.
#'
#' By default a shortcut does NOT fire while a text field has focus,
#' because the alternative is `d` deleting a clip halfway through typing
#' a filename. Escape and the function keys usually want `typing = TRUE`.
#'
#' A shortcut takes the keypress: the browser's own binding for it does
#' not also run. Bind `ctrl+s` and it saves the project rather than
#' offering to save the page.
#'
#' @param id character event ID, as a `button()`'s would be
#' @param key character key spec: an optional `ctrl`/`shift`/`alt`
#'   (or `cmd`/`meta`/`option`) prefix joined by `+`, then one key
#' @param value character carried on the event, exactly as a button's
#'   is, so one handler can serve several bindings
#' @param typing logical fire even while a text input has focus
#' @param hold logical fire repeatedly while the key is held, for
#'   shortcuts that nudge rather than toggle
#' @return A UI component
#' @examples
#' shortcut("play", "space")
#' shortcut("save_project", "ctrl+s", typing = TRUE)
#' shortcut("nudge_left", "left", hold = TRUE)
#' @export
shortcut <- function(id, key, value = NULL, typing = FALSE, hold = FALSE) {
    k <- parse_key(key)
    component("shortcut", id = id, key = k$key, value = value,
              ctrl = k$ctrl, shift = k$shift, alt = k$alt, typing = typing,
              hold = hold)
}
