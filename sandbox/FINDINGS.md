# Gallery loop findings

Porting the Shiny gallery (rstudio/shiny-examples, MIT; shiny core is
MIT too) into glinty's closed vocabulary, one app at a time. Each port
gets: a web serve + headless screenshot (layout), an in-process
protocol drive via `tools/drive.R` (reactive/render correctness), and
a Flutter renderer pump of the serialized tree (layout errors the
browser can't see, per #53).

## Loop verdicts

| App | Port | Web | In-process | Flutter | Notes |
|---|---|---|---|---|---|
| 001-hello (faithful) | clean | layout OK | OK: measure->raster, slider->new raster, 0 errors | pending | headless `--screenshot` can't see measured plots (Chrome virtual time never delivers the ws round trip) — not a glinty bug; in-process drive covers it |

## API gap table (data-driven)

Frequency = calls across all shiny-examples apps (grep sweep,
2026-08-17). Everything above the line is covered by existing glinty
vocabulary; below are the real gaps, ranked.

Covered: fluidPage/titlePanel/sidebarLayout/wellPanel (page, heading,
row, panel variants), verbatimTextOutput+renderPrint (96+91),
plotOutput+renderPlot (83+73), reactive (79), selectInput (74),
actionButton (68), renderText (64), sliderInput single-value (58),
observeEvent (51), tabPanel/tabsetPanel (46+9), renderUI/uiOutput
(33+30), numericInput (27), renderTable/tableOutput (26+19),
textInput (25), isolate (25), checkboxInput (25), observe (24),
conditionalPanel (18), invalidateLater (15), all update_* twins,
fileInput (6), downloadHandler/Button (10+7), dateInput (9),
showModal (5), withProgress (5), renderImage/imageOutput (11+4),
radioButtons, textAreaInput (3), passwordInput -> see gaps.

### Gaps, by app-demand

1. **slider range mode** — sliderInput(value = c(lo, hi)) two-handle;
   005-sliders demos it. Single-value covered. Also shiny has
   animate; skip animate, range is the gap.
2. **interactive table** — renderDataTable/dataTableOutput/DT
   (20+16+2): sort/filter/paginate. glinty table is static. Biggest
   strategic gap; whole "DataTables" demos rest on it.
3. **selectize-style select** — selectizeInput (16) + update (10):
   searchable dropdown, server-side choices, multi/tags. A
   `search = TRUE` flag on select_input covers most uses.
4. **plot interaction** — brushedPoints (14) + nearPoints (9): click/
   brush/hover on plot_output reported to the server. Protocol-level
   (new input frames). Gates the whole "Interactive Plots" section.
5. **checkbox group** — checkboxGroupInput (12) + update (4). Clear,
   small vocabulary gap.
6. **date range** — dateRangeInput (8). Small gap.
7. **navbar page-level nav** — navbarPage (5) + navlistPanel:
   top-level chrome vs tabset-in-page. Medium layout gap.
8. **notifications** — showNotification (4): transient toasts.
   Protocol message + a stacked corner UI.
9. **password input** — passwordInput (4): text_input type variant,
   trivial.
10. **reactiveValues bag** (9) — convenience only; reactive_val
    covers. Low.
11. **bookmarking** — bookmarkButton (4), URL state. Big feature,
    later.

### Deliberate non-gaps

- htmlwidgets ecosystem (leaflet 5, plotly 3, DT 2, sankey,
  dashboardPage/valueBox): third-party JS widget embeds are outside
  the closed vocabulary by design. The answer where it matters is
  first-party components (plot interaction covers common plotly
  uses); note as ecosystem boundary, not fixable gaps.
- renderCachedPlot (11): perf, not vocabulary.
- insertUI/removeUI (2+2): render_ui covers the shape.
- submitButton (1): legacy shiny, skip.
- helpText: txt(variant = "muted") covers.

## Infrastructure notes

- Headless Chrome `--screenshot --virtual-time-budget` never completes
  the ws measure/render round trip: fine for static layout shots,
  blind to plots. In-process driver is the source of truth for
  dynamic behavior; real-Chrome extension when available for full
  visual passes.
- `tools/drive.R` boots an app exactly like the live loop
  (seed_session_inputs -> server fn -> flush) and scripts
  measure/input/event frames against it.
