# Port of shiny-examples 011-timer: a clock. invalidate_later()
# re-arms the render every second, so the output ticks with no
# input anywhere in the app. The h2(textOutput(...)) shape is
# text_output(variant = "heading") again.
library(glinty)

app(
    ui = page(
        text_output("current_time", variant = "heading"),
        title = "Timer"
    ),
    server = function(input, output, session) {
        output$current_time <- render_text(function() {
            invalidate_later(1000, session)
            paste("The current time is", format(Sys.time()))
        })
    }
)
