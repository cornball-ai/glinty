# glinty

Tiny reactive web application framework for R. A glint is a small
shine.

glinty gives you the Shiny mental model (inputs, outputs, reactive
expressions, observers, a UI built in R) with a tinyverse footprint:

- **2 dependencies**: jsonlite and digest. No httpuv, no R6, no
  htmltools, no later/promises. Shiny pulls ~35 recursive packages;
  glinty pulls 2.
- **Pure base R transport**: the HTTP server and the RFC 6455
  WebSocket layer run on `serverSocket()`/`socketSelect()`. No
  compiled code in the package.
- **~7 KB of hand-written JavaScript**, no jQuery, no Bootstrap.
  Shiny's `www/` tree is 6.9 MB; glinty's is under 12 KB.
- **Session-scoped state**: every browser tab gets its own inputs,
  outputs, and observers, torn down on disconnect.

## Install

```r
remotes::install_github("cornball-ai/glinty")
```

## A complete app

```r
library(glinty)

counter <- app(
    ui = page(
        h1("Counter"),
        button("inc", "+1"),
        text_output("count"),
        title = "Counter"
    ),
    server = function(input, output) {
        count <- reactive_val(0L)
        observe_event(input$inc, function() count(isolate(count()) + 1L))
        output$count <- render_text(function() count())
    }
)

run_app(counter, port = 8080)
```

Bundled demos: `run_example("counter")`, `run_example("gallery")`,
`run_example("clock")`.

## Coming from Shiny

The concepts map 1:1. The mechanical difference: glinty passes plain
functions where Shiny quotes expressions, and inputs are read by
calling them (`input$x()` instead of `input$x`).

| Shiny | glinty |
|---|---|
| `reactiveVal(0)` | `reactive_val(0)` |
| `reactive({ x() * 2 })` | `reactive(function() x() * 2)` |
| `observe({ ... })` | `observe(function() ...)` |
| `observeEvent(input$go, { ... })` | `observe_event(input$go, function() ...)` |
| `isolate(x())` | `isolate(x())` |
| `req(input$f)` | `req(input$f())` |
| `invalidateLater(1000)` | `invalidate_later(1000)` |
| `input$x` | `input$x()` |
| `output$y <- renderText({ ... })` | `output$y <- render_text(function() ...)` |
| `renderUI` / `uiOutput` | `render_ui()` / `ui_output()` |
| `htmlOutput` | `html_output()` (browser-only escape hatch) |
| `verbatimTextOutput` | `verbatim_output()` |
| `passwordInput` | `password_input()` |
| `conditionalPanel("input.x == 'a'")` | `conditional_panel(condition = input_is("x", "a"))` |
| `navset_tab` / `nav_panel` | `tabset()` / `tab_panel()` |
| `showModal(modalDialog(...))` | `show_modal(session, ...)` |
| `withProgress` / `incProgress` | `with_progress()` / `inc_progress()` |
| `downloadButton` / `downloadHandler` | `download_button()` / `download_handler()` |
| `session$sendCustomMessage` | `send_custom_message()` |
| `Shiny.setInputValue` | `Glinty.setInputValue` |
| `renderTable` | `render_table()` (data.frame in, escaped table out) |
| `renderPlot` | `render_plot()` (base graphics, fixed size) |
| `textInput("x", "Label")` | `text_input("x", "Label")` |
| `actionButton("go", "Go")` | `button("go", "Go")` |
| `selectInput` / `sliderInput` / `checkboxInput` / `numericInput` | `select_input` / `slider_input` / `checkbox_input` / `number_input` |
| `radioButtons` / `dateInput` / `fileInput` | `radio_buttons` / `date_input` / `file_input` |
| `updateTextInput(session, ...)` | `update_text_input(session, ...)` |
| `fluidPage(...)` | `page(...)` |
| `shinyApp(ui, server)` | `app(ui, server)` |
| `runApp(x, port)` | `run_app(x, port)` |

The server function takes `(input, output)` or
`(input, output, session)`; the session argument is what the
`update_*_input()` family needs.

## How it works

The initial page is rendered server-side from the `page()` tag tree.
The browser then opens a WebSocket; input events flow up as small
JSON messages, and DOM patches flow down. Reactive dependency
tracking (contexts, a flush queue, lazy cached reactives) re-runs
only what changed. One R process serves N tabs from a
`socketSelect()` event loop; `invalidate_later()` timers wake it for
clocks and polling.

Custom widgets need no JavaScript: any element with an `id`, a
`data-g-event`, and a `data-g-target` is an input, so a widget is
just an R function returning `tag()` trees. See `?tag`.

## Native windows (flitR backend)

With the flitR package installed (plus its engine via
`flitR::install_engine()`), `run_app_native(app_obj)` renders the
same app in a native window through the Flutter Engine. The native
window is just another client of glinty's wire protocol: reactive
core, sessions, and renderers are identical, and `render_plot()`
draws natively through flitR's image op.

The supported widget set covers text, headings, `text_input`,
`password_input`, `textarea_input`, `number_input`, `select_input`,
`button`, `checkbox_input`, `slider_input`, `text_output`,
`verbatim_output`, `table_output` (drawn as a native grid),
`plot_output`, `tabset` and `conditional_panel`.

Two of those need a word:

`conditional_panel()`'s condition is evaluated server-side against the
same inputs the browser would use, so both frontends agree on what
shows.

`tabset()` draws its nav strip and emits **only the selected panel**.
That is the immediate-mode reading of a tab: an unselected panel is
not hidden, it is simply not drawn this frame. So unlike the browser,
inputs inside an unselected tab do not keep their values natively.
A tabset needs an `id` to work natively, since that input is where
the selection lives.

`password_input()` masks with bullets via flitR, and the real string
never leaves R: flitR's `scene()` strips the hit records that carry it
before anything goes over the wire.

Everything else is browser-only and **fails fast with a named list**
rather than rendering something wrong: `radio_buttons`, `date_input`,
`file_input`, `html_output`, `audio_output`, `download_button`,
`modal_button`. Modals, progress bars and `send_custom_message()` are
silently inert natively, since they have no native counterpart to get
wrong.

Native sessions seed inputs from widget defaults, mirroring the
browser's init harvest. Don't `library(flitR)` alongside glinty (both
export `app`, `text`, and friends); `run_app_native()` only needs it
installed.

Layout carries across frontends too: `row(...)` and `column(...)`
map to flexbox in the browser and flitR's row/column natively (note
`row()` masks `base::row()` when glinty is attached).

## Resilience

A dropped connection detaches its session instead of killing it:
observers and timers stay warm for `getOption("glinty.resume_grace",
60)` seconds while the client retries with backoff, then resumes
with state intact. Expired sessions get an honest reload.

## Limits (by design)

- Single-threaded: one slow computation stalls all sessions (same
  process model as one Shiny worker, minus the async escape hatches).
- No bookmarking, no modules yet.
- `serverSocket()` binds all interfaces; treat the port as reachable
  from your local network, and the session id as a weak resume
  credential within the grace window.

## Provenance

The reactive core and tag DSL grew out of browseR, a webR experiment;
glinty generalizes them behind a session layer and a WebSocket
transport.
