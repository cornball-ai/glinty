#' Find environment secrets appearing in text
#'
#' Reports the names of environment variables whose values occur in
#' the given text. Only variables that look like secrets are checked:
#' the name must contain KEY, TOKEN, SECRET, PASSWORD, PASSWD or
#' CREDENTIAL, and the value must be at least min_chars long, which
#' keeps short or empty settings from matching by accident.
#'
#' Only the variable names are ever returned, never the values, so
#' the result is safe to print, log, or put in a test failure.
#'
#' run_app() calls this on the rendered page before serving it. Use it
#' directly to assert the same thing in an app's own tests.
#'
#' @param text character to search (the rendered page, typically)
#' @param min_chars integer shortest value worth checking
#' @return character vector of variable names, empty when clean
#' @examples
#' env_secrets_in("<p>nothing to see</p>")
#' @export
env_secrets_in <- function(text, min_chars = 8L) {
    if (length(text) == 0L) {
        return(character(0L))
    }
    text <- paste(text, collapse = "")
    env <- Sys.getenv()
    if (length(env) == 0L) {
        return(character(0L))
    }
    secretish <- grepl("KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL",
                       names(env), ignore.case = TRUE)
    candidates <- env[secretish & nchar(env) >= min_chars]
    if (length(candidates) == 0L) {
        return(character(0L))
    }
    hit <- vapply(candidates, function(v) grepl(v, text, fixed = TRUE),
                  logical(1L))
    names(candidates)[hit]
}

#' Refuse to serve a page containing a secret
#'
#' The failure this exists to stop: prefilling an input from
#' Sys.getenv(), which renders the secret into the page source as a
#' plain attribute. type="password" masks the screen, not the HTML, so
#' the value is readable by anyone who can fetch the page -- and base
#' R's serverSocket() listens on all interfaces.
#'
#' Stops rather than warns, because a warning at startup scrolls past
#' and the app keeps serving the secret.
#'
#' @param page_html character the rendered page
#' @param strict logical stop (TRUE) or warn (FALSE)
#' @return invisible character vector of offending variable names
#' @keywords internal
check_page_secrets <- function(page_html, strict = TRUE) {
    hits <- env_secrets_in(page_html)
    if (length(hits) == 0L) {
        return(invisible(character(0L)))
    }
    msg <- paste0(
                  "the rendered page contains the value of ",
                  paste(hits, collapse = ", "), ".\n",
                  "A secret in page source is readable by anyone who can fetch ",
                  "the page; type=\"password\" masks the screen, not the HTML.\n",
                  "Read the secret server-side rather than prefilling an input, ",
                  "and let an empty field mean \"use the configured one\".\n",
                  "Pass check_secrets = FALSE to run_app() if this is deliberate."
    )
    if (isTRUE(strict)) {
        stop(msg, call. = FALSE)
    }
    warning(msg, call. = FALSE)
    invisible(hits)
}
