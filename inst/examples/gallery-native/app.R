library(glinty)

# The gallery trimmed to the native-parity widget set: run with
# run_app_native() for a window, or run_app() for a browser -- same
# app either way.
app(
    ui = page(
        h1("Native parity gallery"),
        p("Same app, browser or native window."),
        row(
            text_input("txt", "Text:", value = "hello"),
            number_input("num", "Number:", value = 3, min = 0, max = 10)
        ),
        textarea_input("notes", "Notes:", rows = 3L),
        row(
            select_input("sel", "Choice:",
                choices = c(Alpha = "a", Bravo = "b", Charlie = "c")),
            checkbox_input("chk", "Enabled", value = TRUE)
        ),
        slider_input("sl", "Slider:", min = 0, max = 100, value = 50,
            step = 1),
        button("randomize", "Randomize from server"),
        h3("Current values"),
        table_output("values"),
        title = "glinty native parity"
    ),
    server = function(input, output, session) {
        show <- function(v) paste(as.character(v), collapse = ", ")
        output$values <- render_table(function() {
            data.frame(
                input = c("txt", "num", "notes", "sel", "chk", "sl"),
                value = c(show(input$txt()), show(input$num()),
                    show(input$notes()), show(input$sel()),
                    show(input$chk()), show(input$sl())),
                stringsAsFactors = FALSE
            )
        })
        observe_event(input$randomize, function() {
            update_text_input(session, "txt",
                value = sample(c("corn", "ball", "glint"), 1L))
            update_slider_input(session, "sl", value = sample(0:100, 1L))
            update_select_input(session, "sel",
                selected = sample(c("a", "b", "c"), 1L))
        })
    }
)
