# Port of shiny-examples 010-download: a select picks the dataset,
# the table shows it, and the download button hands back the same
# data as CSV. download_handler() carries Shiny's two pieces -- a
# computed filename and a content function writing to the path it
# is given -- but registers on the session by id rather than
# assigning into output$: the press IS the transfer, so there is no
# output value to hold.
library(glinty)

app(
    ui = page(
        heading("Downloading Data", level = 1L),
        row(
            panel(variant = "sidebar", width = 280L,
                select_input("dataset", "Choose a dataset:",
                    choices = c("rock", "pressure", "cars")),
                spacer(1L),
                download_button("download_data", "Download",
                    variant = "primary")),
            column(grow = 1L,
                table_output("table")),
            align = "start"
        ),
        title = "Downloading Data"
    ),
    server = function(input, output, session) {
        dataset_input <- reactive(function() {
            switch(input$dataset(),
                rock = datasets::rock,
                pressure = datasets::pressure,
                cars = datasets::cars)
        })
        output$table <- render_table(function() dataset_input())
        download_handler(session, "download_data",
            filename = function() paste0(input$dataset(), ".csv"),
            content = function(file) {
                utils::write.csv(dataset_input(), file, row.names = FALSE)
            })
    }
)
