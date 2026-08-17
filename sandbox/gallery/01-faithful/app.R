# Port of the Shiny gallery "Faithful" (Hello Shiny) app.
# Original: sidebarLayout(sidebarPanel(sliderInput bins), mainPanel(plotOutput)).
library(glinty)

app(
    ui = page(
        heading("Hello glinty", level = 1L),
        row(
            panel(
                slider_input("bins", "Number of bins:",
                    min = 1, max = 50, value = 30, step = 1),
                variant = "sidebar", width = 260
            ),
            panel(
                plot_output("dist", height = 400),
                grow = 1
            ),
            align = "stretch", gap = 16L
        ),
        title = "Faithful"
    ),
    server = function(session, input, output) {
        output$dist <- render_plot(function() {
            x <- faithful$waiting
            bins <- seq(min(x), max(x), length.out = input$bins() + 1)
            hist(x, breaks = bins, col = "#75AADB", border = "white",
                 xlab = "Waiting time to next eruption (min)",
                 main = "Histogram of waiting times")
        })
    }
)
