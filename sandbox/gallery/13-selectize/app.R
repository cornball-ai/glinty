# Port of shiny-examples 013-selectize: the selectize.js feature
# tour. Ported unfaithfully on purpose -- selectize is a JS library
# and half its demo is raw-JS configuration, which is the escape
# hatch glinty's vocabulary exists to remove. What ports:
#
#   e0 ordinary select          -> select_input()
#   e1 zero-config selectize    -> select_input(search = TRUE)
#   e2 multi-select             -> select_input(multiple = TRUE)
#   e5 multi with maxItems = 2  -> multiple, cap noted as not taken
#
# Not taken, by design: e3 item creation (free text widens the
# closed choice domain), e4 maxOptions (display knob), e6 raw-JS
# placeholder/onInitialize, e7 (a Shiny-internal quirk), and the
# whole GitHub remote-search block (custom JS render/score/load
# against a remote API). Server-driven choices already have their
# own seam: update_select_input().
library(glinty)

states <- datasets::state.name

app(
    ui = page(
        heading("Selectize examples", level = 1L),
        row(
            panel(variant = "sidebar", width = 340L,
                select_input("e0", "0. An ordinary select input",
                    choices = states),
                select_input("e1", "1. A searchable select (combobox)",
                    choices = states, search = TRUE),
                select_input("e2", "2. Multi-select",
                    choices = states, multiple = TRUE),
                select_input("e5", "5. Multi-select (selectize caps at 2; no cap here)",
                    choices = states, multiple = TRUE)),
            column(grow = 1L,
                txt("Output of the examples in the left:",
                    variant = "muted"),
                verbatim_output("ex_out")),
            align = "start"
        ),
        title = "Selectize examples"
    ),
    server = function(input, output, session) {
        output$ex_out <- render_text(function() {
            vals <- list(e0 = input$e0(), e1 = input$e1(),
                         e2 = input$e2(), e5 = input$e5())
            paste(utils::capture.output(utils::str(vals)),
                  collapse = "\n")
        })
    }
)
