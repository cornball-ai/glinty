# Port of shiny-examples 009-upload: a CSV lands over HTTP, its
# parse is steered by header/sep/quote controls, and req() keeps the
# table silent until a file exists. glinty's upload value is the
# same shape as Shiny's: a data.frame with name, size, type,
# datapath -- one row per file.
library(glinty)

app(
    ui = page(
        heading("Uploading Files", level = 1L),
        row(
            panel(variant = "sidebar", width = 300L,
                file_input("file1", "Choose CSV File", accept = ".csv"),
                divider(),
                checkbox_input("header", "Header", value = TRUE),
                radio_buttons("sep", "Separator",
                    choices = c(Comma = ",", Semicolon = ";", Tab = "\t"),
                    selected = ","),
                radio_buttons("quote", "Quote",
                    choices = c(None = "", `Double Quote` = "\"",
                        `Single Quote` = "'"),
                    selected = "\""),
                divider(),
                radio_buttons("disp", "Display",
                    choices = c(Head = "head", All = "all"),
                    selected = "head")),
            column(grow = 1L,
                table_output("contents")),
            align = "start"
        ),
        title = "Uploading Files"
    ),
    server = function(input, output, session) {
        output$contents <- render_table(function() {
            f <- req(input$file1())
            df <- utils::read.csv(f$datapath[[1L]],
                header = input$header(),
                sep = input$sep(),
                quote = input$quote())
            if (input$disp() == "head") utils::head(df) else df
        })
    }
)
