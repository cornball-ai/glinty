# Port of shiny-examples 006-tabsets: the random distribution app.
# Radio buttons pick the generator, a continuous slider the sample
# size, and one shared reactive feeds a Plot / Summary / Table
# tabset -- the plot must survive living in a sometimes-hidden tab.
# Shiny's renderTable(vector) coerces; render_table() wants a
# data.frame, so the port wraps the sample itself.
library(glinty)

app(
    ui = page(
        heading("Tabsets", level = 1L),
        row(
            panel(variant = "sidebar", width = 280L,
                radio_buttons("dist", "Distribution type:",
                    choices = c(Normal = "norm", Uniform = "unif",
                        `Log-normal` = "lnorm", Exponential = "exp")),
                spacer(1L),
                slider_input("n", "Number of observations:",
                    min = 1, max = 1000, value = 500)),
            column(grow = 1L,
                tabset(id = "view",
                    tab_panel("Plot", plot_output("plot", height = 300)),
                    tab_panel("Summary", verbatim_output("summary")),
                    tab_panel("Table", table_output("table")))),
            align = "start"
        ),
        title = "Tabsets"
    ),
    server = function(input, output, session) {
        d <- reactive(function() {
            gen <- switch(input$dist(),
                norm = stats::rnorm,
                unif = stats::runif,
                lnorm = stats::rlnorm,
                exp = stats::rexp,
                stats::rnorm)
            gen(input$n())
        })
        output$plot <- render_plot(function() {
            hist(d(),
                main = paste0("r", input$dist(), "(", input$n(), ")"),
                col = "#75AADB", border = "white")
        })
        output$summary <- render_text(function() {
            paste(utils::capture.output(summary(d())), collapse = "\n")
        })
        output$table <- render_table(function() {
            data.frame(x = d())
        })
    }
)
