# Port of shiny-examples 012-datatables: three datasets behind a
# tabset, each in an interactive table. The sidebar changes with the
# tab via conditional panels keyed on the tabset's own input -- in
# Shiny a JS expression string, here input_is() on the tab title.
# The diamonds tab's column picker is a checkbox_group whose plural
# value subsets the data.frame server-side; sorting, filtering and
# paging never leave the client.
#
# Ported unfaithfully where DT is cosmetic: orderClasses (tinting
# the sorted column) has no glinty equivalent, and row-number
# "rownames" columns are dropped. mtcars keeps its model names by
# making them a real column, which render_table would otherwise
# discard.
library(glinty)

set.seed(42) # the original samples fresh per launch; fixed here so
             # restarts show the same 1000 diamonds
diamonds2 <- as.data.frame(ggplot2::diamonds)
diamonds2 <- diamonds2[sample(nrow(diamonds2), 1000L), ]
mtcars2 <- data.frame(model = rownames(datasets::mtcars),
                      datasets::mtcars)

app(
    ui = page(
        heading("Examples of DataTables", level = 1L),
        row(
            panel(variant = "sidebar", width = 280L,
                conditional_panel(
                    checkbox_group("show_vars",
                        "Columns in diamonds to show:",
                        choices = names(diamonds2),
                        selected = names(diamonds2)),
                    condition = input_is("dataset", "diamonds")),
                conditional_panel(
                    txt("Click a column header to sort.",
                        variant = "muted"),
                    condition = input_is("dataset", "mtcars")),
                conditional_panel(
                    txt("Displays 5 records by default.",
                        variant = "muted"),
                    condition = input_is("dataset", "iris"))),
            column(grow = 1L,
                tabset(id = "dataset",
                    tab_panel("diamonds", data_table("mytable1")),
                    tab_panel("mtcars", data_table("mytable2")),
                    tab_panel("iris", data_table("mytable3",
                        page_length = 5L,
                        length_menu = c(5, 30, 50))))),
            align = "start"
        ),
        title = "Examples of DataTables"
    ),
    server = function(input, output, session) {
        output$mytable1 <- render_table(function() {
            cols <- as.character(unlist(input$show_vars()))
            diamonds2[, cols, drop = FALSE]
        })
        output$mytable2 <- render_table(function() mtcars2)
        output$mytable3 <- render_table(function() datasets::iris)
    }
)
