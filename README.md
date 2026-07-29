# glinty

**Status: alpha.** Pre-0.1: the version is `0.0.x`, `0.1.0` is what
the plan targets, and nothing here is stable. The API moves, the wire
protocol moved recently, and there is no deprecation cycle yet. A few
`0.0.x` releases exist on GitHub; none is on CRAN. Use it if you find
it interesting; do not build something you need on it yet.

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
- **~48 KB of hand-written JavaScript**, no jQuery, no Bootstrap.
  Shiny's `www/` tree is 6.9 MB; glinty's is under 60 KB.
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
        heading("Counter", level = 1L),
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

The initial page is rendered server-side from the `page()` component
tree. The browser then opens a WebSocket; input events flow up as
small JSON messages, and typed output values flow down -- text,
tables, images, component trees -- for the client to display however
it displays them. Reactive dependency
tracking (contexts, a flush queue, lazy cached reactives) re-runs
only what changed. One R process serves N tabs from a
`socketSelect()` event loop; `invalidate_later()` timers wake it for
clocks and polling.

Layout is `row()` and `column()`, which map to flexbox in the browser
and to Flutter's `Row`/`Column` (note `row()` masks `base::row()`
when glinty is attached).

Custom widgets are R functions returning component trees, so they
work on every frontend without JavaScript. `tag()` remains for
browser-only markup, and is trusted HTML: see `?tag` before putting
anything into it that you did not write.

Styling that should survive the trip to a non-browser frontend goes
through `app(theme = app_theme(...))`: a closed set of semantic
tokens (colors, spacing, radius, fonts) that the browser applies as
CSS custom properties and Flutter maps onto `ThemeData`. Without a
theme you get each frontend's defaults, including the browser's
automatic dark mode. App stylesheets still work, and only affect the
browser.

## A second frontend (Flutter)

Write a glinty app much like a conventional Shiny app. It runs in
the browser, and if it sticks to glinty's portable components and
typed renderers, most of the work a native app needs is already
done: the same R server and application logic drive a Flutter
interface, and the native-specific remainder is branding,
permissions, packaging and signing.

`tag()`, `html_output()`, custom JavaScript and browser-only CSS are
escape hatches, and escape hatches don't travel. R stays on the
server; it is not bundled into the native app.

The Flutter transport is live: `GlintyApp` opens the socket, sends
`hello`, hydrates from `welcome`, reconnects with `resume` under
bounded backoff, and refuses visibly when the server says no. It
draws dialogs and progress reports, reports output boxes for
client-sized plots, and redeems transfer tickets. Downloads, links
and `custom` messages need an embedder callback, because saving a
file, opening a URL and knowing what an app's own message means are
all things this package cannot do on its own -- so it declares those
features only when one is wired, and names the gap on screen rather
than dropping the frame. There is no project scaffolder yet.

The wire carries semantic components, not DOM instructions, which is
what makes that swap possible. `dart/glinty_flutter` reads the same
component trees the browser does and lowers them to Flutter widgets,
which covers iOS, Android, desktop and web from the same R app.

Both clients read two generated files as their contract:
`inst/fixtures/components.json` (every component, once) and
`inst/fixtures/transcripts.json` (the frames of an exchange, in
order). Tests on each side assert the files match the R definitions
they came from, so a component only counts as frontend-neutral once
it has rendered in both.

A component the Flutter client cannot draw yet gets a visible
placeholder naming it, rather than being silently dropped. `tag()`
produces `raw_html`, which is browser-only by design: arbitrary
markup has no widget equivalent.

See `PROTOCOL.md` for the spec. The flitR native backend that used to
live here is retired; flitR is archived.

## Resilience

A dropped connection detaches its session instead of killing it:
observers and timers stay warm for `getOption("glinty.resume_grace",
60)` seconds while the client retries with backoff, then resumes
with state intact. Expired sessions get an honest reload.

## Authentication and deployment

`run_app(auth = )` takes a verifier for the opaque token a client
sends when it connects: NULL refuses the connection, anything else
becomes `session$principal`. `jwt_auth()` covers the JWT case in one
line (HS256 built in; RS256 with the openssl package). Uploads and
downloads ride short-lived single-use tickets minted over the
WebSocket, so no session credential ever appears in a URL. `GET
/healthz` reports sessions and uptime for supervisors, and
`run_app()` reads `GLINTY_PORT`/`PORT` from the environment when no
port is given.

## Limits (by design)

- Single-threaded: one slow computation stalls all sessions (same
  process model as one Shiny worker, minus the async escape hatches).
- No bookmarking, no modules yet.
- `serverSocket()` binds all interfaces -- base R sockets cannot bind
  selectively or terminate TLS. Gate sessions with `auth =`, and
  scope the port with a firewall, container namespace, or reverse
  proxy; startup says this out loud.
- The session id remains a weak resume credential within the
  reconnect grace window (auth is re-verified on resume when
  configured).

## Provenance

The reactive core and tag DSL grew out of browseR, a webR experiment;
glinty generalizes them behind a session layer and a WebSocket
transport.
