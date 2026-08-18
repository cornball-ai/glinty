# Port of shiny-examples 003-reactivity: the dataset viewer that
# teaches the shared reactive expression. The caption re-renders as
# you type (text_input's default emit = "live") and draws as a
# heading via render_ui, glinty's shape for reactive structure. One
# dataset reactive feeds both summary and table and recomputes only
# when the dropdown changes.
library(glinty)

app(
    ui = page(
        heading("Reactivity", level = 1L),
        row(
            panel(variant = "sidebar", width = 280L,
                text_input("caption", "Caption:", value = "Data Summary"),
                select_input("dataset", "Choose a dataset:",
                    choices = c("rock", "pressure", "cars")),
                number_input("obs", "Number of observations to view:",
                    value = 10, min = 1)),
            column(grow = 1L,
                ui_output("caption_head"),
                verbatim_output("summary"),
                table_output("view")),
            align = "start"
        ),
        title = "Reactivity"
    ),
    server = function(input, output, session) {
        dataset_input <- reactive(function() {
            switch(input$dataset(),
                rock = datasets::rock,
                pressure = datasets::pressure,
                cars = datasets::cars)
        })
        output$caption_head <- render_ui(function() {
            heading(input$caption(), level = 3L)
        })
        output$summary <- render_text(function() {
            paste(utils::capture.output(summary(dataset_input())),
                collapse = "\n")
        })
        output$view <- render_table(function() {
            utils::head(dataset_input(), n = input$obs())
        })
    }
)
