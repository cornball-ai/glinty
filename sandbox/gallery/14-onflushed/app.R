# Port of shiny-examples 014-onflushed: the deferred-expensive-render
# pattern. Fast outputs paint immediately; the slow ones render a
# placeholder first and start the real work only after the placeholder
# has reached the client -- session$on_flushed(), the round-14
# vocabulary add, fires once after the next completed flush.
#
# One deliberate simplification vs the original: no invalidateLater(0)
# inside the renders. Flipping the reactive_val in on_flushed already
# invalidates every render that read it, and the event loop spins
# immediately after firing callbacks, so the extra self-invalidation
# Shiny's 2013 example carries is dead weight here.
library(glinty)

app(
    ui = page(
        heading("Immediate output here", level = 2L),
        verbatim_output("fast"),
        heading("Delayed output comes after the page is ready",
            level = 2L),
        verbatim_output("slow"),
        plot_output("slow_plot", height = 400L),
        title = "onFlushed"
    ),
    server = function(input, output, session) {
        starting <- reactive_val(TRUE)
        session$on_flushed(function() starting(FALSE))

        output$fast <- render_text(function() "This happens right away")
        output$slow <- render_text(function() {
            if (starting()) {
                return("Please wait for 5 seconds")
            }
            Sys.sleep(5) # pretend this is time-consuming
            "This happens later"
        })
        output$slow_plot <- render_plot(function() {
            if (starting()) {
                plot(datasets::cars, main = "Please wait for a while")
            } else {
                plot(stats::rnorm(100000), main = "A slow plot")
            }
        })
    }
)
