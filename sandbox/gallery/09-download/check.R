# Download e2e in-process: the table tracks the select, and the
# download ticket path serves the CURRENT dataset under its own
# name -- filename and content both read the select at redemption
# time.
source("../../tools/drive.R")

d <- drive_boot("app.R", "download")

n <- function() length(drive_msgs(d, type = "output", id = "table"))
last <- function() {
    m <- drive_msgs(d, type = "output", id = "table")
    m[[length(m)]]$value
}

# --- boot: rock renders (48 rows)
stopifnot(n() == 1L, length(last()$rows) == 48L)
cat("boot: rock, 48 rows\n")

# --- select drives the table
drive_input(d, "dataset", "pressure")
stopifnot(n() == 2L, length(last()$rows) == 19L)
cat("dataset -> pressure: 19 rows\n")

# --- the ticket path: redeem a download grant like a client would
issue_ticket <- glinty:::issue_ticket
handle_download <- glinty:::handle_download
tok <- issue_ticket(d$session, "download_data", "download")$token
resp <- rawToChar(handle_download(list(method = "GET", path = "/download",
    query = paste0("ticket=", tok))))
stopifnot(grepl("200", strsplit(resp, "\r\n")[[1L]][[1L]]))
stopifnot(grepl('filename="pressure.csv"', resp, fixed = TRUE))
stopifnot(grepl("temperature", resp, fixed = TRUE))
body <- sub("(?s).*\r\n\r\n", "", resp, perl = TRUE)
stopifnot(length(strsplit(body, "\n")[[1L]]) >= 20L)
cat("download: pressure.csv, header + 19 rows\n")

# --- the filename tracks the select
drive_input(d, "dataset", "cars")
tok2 <- issue_ticket(d$session, "download_data", "download")$token
resp2 <- rawToChar(handle_download(list(method = "GET", path = "/download",
    query = paste0("ticket=", tok2))))
stopifnot(grepl('filename="cars.csv"', resp2, fixed = TRUE))
stopifnot(grepl("speed", resp2, fixed = TRUE))
cat("select changed: cars.csv with cars content\n")

# --- a spent ticket does not serve twice
resp3 <- rawToChar(handle_download(list(method = "GET", path = "/download",
    query = paste0("ticket=", tok2))))
stopifnot(grepl("403", strsplit(resp3, "\r\n")[[1L]][[1L]]))
cat("ticket is one-shot\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("DOWNLOAD OK\n")
