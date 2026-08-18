# Port of the Shiny gallery "Faithful" app (the tutorial classic):
# bins dropdown, two checkboxes, density with a conditional bandwidth
# slider. Original is a single-column bootstrapPage with the slider
# below the plot.
library(glinty)

app(
    ui = page(
        heading("Old Faithful eruptions", level = 1L),
        select_input("n_breaks", "Number of bins in histogram (approximate):",
            choices = c("10", "20", "35", "50"), selected = "20"),
        checkbox_input("individual_obs", "Show individual observations"),
        checkbox_input("density", "Show density estimate"),
        plot_output("main_plot", height = 300),
        conditional_panel(
                          slider_input("bw_adjust", "Bandwidth adjustment:",
                min = 0.2, max = 2, value = 1, step = 0.2),
                          condition = input_is("density", TRUE)
        ),
        title = "Faithful"
    ),
    server = function(input, output, session) {
        output$main_plot <- render_plot(function() {
            hist(faithful$eruptions, probability = TRUE,
                 breaks = as.numeric(input$n_breaks()),
                 xlab = "Duration (minutes)",
                 main = "Geyser eruption duration")
            if (isTRUE(input$individual_obs())) {
                rug(faithful$eruptions)
            }
            if (isTRUE(input$density())) {
                dens <- stats::density(faithful$eruptions,
                    adjust = input$bw_adjust())
                lines(dens, col = "blue")
            }
        })
    }
)
