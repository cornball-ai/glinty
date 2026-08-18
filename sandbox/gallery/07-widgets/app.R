# Port of shiny-examples 007-widgets: a dataset viewer whose outputs
# update only when Update View is pressed. Shiny's
# eventReactive(input$update, ..., ignoreNULL = FALSE) composes here
# as a reactive_val written by observe_event(ignore_init = FALSE,
# ignore_null = FALSE) -- the handler body already runs under
# isolate(), so reading the select inside adds no dependency, and
# ignore_init = FALSE computes the boot value the way ignoreNULL =
# FALSE does. The table's row count reads input$obs through
# isolate(), exactly as the original does.
library(glinty)

app(
    ui = page(
        heading("More Widgets", level = 1L),
        row(
            panel(variant = "sidebar", width = 300L,
                select_input("dataset", "Choose a dataset:",
                    choices = c("rock", "pressure", "cars")),
                number_input("obs", "Number of observations to view:",
                    value = 10),
                txt(paste("Note: while the data view will show only the",
                    "specified number of observations, the summary will",
                    "still be based on the full dataset."),
                    variant = "muted"),
                spacer(1L),
                button("update", "Update View", variant = "primary")),
            column(grow = 1L,
                heading("Summary", level = 4L),
                verbatim_output("summary"),
                heading("Observations", level = 4L),
                table_output("view")),
            align = "start"
        ),
        title = "More Widgets"
    ),
    server = function(input, output, session) {
        dataset_input <- reactive_val(NULL)
        observe_event(input$update, function() {
            dataset_input(switch(input$dataset(),
                rock = datasets::rock,
                pressure = datasets::pressure,
                cars = datasets::cars))
        }, ignore_init = FALSE, ignore_null = FALSE)
        output$summary <- render_text(function() {
            paste(utils::capture.output(summary(dataset_input())),
                collapse = "\n")
        })
        output$view <- render_table(function() {
            utils::head(dataset_input(), n = isolate(input$obs()))
        })
    }
)
