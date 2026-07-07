#' Create an update message
#'
#' The DOM patch used by all outputs: set one property on the element
#' with the given id.
#'
#' @param id character element ID
#' @param property character DOM property to update
#' @param value new value
#' @return character JSON string
#' @keywords internal
update_msg <- function(id, property, value) {
    as.character(jsonlite::toJSON(
        list(type = "update", id = id, property = property, value = value),
        auto_unbox = TRUE
    ))
}
