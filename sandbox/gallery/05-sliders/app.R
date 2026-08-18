# Port of shiny-examples 005-sliders: five sliders feeding one
# summary table through a shared reactive. The Range row is
# range_slider(), one input whose value is the pair c(lo, hi).
#
# Deliberately not ported, tracked in FINDINGS: the currency
# formatting on "Custom Format" (pre = "$", sep = ",") and the
# animate/animationOptions() play button on the last two -- glinty
# has no slider display-format or animation vocabulary yet, so both
# render as plain sliders.
library(glinty)

app(
    ui = page(
        heading("Sliders", level = 1L),
        row(
            panel(variant = "sidebar", width = 300L,
                slider_input("integer", "Integer:",
                    min = 0, max = 1000, value = 500),
                slider_input("decimal", "Decimal:",
                    min = 0, max = 1, value = 0.5, step = 0.1),
                range_slider("range", "Range:",
                    min = 1, max = 1000, value = c(200, 500)),
                slider_input("format", "Custom Format:",
                    min = 0, max = 10000, value = 0, step = 2500),
                slider_input("animation", "Looping Animation:",
                    min = 1, max = 2000, value = 1, step = 10)),
            column(grow = 1L,
                table_output("values")),
            align = "start"
        ),
        title = "Sliders"
    ),
    server = function(input, output, session) {
        slider_values <- reactive(function() {
            data.frame(
                Name = c("Integer", "Decimal", "Range", "Custom Format",
                    "Animation"),
                Value = as.character(c(input$integer(), input$decimal(),
                    paste(input$range(), collapse = " "),
                    input$format(), input$animation())),
                stringsAsFactors = FALSE)
        })
        output$values <- render_table(function() slider_values())
    }
)
