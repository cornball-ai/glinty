library(glinty)

app(
    ui = page(
        heading("Counter", level = 1L),
        txt("Each browser tab gets its own session-scoped count."),
        button("inc", "+1"),
        button("reset", "Reset"),
        text_output("count"),
        title = "glinty counter"
    ),
    server = function(input, output) {
        count <- reactive_val(0L)
        observe_event(input$inc, function() count(isolate(count()) + 1L))
        observe_event(input$reset, function() count(0L))
        output$count <- render_text(function() count())
    }
)
