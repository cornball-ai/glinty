# Layout e2e in-process: the two 015s composed. The sidebar-right
# claim is a lowering-order fact, so the check reads the page HTML;
# the histogram re-renders on bins like round 1.
source("../../tools/drive.R")

d <- drive_boot("app.R")
drive_measure(d, "dist_plot", 700, 400)

last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}
n <- function(id) length(drive_msgs(d, type = "output", id = id))

# --- the tabset seeded, the plot rendered
stopifnot(identical(glinty::isolate(d$input$nav()), "Component 1"))
stopifnot(grepl("^data:image/png", last("dist_plot")$src))

# --- sidebar on the right IS the child order: plot slot before the
# sidebar panel in the lowered markup
html <- glinty:::component_to_html(d$app$ui)
plot_at <- regexpr('data-g-output="dist_plot"', html, fixed = TRUE)
side_at <- regexpr("g-panel-sidebar", html, fixed = TRUE)
stopifnot(plot_at > 0L, side_at > 0L, plot_at < side_at)
cat("sidebar-right: main content lowers before the sidebar\n")

# --- bins drives the histogram
p1 <- last("dist_plot")$src
drive_input(d, "bins", 5)
stopifnot(!identical(p1, last("dist_plot")$src))
cat("bins -> 5: histogram re-rendered\n")

# --- tab switches render nothing new
renders <- n("dist_plot")
drive_input(d, "nav", "Component 2")
stopifnot(identical(glinty::isolate(d$input$nav()), "Component 2"))
stopifnot(n("dist_plot") == renders)
cat("tab -> Component 2: pure visibility\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("Layout OK\n")
