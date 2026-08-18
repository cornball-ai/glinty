# Port of BOTH shiny-examples 015s in one app, because each alone is
# a fragment: 015-layout-sidebar (sidebar on the right) and
# 015-layout-navbar (navbarPage with three tab panels).
#
# sidebar-right is child order in a row() -- glinty has no `position`
# argument because the tree already says where things are. The
# navbar ports as a tabset on a full-width page: same navigation,
# in-page chrome. Shiny's navbarPage is top-level window chrome
# (brand bar, page-wide swap); that distinction is real and stays
# open in the gap table -- three empty tabPanels are not enough
# signal to design chrome against.
library(glinty)

app(
    ui = page(
        tabset(id = "nav",
            tab_panel("Component 1",
                heading("Hello Shiny!", level = 1L),
                row(
                    column(grow = 1L,
                        plot_output("dist_plot", height = 400L)),
                    panel(variant = "sidebar", width = 300L,
                        slider_input("bins", "Number of bins:",
                            min = 1, max = 50, value = 30)),
                    align = "start"
                )),
            tab_panel("Component 2",
                txt("Nothing here either, faithfully.",
                    variant = "muted")),
            tab_panel("Component 3",
                txt("The original ships three empty panels;
                     one of them at least admits it.",
                    variant = "muted"))),
        title = "My Application",
        width = "full"
    ),
    server = function(input, output, session) {
        output$dist_plot <- render_plot(function() {
            x <- datasets::faithful[, 2]
            bins <- seq(min(x), max(x),
                        length.out = input$bins() + 1)
            hist(x, breaks = bins, col = "darkgray", border = "white")
        })
    }
)
