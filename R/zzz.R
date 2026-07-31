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
    .globals$progress <- list()
    .globals$welcome_ui <- NULL
    .globals$welcome_revision <- NULL
    .globals$welcome_theme <- NULL
    .globals$tickets <- new.env(parent = emptyenv())
    .globals$jobs <- new.env(parent = emptyenv())
    .globals$job_queues <- list()
    .globals$job_lanes <- JOB_DEFAULT_LANES
    .globals$job_timer <- NULL
    .globals$job_id_counter <- 0L
    .globals$job_progress_last <- NULL
    reg_reset()
}
