library(glinty)

app(
    ui = page(
        h1("Clock and sine"),
        p("The clock re-renders every second via invalidate_later();",
            " the plot re-renders on slider moves."),
        text_output("now"),
        slider_input("n", "Wavelengths:", min = 1, max = 10, value = 2,
            step = 1),
        plot_output("wave"),
        title = "glinty clock"
    ),
    server = function(input, output) {
        output$now <- render_text(function() {
            invalidate_later(1000)
            format(Sys.time(), "%H:%M:%S")
        })
        output$wave <- render_plot(function() {
            n <- input$n()
            if (is.null(n)) n <- 2
            x <- seq(0, n * 2 * pi, length.out = 500L)
            plot(x, sin(x), type = "l", lwd = 2, col = "#2456d6",
                xlab = "x", ylab = "sin(x)")
        })
    }
)
