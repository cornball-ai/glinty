library(glinty)

app(
    ui = page(
        heading("Input gallery", level = 1L),
        txt("Every widget wired to a live echo table, plus server-side updates."),
        row(
            text_input("txt", "Text:", value = "hello"),
            number_input("num", "Number:", value = 3, min = 0, max = 10)
        ),
        textarea_input("notes", "Notes:", rows = 3L),
        row(
            slider_input("sl", "Slider:", min = 0, max = 100, value = 50,
                step = 1),
            checkbox_input("chk", "Enabled", value = TRUE),
            align = "center"
        ),
        select_input("sel", "Choice:",
            choices = c(Alpha = "a", Bravo = "b", Charlie = "c")),
        radio_buttons("mode", "Mode:",
            choices = c(Fast = "fast", Careful = "careful")),
        date_input("when", "Date:", value = "2026-07-07"),
        file_input("upload", "File:", multiple = TRUE),
        button("randomize", "Randomize from server"),
        row(
            button("browse", "Browse folders on the server"),
            text_output("picked", variant = "mono"),
            align = "center", gap = 12L
        ),
        checkbox_input("more", "Show dynamic panel"),
        ui_output("panel"),
        heading(level = 3L, value = "Current values"),
        table_output("values"),
        title = "glinty gallery"
    ),
    server = function(input, output, session) {
        show <- function(v) paste(as.character(v), collapse = ", ")
        output$values <- render_table(function() {
            data.frame(
                input = c("txt", "notes", "num", "sl", "chk", "sel",
                    "mode", "when", "upload"),
                value = c(show(input$txt()), show(input$notes()),
                    show(input$num()), show(input$sl()),
                    show(input$chk()), show(input$sel()),
                    show(input$mode()), show(input$when()),
                    {
                        f <- input$upload()
                        if (is.null(f)) "" else {
                            paste(f$name, sprintf("(%d B)", f$size),
                                collapse = ", ")
                        }
                    }),
                stringsAsFactors = FALSE
            )
        })
        output$panel <- render_ui(function() {
            if (isTRUE(input$more())) {
                column(
                    heading(level = 4L, value = "Dynamic content"),
                    text_input("extra", "Appeared at runtime:"),
                    text_output("echo_extra")
                )
            } else {
                NULL
            }
        })
        output$echo_extra <- render_text(function() {
            v <- input$extra()
            if (is.null(v)) "" else paste("you typed:", v)
        })
        # The served file browser: a dialog built from ordinary
        # components, walking the server's own disk, with app-supplied
        # shortcuts above the tree.
        picker <- path_picker(session, input, "proj", kind = "dir",
                              shortcuts = c("this app's folder" = getwd()))
        observe_event(input$browse, function() picker$open())
        output$picked <- render_text(function() {
            v <- picker$value()
            if (is.null(v)) "nothing picked yet" else v
        })
        observe_event(input$randomize, function() {
            update_text_input(session, "txt",
                value = sample(c("corn", "ball", "glint"), 1L))
            update_slider_input(session, "sl", value = sample(0:100, 1L))
            update_number_input(session, "num", value = sample(0:10, 1L))
            update_checkbox_input(session, "chk", value = runif(1) > 0.5)
            update_select_input(session, "sel",
                selected = sample(c("a", "b", "c"), 1L))
            update_radio_buttons(session, "mode",
                selected = sample(c("fast", "careful"), 1L))
            update_date_input(session, "when",
                value = as.Date("2026-01-01") + sample(0:364, 1L))
        })
    }
)
