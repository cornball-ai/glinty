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
| `renderUI` / `htmlOutput` | `render_html()` / `html_output()` |
| `renderTable` | `render_table()` (data.frame in, escaped table out) |
| `renderPlot` | `render_plot()` (base graphics, fixed size) |
| `textInput("x", "Label")` | `text_input("x", "Label")` |
| `actionButton("go", "Go")` | `button("go", "Go")` |
| `selectInput` / `sliderInput` / `checkboxInput` / `numericInput` | `select_input` / `slider_input` / `checkbox_input` / `number_input` |
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

## Limits (v0.1, by design)

- Single-threaded: one slow computation stalls all sessions (same
  process model as one Shiny worker, minus the async escape hatches).
- A dropped connection is a fresh session; the client shows a reload
  overlay instead of pretending to resume.
- `render_plot()` is fixed-size, no client-side resizing.
- No file upload, no bookmarking, no modules yet.
- `serverSocket()` binds all interfaces; treat the port as reachable
  from your local network.

## Provenance

The reactive core and tag DSL grew out of browseR, a webR experiment;
glinty generalizes them behind a session layer and a WebSocket
transport.
