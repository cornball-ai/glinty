# Server-driven video playback. An output message replaces the
# element's source; this drives the player that is already there.

#' Drive a video output's playback from the server
#'
#' Seeks and plays/pauses the client's player without touching its
#' source -- a new output value swaps the video, this moves inside
#' it. The shape that wants it is an external playhead (a timeline, a
#' transport slider) kept in sync with a preview player.
#'
#' Both fields are optional and NULL leaves that half of the state
#' alone: `update_video(session, id, playing = FALSE)` pauses without
#' seeking, `update_video(session, id, current_time = 0)` rewinds
#' without deciding whether to play.
#'
#' A play may still be refused by the client -- browsers block
#' unmuted playback before the user has interacted with the page --
#' and a refusal is the client's to report, not a round trip this
#' waits on.
#'
#' @param session a glinty_session
#' @param id character video output ID
#' @param current_time numeric seek position in seconds
#' @param playing logical TRUE plays, FALSE pauses
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_video(session, "preview", current_time = 3.5, playing = TRUE)
#' }
#' @export
update_video <- function(session, id, current_time = NULL, playing = NULL) {
    if (!is.null(current_time)) {
        if (!is.numeric(current_time) || length(current_time) != 1L ||
            is.na(current_time) || !is.finite(current_time) ||
            current_time < 0) {
            stop("update_video() current_time must be one finite, ",
                 "non-negative number of seconds", call. = FALSE)
        }
        current_time <- as.numeric(current_time)
    }
    if (!is.null(playing)) {
        if (!is.logical(playing) || length(playing) != 1L || is.na(playing)) {
            stop("update_video() playing must be TRUE or FALSE", call. = FALSE)
        }
    }
    fields <- list(current_time = current_time, playing = playing)
    fields <- fields[!vapply(fields, is.null, logical(1L))]
    if (length(fields) == 0L) {
        return(invisible(NULL))
    }
    session$send(video_update_msg(id, fields))
    invisible(NULL)
}
