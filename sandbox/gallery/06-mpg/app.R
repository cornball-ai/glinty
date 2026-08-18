# Port of shiny-examples 004-mpg: a select picks which mtcars
# variable to box against mpg, a checkbox toggles outliers, and one
# reactive formula string feeds both the caption and the plot. The
# caption is Shiny's h3(textOutput(...)) -- here
# text_output(variant = "heading"), the round-6 vocabulary add.
library(glinty)

mpg_data <- datasets::mtcars
mpg_data$am <- factor(mpg_data$am, labels = c("Automatic", "Manual"))

app(
    ui = page(
        heading("Miles Per Gallon", level = 1L),
        row(
            panel(variant = "sidebar", width = 280L,
                select_input("variable", "Variable:",
                    choices = c(Cylinders = "cyl", Transmission = "am",
                        Gears = "gear")),
                spacer(1L),
                checkbox_input("outliers", "Show outliers", value = TRUE)),
            column(grow = 1L,
                text_output("caption", variant = "heading"),
                plot_output("mpg_plot", height = 400)),
            align = "start"
        ),
        title = "Miles Per Gallon"
    ),
    server = function(input, output, session) {
        formula_text <- reactive(function() {
            paste("mpg ~", input$variable())
        })
        output$caption <- render_text(function() formula_text())
        output$mpg_plot <- render_plot(function() {
            boxplot(stats::as.formula(formula_text()), data = mpg_data,
                outline = input$outliers(), col = "#75AADB", pch = 19)
        })
    }
)
