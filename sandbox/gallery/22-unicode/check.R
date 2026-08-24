# Unicode e2e in-process: Chinese as values, labels, data, and one
# output ID, surviving the trip through JSON both directions. The
# assertions compare against escaped literals so this file itself
# stays ASCII-robust regardless of the reading locale.
source("../../tools/drive.R")

rock_name <- "岩石"                      # 岩石
summary_id <- paste0("summary这里也",
                     "可以用中文")

d <- drive_boot("app.R")
drive_measure(d, "rockplot", 600, 300)

last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}
n <- function(id) length(drive_msgs(d, type = "output", id = id))

# --- boot: the Chinese default value seeded and round-tripped
stopifnot(identical(glinty::isolate(d$input$dataset()), rock_name))
# the Chinese-named output rendered a Chinese summary
stopifnot(n(summary_id) == 1L)
stopifnot(grepl("面积", last(summary_id)))   # 面积 in summary
# dynamic UI delivered the vars select with Chinese choices
ui_msgs <- drive_msgs(d, type = "output", id = "rockvars")
stopifnot(length(ui_msgs) >= 1L)
ui_val <- ui_msgs[[length(ui_msgs)]]$value
stopifnot(identical(ui_val$component, "select_input"))
chs <- vapply(ui_val$choices, function(ch) ch$value, character(1L))
stopifnot(identical(chs, c("周长", "形状",
                           "渗透性")))
# the table carries the Chinese header
stopifnot(identical(unlist(last("view")$header)[1L], "面积"))
cat("boot: Chinese values, output id, dynamic UI, table header\n")

# --- the plot waits on the dynamic input, then renders with req()
drive_input(d, "vars", "周长")           # 周长
stopifnot(n("rockplot") >= 1L)
stopifnot(grepl("^data:image/png", last("rockplot")$src))
cat("vars -> Chinese column: formula plot rendered\n")

# --- switching to an ASCII dataset flips everything through
drive_input(d, "dataset", "cars")
stopifnot(identical(unlist(last("view")$header),
                    c("speed", "dist", "random")))
# the random column is Chinese characters as data
stopifnot(any(grepl("[一-鿿]", unlist(last("view")$rows))))
# dynamic UI slot emptied (NULL render)
cat("dataset -> cars: Chinese factor data in the table\n")

# --- the summary checkbox gates with a Chinese message
drive_input(d, "summary", FALSE)
stopifnot(grepl("隐藏", last(summary_id)))  # 隐藏
cat("summary off: Chinese fallback message\n")

# --- input frames with Chinese values leave no mojibake anywhere
all_json <- paste(unlist(d$session$outgoing), collapse = "")
stopifnot(!grepl("�", all_json))            # no replacement chars
stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("Unicode OK\n")
