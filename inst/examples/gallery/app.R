library(glinty)

app(
    ui = page(
        h1("Input gallery"),
        p("Every widget wired to a live echo table, plus server-side updates."),
        text_input("txt", "Text:", value = "hello"),
        textarea_input("notes", "Notes:", rows = 3L),
        number_input("num", "Number:", value = 3, min = 0, max = 10),
        slider_input("sl", "Slider:", min = 0, max = 100, value = 50,
            step = 1),
        checkbox_input("chk", "Enabled", value = TRUE),
        select_input("sel", "Choice:",
            choices = c(Alpha = "a", Bravo = "b", Charlie = "c")),
        button("randomize", "Randomize from server"),
        h3("Current values"),
        table_output("values"),
        title = "glinty gallery"
    ),
    server = function(input, output, session) {
        show <- function(v) paste(as.character(v), collapse = ", ")
        output$values <- render_table(function() {
            data.frame(
                input = c("txt", "notes", "num", "sl", "chk", "sel"),
                value = c(show(input$txt()), show(input$notes()),
                    show(input$num()), show(input$sl()),
                    show(input$chk()), show(input$sel())),
                stringsAsFactors = FALSE
            )
        })
        observe_event(input$randomize, function() {
            update_text_input(session, "txt",
                value = sample(c("corn", "ball", "glint"), 1L))
            update_slider_input(session, "sl", value = sample(0:100, 1L))
            update_number_input(session, "num", value = sample(0:10, 1L))
            update_checkbox_input(session, "chk", value = runif(1) > 0.5)
            update_select_input(session, "sel",
                selected = sample(c("a", "b", "c"), 1L))
        })
    }
)
