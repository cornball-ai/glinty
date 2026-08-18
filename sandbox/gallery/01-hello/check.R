# Faithful e2e in-process: measure -> raster; slider change -> new raster.
source("../../tools/drive.R")

d <- drive_boot("app.R", "faithful")
drive_measure(d, "dist", 900, 400)

imgs <- drive_msgs(d, type = "output", id = "dist")
stopifnot(length(imgs) >= 1L)
first <- imgs[[length(imgs)]]$value$src
stopifnot(grepl("^data:image/png;base64,", first))
cat("initial raster:", nchar(first), "chars,",
    imgs[[length(imgs)]]$value$width, "x",
    imgs[[length(imgs)]]$value$height, "\n")

drive_input(d, "bins", 5L)
imgs2 <- drive_msgs(d, type = "output", id = "dist")
second <- imgs2[[length(imgs2)]]$value$src
stopifnot(length(imgs2) > length(imgs), !identical(first, second))
cat("after bins=5: new raster differs, total plot frames:",
    length(imgs2), "\n")

errs <- drive_msgs(d, type = "error")
cat("error frames:", length(errs), "\n")
stopifnot(length(errs) == 0L)
cat("FAITHFUL OK\n")
