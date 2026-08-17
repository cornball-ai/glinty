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
| 001-hello | clean | OK live: plot renders, slider round trip | OK: measure->raster, slider->new raster, 0 errors | OK live via web build: plot + slider round trip | headless `--screenshot` can't see measured plots (Chrome virtual time never delivers the ws round trip) — not a glinty bug; in-process drive covers it |
| gallery Faithful | clean | OK live: dropdown, both checkboxes, density line, conditional bw slider reveal, bw drag reshapes | OK: all four controls change the raster, 0 errors | plot MISSING at first paint; appears (with conditional slider) after first input round trip — see finding 6 | conditional_panel works in both lowerings |

## Parity gaps found live (both frontends, same app, same server)

1. **Unthemed apps diverge completely.** welcome carries `theme` only
   when the app set one (protocol.R welcome_msg). Browser falls back
   to the stylesheet's stock tokens (blue on white, centered content
   column); Flutter falls back to the embedder's MaterialApp defaults
   (Material 3 purple, tinted surfaces). Same app, two products.
   Fix direction: GlintyApp/the renderer should carry glinty's stock
   tokens as its own fallback ThemeData — or welcome always sends the
   resolved theme, defaults included, one source of truth.
2. **Dart content page has no reading column.** Browser: centered
   max-width column with padding. Flutter: flush top-left, full
   width, no padding (page renders as a bare Column). Known from the
   #44 review; now confirmed side by side on 001-hello.

## More live findings (gallery Faithful, 2026-08-17)

4. **Sliders show no numbers, either lowering.** Shiny's slider
   displays its current value on the handle plus min/max labels;
   glinty's browser slider is a bare `<input type=range>` and the
   Flutter one a bare Material Slider (it does get division ticks
   from `step`). A user cannot tell what value they picked. Wants:
   current value readout (and probably min/max) as part of
   slider_input in both lowerings. (Troy called this out on sight.)
5. **Flutter drops boot-time outputs.** The server sends initial
   render output right after welcome; the dart client shows nothing
   until the first input round trip, after which the output (and its
   remeasure) appear. Repro: gallery-Faithful port, plot area empty
   at first paint, click any checkbox and everything appears. The
   browser's version of this is the welcome-time measure race
   (reportPlotDims called directly at welcome, once, no retry —
   works today only because layout beats the socket).
6. **Flutter checkbox is a full-width row with a trailing box** (and
   a hover/checked row highlight); the browser inlines box-then-label.
   Same tree, structurally different control.

## Fixed on this branch (worktree, pending PR)

- **Sliders show their numbers** in both lowerings: min / max flank
  the track, a client-tracked readout follows the thumb, and the
  browser gets native tick marks via a step-derived `datalist`
  (capped at 24), the twin of Flutter's division dots. Finding 4
  closed.
- **Flutter boot-blank root-caused and fixed.** session.dart
  measure() recorded its dedup key BEFORE handing the frame to the
  transport and ignored the result; a frame dropped mid-handshake
  poisoned the dedup, the plot never measured, and the first paint
  stayed empty until any input round trip. Server tracing
  (`options(glinty.trace = TRUE)`, added to run_app) proved the
  server always sends welcome + boot output. Fix: record only when
  the wire took the frame. 3/4 loads broke before; 0/4 after.
  Regression test: test/boot_output_probe_test.dart. Finding 5
  closed.
- **Parity pass** (findings 1, 2, 6 closed):
  - dart falls back to glinty's stock tokens (`glintyStockTheme`,
    mirroring theme_defaults() + DARK_COLOR_DEFAULTS) instead of
    Material purple when welcome carries no theme;
  - content pages render as the browser's reading column (centered,
    760 max, padded, page scrolls); `width = "full"` unchanged;
  - checkboxes are box-then-word at natural width (InkWell + Row),
    not a full-width CheckboxListTile.
- **Three-layer slider, matched to the ionRangeSlider reference**
  (superseding the first numbers pass, at Troy's direction): a value
  bubble riding the thumb, min/max chips at the ends that yield when
  the bubble reaches them, and a graded scale below the track --
  half-size minor ticks, numbered majors. When the step grid has
  1-20 stops the scale sits ON the stops (labels every stop up to
  10, every 2nd for 11-20, midpoint half-ticks up to 10), so tick
  marks align exactly with where the thumb can rest; otherwise a
  41-tick tenths grid with step-snapped, consecutive-deduped labels.
  One rule, three implementations that must agree: R slider_ticks()
  (lower_html.R), JS sliderTicks() (glinty.js), dart _sliderTicks()
  (render.dart). Verified live in Chrome against the running Shiny
  original.
- **CanvasKit checkbox box-clicks fizzled** -- label clicks sent the
  input, clicks on the box itself sent nothing (server trace showed
  no frame). Nested live tap targets (InkWell wrapping an enabled
  Checkbox) put box-taps into a gesture arena that resolved to
  neither. Fix: the box is display-only under IgnorePointer; the
  InkWell is the single tap path. Verified live: box-click drew the
  density curve and summoned the conditional slider.
- **A checked box paints primary + white check** -- proven at the
  raster level (test/checkbox_paint_probe_test.dart samples the
  painted pixels: fill exactly #2456d6). The grey glyph in earlier
  screenshots was capture mush: a 16px box through the extension's
  ~0.82x resample plus JPEG 4:2:0 chroma subsampling.
- **The app paints its own ground**: GlintyView wraps content in
  `Material(color: scaffoldBackgroundColor)` (Material, not
  ColoredBox -- list tiles and ink need a Material ancestor to
  paint on). Embedders must still hand it real constraints:
  a Scaffold body's loose constraints shrink-wrap the app and show
  the embedder's surface through every margin -- the viewer wraps
  in SizedBox.expand.
- Still open from the reconciliation ask: **font**. `system-ui` has
  no Flutter equivalent; the dart side keeps Roboto, and the native
  build takes the platform's fontconfig default. True parity means
  bundling one font in both frontends (Inter is the natural pick);
  candidate for a follow-up round.

## Round 3: Reactivity (shiny-examples 003, 2026-08-17)

Port went up clean on the first in-process run -- the emission graph
(dataset -> summary+view via one shared reactive; caption -> heading
only; obs -> table only) held exactly. Three framework gaps surfaced
by holding the frontends against the running original, all fixed on
this branch:

- **verbatim_output soft-wrapped** (`white-space: pre-wrap`),
  shattering summary()'s column alignment the moment content
  exceeded the box; the `overflow-x: auto` beneath it was dead code.
  Now `pre` + scroll; Flutter mirrors with softWrap: false in a
  horizontal scroller.
- **Tables had no numeric alignment**: values travel as strings, so
  the wire now carries `align` ("num"/"text" per column, from
  is.numeric before formatting) and both frontends right-align
  number columns. Shiny right-aligns via column class server-side;
  same idea, structural instead of markup.
- **The browser row wrapped; Flutter's cannot.** `flex-wrap: wrap`
  (from #8, no stated rationale) silently restacked the sidebar
  shape when content pressed, in one frontend only. Now nowrap +
  `min-width: 0` on row children (the horizontal twin of g-fill's
  min-height: 0) so inner scroll containers absorb the pressure.
  CHANGED A #8 DEFAULT -- flag in the PR for review.

Parity note, not yet a gap: Shiny's renderTable rounds (xtable
digits, shape shows 0.09) where render_table() sends full precision
(0.0903296). A digits/format control on render_table() would close
it; deferred.

## Framework DX finding

3. **A server function with the wrong argument order fails silently.**
   glinty's contract is Shiny's: `function(input, output[, session])`,
   dispatched positionally (run_app.R start_session). Declaring
   `function(session, input, output)` binds `output` to the session
   env, so `output$x <- render_*()` writes an inert field: no
   renderer, no observer, no error, welcome works, everything else is
   silence. Cost a full live-debug session to find. Cheap guard: when
   the server function's formals are NAMED input/output/session but
   in non-contract positions, stop with a clear error at run_app()
   time. Worth filing.

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
- The flutter-viewer web build carries no service worker
  (`--pwa-strategy=none`) and busybox httpd sends Last-Modified, so
  Chrome heuristically caches main.dart.js: after a rebuild, plain
  navigation shows the OLD build. Hard reload (or a fresh tab) after
  every rebuild, then confirm against the server trace log that a
  new welcome actually happened before judging behavior.
- A CDP zoom/device-metrics override sticks to the tab across
  reloads (dpr silently 2x, screenshots freeze or mislead). A fresh
  tab gets a clean CDP session; recreate rather than diagnose.
- For lossless pixels (JPEG screenshots smear a 16px glyph):
  `ffmpeg -f x11grab -i :1 -frames:v 1 out.png` for native windows;
  a RepaintBoundary.toImage() widget test for the flutter engine.
