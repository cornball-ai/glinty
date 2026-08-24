# Port of shiny-examples 022-unicode-chinese: UTF-8 through the
# whole pipeline. Chinese travels as the page title, labels, choice
# VALUES (the conditional panel keys on 岩石), factor data in a
# table, plot axis names -- and one output id is itself Chinese,
# which the original demos on purpose (output$summary这里也可以用中文).
#
# Skipped from the original: the ShinyApps font-download dance in
# global.R (this host has Noto CJK) and the Cairo workaround
# (options(shiny.usecairo)) -- glinty's render_plot uses grDevices
# png(type = "cairo") or the default; if 汉字 render in the plot,
# the device story is fine, which is part of what this round tests.
library(glinty)

rock2 <- datasets::rock
names(rock2) <- c("面积", "周长", "形状",
                  "渗透性")
cars2 <- datasets::cars
cars2$random <- sample(
    strsplit("随意放一些中文字符",
             "")[[1]],
    nrow(cars2), replace = TRUE
)

rock_name <- "岩石"
summary_id <- paste0("summary",
                     "这里也可以用中文")

app(
    ui = page(
        heading(paste0("麻麻再也不用担",
                       "心我的Shiny应用不",
                       "能显示中文了"),
            level = 1L),
        row(
            panel(variant = "sidebar", width = 300L,
                select_input("dataset",
                    "请选一个数据：",
                    choices = c(rock_name, "pressure", "cars")),
                ui_output("rockvars"),
                number_input("obs",
                    paste0("查看多少行",
                           "数据？"),
                    value = 5),
                checkbox_input("summary",
                    "显示概要", value = TRUE)),
            column(grow = 1L,
                conditional_panel(
                    plot_output("rockplot", height = 300L),
                    condition = input_is("dataset", rock_name)),
                verbatim_output(summary_id),
                table_output("view")),
            align = "start"
        ),
        title = "Unicode 中文"
    ),
    server = function(input, output, session) {
        dataset_input <- reactive(function() {
            switch(input$dataset(),
                pressure = datasets::pressure,
                cars = cars2,
                rock2
            )
        })
        output$rockvars <- render_ui(function() {
            if (input$dataset() != rock_name) {
                return(NULL)
            }
            select_input("vars",
                paste0("从岩石数据中选",
                       "择一列作为自变",
                       "量"),
                choices = names(rock2)[-1])
        })
        output$rockplot <- render_plot(function() {
            req(input$vars())
            par(mar = c(4, 4, .1, .1))
            plot(as.formula(paste(names(rock2)[1], "~",
                                  input$vars())),
                 data = rock2)
        })
        output[[summary_id]] <- render_text(function() {
            if (!input$summary()) {
                return(paste0("数据概要信息",
                              "被隐藏了！"))
            }
            paste(utils::capture.output(summary(dataset_input())),
                  collapse = "\n")
        })
        output$view <- render_table(function() {
            utils::head(dataset_input(), n = input$obs())
        })
    }
)
