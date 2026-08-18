# Port of shiny-examples 008-html -- deliberately unfaithful in the
# one way that matters. The original's point is htmlTemplate(): the
# UI is a hand-written index.html wearing shiny CSS classes. glinty
# rejects page-level raw HTML by design (closed vocabulary, so any
# app can flow to any frontend), so this port expresses the same app
# in vocabulary and FINDINGS records the boundary. The functionality
# is 03-reactivity's shape in the original's plain vertical layout.
library(glinty)

app(
    ui = page(
        heading("HTML UI", level = 1L),
        select_input("dist", "Distribution type:",
            choices = c(Normal = "norm", Uniform = "unif",
                `Log-normal` = "lnorm", Exponential = "exp")),
        number_input("n", "Number of observations:",
            value = 500, min = 1, max = 1000),
        heading("Summary of data:", level = 3L),
        verbatim_output("summary"),
        heading("Plot of data:", level = 3L),
        plot_output("plot", height = 300),
        heading("Head of data:", level = 3L),
        table_output("table"),
        title = "HTML UI"
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
            utils::head(data.frame(x = d()))
        })
    }
)
