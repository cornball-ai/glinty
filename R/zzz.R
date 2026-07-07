.globals <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
    .globals$current_context <- NULL
    .globals$pending_flush <- list()
    .globals$flush_scheduled <- FALSE
    .globals$ctx_id_counter <- 0L
    .globals$current_session <- NULL
    .globals$sessions <- new.env(parent = emptyenv())
    .globals$timers <- list()
    .globals$timer_id_counter <- 0L
}
