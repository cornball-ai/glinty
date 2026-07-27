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
#' @return A UI component
#' @examples
#' text_input("name", "Name:")
#' @export
text_input <- function(id, label = "", value = "", placeholder = NULL,
                       emit = "live") {
    component("text_input", id = id, label = label, value = value,
              placeholder = placeholder, emit = emit)
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
#' @return A UI component
#' @examples
#' textarea_input("notes", "Notes:", rows = 6L)
#' @export
textarea_input <- function(id, label = "", value = "", rows = 4L,
                           placeholder = NULL, emit = "live") {
    component("textarea_input", id = id, label = label, value = value,
              rows = rows, placeholder = placeholder, emit = emit)
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
#' @param id character input ID
#' @param label character label text
#' @param choices character vector of choices; names are display
#'   labels. A list of value/label pairs also works.
#' @param selected character value selected initially
#' @param multiple logical allow several selections
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' select_input("engine", "Engine:", c(Fast = "fast", Slow = "slow"))
#' @export
select_input <- function(id, label = "", choices = character(0),
                         selected = NULL, multiple = FALSE, emit = "settle") {
    component("select_input", id = id, label = label, choices = choices,
              selected = selected, multiple = multiple, emit = emit)
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

#' Create a range slider
#'
#' @param id character input ID
#' @param label character label text
#' @param min,max numeric bounds
#' @param value numeric initial value
#' @param step numeric step size; a frontend may derive its own
#'   division count from it, which is why it is a number
#' @param emit character "live" or "settle"
#' @return A UI component
#' @examples
#' slider_input("n", "Points:", min = 10, max = 500, value = 100, step = 10)
#' @export
slider_input <- function(id, label = "", min = 0, max = 1, value = NULL,
                         step = NULL, emit = "live") {
    component("slider_input", id = id, label = label, min = min, max = max,
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
#' @return A UI component
#' @examples
#' button("go", "Run", variant = "primary")
#' @export
button <- function(id, label, variant = "default", icon = NULL) {
    component("button", id = id, label = label, variant = variant, icon = icon)
}
