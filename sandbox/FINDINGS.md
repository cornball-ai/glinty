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

## Round 4: Tabsets (shiny-examples 006, 2026-08-17)

Radio buttons, a continuous 1..1000 slider, and a Plot / Summary /
Table tabset over one shared reactive. In-process check pins the
emission graph and that a tab switch is an input, not a re-render.
Framework yield, all fixed on this branch:

- **The 41-tick scale mushed on a narrow track**: 11 labels in
  ~230px is unreadable. The label budget is now width-aware
  (floor(width / 70), floor 2): R emits the width-blind default and
  each client rebuilds to its measured budget; thinned positions
  keep their tick at minor size, the last stop is always labeled
  and a regular label within one gap of it yields. Same rule in R /
  JS / dart (the step-grid form of the rule reproduces the old
  every-stop / every-2nd behavior at the default budget).
- **Two sync gaps for server-rendered scales**: nothing rebuilt them
  at hydration (width unknown server-side), and nothing rebuilt a
  slider revealed by a conditional panel or a tab switch (measured
  0 while hidden). welcome, refreshConditionals and activateTab now
  run syncSliderLabels over the affected range inputs.
- **Stepless labels showed float noise** (300.7 where the Shiny
  reference shows integers). Cribbed the actual rule from the
  clone: shiny's findStepSize (R/input-slider.R) derives step 1 for
  integer ends spanning >= 2, else a pretty ~range/100 decimal, and
  ionRangeSlider rounds grid values to the step's precision. glinty
  now derives the same implied step when step is absent and snaps
  scale labels to it: 1..1000 reads 1, 301, 600, 1000. Pinned in
  test_slider_scale.R.
- **Flutter clipped tab content at a hardcoded 200px** TabBarView.
  Now an IndexedStack synced to the TabController: the set sizes to
  its largest panel, every panel stays alive (the browser keeps
  hidden tab bodies in the DOM the same way), a 300px plot in a tab
  keeps its height. No swipe, matching the browser.

- **A stepless slider dragged in floats on flutter** (Troy: "you
  can't have 394.326 samples"). The implied step now materializes
  as the drag granularity everywhere: the HTML step attribute in
  both the R lowering and the JS builder (which also fixes a 0..1
  stepless slider having two positions from the browser's default
  step of 1), and _sliderQuantize on every emitted flutter value.
  A drag test pins whole-number emission for 1..1000.
- **Flutter's slider layers only aligned with the thumb at the
  midpoint** (Troy caught it live): Material insets the track by
  max(overlay, thumb)/2 = 24 per side, while bubble and scale
  positioned at f * width. A paint probe measured the true inset
  (slider_geometry_probe_test, kept as a regression net); bubble
  and scale now map through trackInset + f * (width - 2*inset), the
  track's own coordinate space. The full-bleed alternative
  (SliderThemeData.padding: zero) stopped painting the inactive
  track half, so it was reverted in favor of moving the layers.

## Round 5: Sliders (shiny-examples 005, 2026-08-17)

Five sliders feeding one table through a shared reactive. The point
of this round was the gap-table #1 entry: **range mode is now
`range_slider()`**, a real component in all three renderers rather
than a slider variant.

- **One input, two thumbs, value = the pair [lo, hi] everywhere**:
  the tree, every input frame, the seed. The arity rule (exactly
  two, ordered, in bounds) lives in check_component() beside
  select_input's multiple/selected rule; a new "numbers" field type
  carries the pair. normalize_value() already collapses the wire
  array to a numeric vector, so the server sees the same shape from
  the seed and from a client frame.
- **Browser lowering**: two overlaid native range inputs
  (data-g-range-end lo/hi) over one rail+fill, pointer-events only
  on the thumbs; the binding sits on the box because an end input
  carrying data-g-target would send a scalar where the server keeps
  a pair. Crossing clamps to the other thumb.
- **Flutter lowering**: Material RangeSlider under the same three
  number layers as a single slider — chip/track-space/scale code
  now shared as _sliderChip / _trackX / _sliderScale. Both ends
  quantize through _sliderQuantize, so a stepless 1..1000 range
  drags in whole numbers like the single slider does (drag test
  pins ordered whole pairs; settle test pins one frame at release).
- **Live check, both frontends against the running Shiny original**:
  boot table seeds all five rows (Range "200 500"); an HTML thumb
  drag lands 430 500, a flutter track click lands 200 723 — whole
  numbers, ordered, one table re-emission each.

Deferred gaps (still open after this round):

- **Slider display formatting** — 005's Custom Format slider uses
  pre = "$", sep = "," (ion's prettify). glinty sliders render the
  bare number; a format vocabulary (prefix/suffix/thousands) would
  have to hold across all three renderers. Ports as a plain slider.
- **Slider animation** — animate = TRUE / animationOptions(): a play
  button stepping the value on an interval, optionally looping.
  Nothing in the vocabulary yet. Ports as a plain slider.
- **Range bubble merge** — when lo and hi get close, the two value
  bubbles overlap (ion merges them into one "430 — 500" chip).
  Cosmetic, both frontends, not yet handled.

## Round 6: MPG (shiny-examples 004, 2026-08-17)

A select picks the boxplot grouping, a checkbox toggles outliers,
one reactive formula string feeds a caption and the plot. Small on
purpose after the range build — the round's yield is a vocabulary
asymmetry and a capture-infrastructure lesson.

- **text_output had no heading variant** while text did, so Shiny's
  h3(textOutput(...)) — a caption whose text is computed — was
  inexpressible. Added to the enum; same tokens in every renderer
  (g-text-heading / titleMedium); the css guard derives its probe
  families from the schema, so it picked the new variant up with no
  code change.
- **check.R lesson**: "toggle outliers, assert pixels changed" is
  only a test on a grouping that has outliers to hide. mpg ~ am and
  mpg ~ gear have none — hiding nothing draws identical bytes — so
  the check toggles on cyl (2 outliers) before switching variables.
- **Live**: HTML side full round trip (form_input on the select →
  caption "mpg ~ am" + factor-labelled boxplot; checkbox toggles
  re-rendered the plot only, twice, per the trace). Flutter side
  static-verified by canvas grab (heading caption, checked box,
  plot); its interaction paths were live-verified in rounds 3-5 and
  hold in the widget tests.

Infrastructure learned the hard way this round:

- **CDP Page.captureScreenshot can freeze on the CanvasKit tab**
  (30s timeout, twice, on two fresh tabs) while the page thread
  stays fully responsive — and the timed-out capture then leaves
  the 784x370 device-metrics override behind, poisoning the tab's
  coordinate space (the round-4 failure, now with its cause
  observed). The app was never at fault: the server trace showed
  welcome + outputs delivered throughout.
- **Workaround that gets pixels anyway**: inside the page,
  drawImage the flutter canvas (it lives in flt-glass-pane's shadow
  root — walk shadowRoots to find it) onto a 2D canvas and
  toDataURL. Full-page came out through a local listener;
  region crops are the right unit when a listener is unavailable
  (tool output truncates ~8K and the extension's DLP filter blocks
  long base64 blobs — don't fight the filter, crop smaller or use
  the a11y route).
- **Native select popups are OS windows**: extension clicks cannot
  reach the option list. form_input (or keyboard) is the way to
  drive a select_input in the HTML frontend.

## Round 7: More Widgets (shiny-examples 007, 2026-08-17)

The dataset viewer whose outputs move only on Update View. **First
round that needed zero framework changes** — the port is
vocabulary and semantics glinty already had:

- Shiny's `eventReactive(input$update, ..., ignoreNULL = FALSE)`
  composes as a reactive_val written by
  `observe_event(ignore_init = FALSE, ignore_null = FALSE)`: the
  handler body already runs under isolate(), so reading the select
  inside adds no dependency, and ignore_init = FALSE computes the
  boot value. `isolate(input$obs())` gates the row count exactly as
  the original's isolate() does.
- helpText is txt(variant = "muted"), as the gap table predicted.
- In-process check pins the negative space: select + number changes
  re-render nothing; the press applies both; obs stays isolated
  after the first press.
- Live (HTML): pressure + 5 typed while outputs held rock + 10;
  one press swapped summary and table together. Flutter viewer
  reconnected across the app swap (welcome + outputs in trace) and
  a canvas pixel probe confirmed it painting text and the filled
  button; blob-returning captures stay DLP-blocked, so numeric
  probes are the unit for viewer liveness now.

## Round 8: Uploading Files (shiny-examples 009, 2026-08-17)

The CSV-upload app: file_input feeds read.csv steered by
header/sep/quote radios, req() keeps the table silent until a file
exists. Zero framework changes again.

- **The upload value is Shiny's shape already**: a data.frame with
  name/size/type/datapath, one row per file, so the server code
  ports line for line. An empty-string radio value (the None quote)
  works on the wire.
- **Live over real HTTP**: the extension's file_upload set the file
  on the input, the browser POSTed against the transfer ticket, and
  the table appeared -- head 6 of 8 with mixed alignment (city
  left, numbers right: the align wire on real data), Display = All
  showed all 8. In-process check covers sep/header/disp
  re-parses and the boot silence.
- **Flutter viewer: the named-gap path, working as designed.** The
  library carries uploads through the onUpload embedder seam; the
  viewer passes none, so file_input renders the pale-yellow "[no
  file picker wired: pass onUpload to send files]" banner while
  every sibling control renders normally. Wiring a picker
  (file_picker package) is embedder work for the viewer, tracked
  here rather than hidden.
- **The frozen-capture saga resolved into a rule**: the freeze is
  tab-sticky, not page-sticky. The wedged tab also stops
  repainting new frames (its canvas pixel-counts stayed
  byte-identical across an app swap -- that staleness is itself
  the tell). A recreated tab captured fine immediately. Recreate,
  don't rehabilitate.

## Round 9: Downloading Data (shiny-examples 010, 2026-08-17)

The dataset-download app, plus the round's real work: **the viewer
now wires both transfer seams** (web leg), so file_input and
download_button stop refusing there.

- **Port**: line for line again, with one DX divergence worth
  stating: glinty's download_handler(session, id, filename,
  content) registers on the session by id rather than assigning
  into output$ -- the press IS the transfer, so there is no output
  value to hold. filename= and content= both read inputs at
  redemption time (the served name tracks the select).
- **In-process check covers the whole ticket path**: 200 with
  content-disposition naming the current dataset, correct CSV
  body, filename following a select change, and a spent ticket
  refusing with 403 (one-shot).
- **Viewer wiring** (sandbox/flutter-viewer): a conditional-import
  pair -- transfer_web.dart drives a transient <input type=file>
  and posts multipart to await request.target(); downloads are an
  anchor click, a top-level navigation that works cross-origin
  where an XHR would need CORS. transfer_stub.dart keeps native
  refusing by name (a dialog plugin the viewer does not take on).
  Live proof: the Download button renders ENABLED in the viewer --
  unwired it names the gap -- beside the same rock table as the
  browser. Cross-origin note: the viewer's upload POST (8492 ->
  8490) will need CORS on the upload endpoint before that leg can
  land files; the download anchor path has no such constraint.
- **Not pressed live**: actually saving a file is a download
  action gated on explicit permission -- the ticket path is fully
  proven in-process; the live click is Troy's to try.
- The CanvasKit capture freeze reproduced on a hard reload and
  once more on a fresh tab mid-boot; the recreate-don't-
  rehabilitate rule held both times (second fresh tab captured
  fine).

## Round 10: Timer (shiny-examples 011, 2026-08-17)

The one-line clock: invalidate_later(1000) re-arms a render_text
every second. Fourth straight zero-framework-change port.

- The check drives run_due_timers() at chosen nows, so it is
  deterministic -- three sweeps, three re-renders, re-armed each
  time, and a not-due sweep stays quiet. No sleeps.
- Live: both frontends tick in step from the one server render --
  the browser tab and the flutter viewer each showed the current
  second, and the viewer picked the new app up by reconnect alone
  (no reload, no rebuild -- the smoothest app swap of the loop).
- text_output(variant = "heading") earned its second use one round
  after existing.

## Round 11: HTML UI (shiny-examples 008, 2026-08-17)

The gallery entry whose point is htmlTemplate(): the UI is a
hand-written index.html wearing shiny classes. **Ported deliberately
unfaithfully** — same app, expressed in vocabulary — because
page-level raw HTML is the escape hatch glinty exists to remove: a
raw page renders in exactly one frontend, and the whole bet is
one tree, every frontend. glinty's raw_html/html_output remain as
browser-only VALUE escape valves that other frontends refuse by
name; there is no page-level template on purpose, and this round
records that as a boundary, not a gap.

Worth noting from the side-by-side: the vocabulary port renders
better than the original in the original's own frontend (the raw
template has no styling beyond browser defaults), and the same tree
came up in the flutter viewer with the number field's bounds
rendered as Material helper text — the frontend spending schema
data its own way, which is the argument for the boundary in one
screenshot. Fifth straight port with zero framework changes. Also
filed this round, from the loop's accumulated evidence: glinty #56
(run_app loop waits on external fds) and #57 (client declaration
tables derived from the R schema instead of hand-restated).

## Round 12: DataTables (shiny-examples 012, 2026-08-17)

The strategic-gap round: gap-table #2 (interactive table) and #5
(checkbox group) both closed, because the app is nothing but the two
of them. `data_table()` takes the same table value `table_output`
does and adds client-side sort/filter/paginate — the server lowers
an empty shell with the options as data attributes, the interactive
build happens where the value arrives, and `align` doubles as the
sort-type signal (`"num"` sorts numerically). Design decisions that
proved out live:

- **Interaction never touches the server.** Sorting 1000 diamonds is
  a local rearrangement; the trace shows zero frames from a sort,
  filter, or page click. Shiny ships DT (a JS library wrapping the
  same idea); glinty's is ~170 lines of glinty.js and one stateful
  Flutter widget, same state machine, asserted equal by tests on
  both sides.
- **Clamp, don't reset.** A value update keeps the reader's page
  unless the page stopped existing. Verified end to end in one
  frame: uncheck a column while on page 2 of a filtered, sorted
  view — the server re-renders the value, the view comes back still
  on page 2, filter and sort intact.
- **Persistent controls over rebuilt body.** The browser builds the
  length select and search box once per element, so focus survives
  value updates; only table and footer rebuild.
- **checkbox_group is the plural radio_buttons** and the third
  member of the array-at-every-length family (multiple select,
  range_slider, now selected/reported values incl. `[]`). Binding
  on the box, members carry only a marker — a member with a target
  would report a scalar where the server keeps a list. Its live
  role here: the diamonds column picker, plural value subsetting
  the data.frame server-side.
- **The whole 012 app needed zero new layout machinery**: tabset +
  conditional panels keyed on the tabset's own input (input_is on
  tab titles, where Shiny writes a JS expression string) composed
  with the new components on the first try.

Ported unfaithfully where DT is cosmetic: orderClasses (tinting the
sorted column) skipped; DT's rownames pseudo-column dropped, mtcars
keeps its models by making them a real `model` column (render_table
discards rownames, and that is the honest wire shape — a column is
data or it isn't).

Verification asymmetry worth recording: browser frontend verified
live (sort arrows, case-insensitive filter with "(filtered from
1000)", paging, the clamp scenario, per-tab independent state, iris
honoring page_length 5 / menu 5-30-50); flutter renderer verified
headless (278 dart tests incl. a 1000-rows-in-a-tabset scale test)
plus semantics-tree readout of the live viewer showing the real
server value rendered — but live *interaction* on the web viewer was
blocked by the stuck CDP device-metrics override (viewport pinned
1920x905 in a 1568-wide window; pointer events never reach the
engine, resize doesn't propagate, capture times out). Even a fresh
tab inherited it this time, so "recreate the tab" is no longer a
complete recipe; native-window ffmpeg capture or a driven
RepaintBoundary test remains the fallback. Infrastructure, not
framework: the same build's logic passes every headless interaction
test.

littler note for gallery apps: glinty deliberately exports `txt()`
not `text()` (graphics::text would collide); under littler the
collision still materializes if an app touches ggplot2 — the lazy
autoload attaches graphics *after* glinty and graphics::text wins.
`txt()` sidesteps the whole class.

## Round 13: Selectize (shiny-examples 013, 2026-08-17)

Gap #3 closed: `select_input(search = TRUE)`, a combobox over the
same closed choices. The design line that survived every decision:
**typed text is a view, never a value.** Filtering happens against
the declared choice list, only picking a real choice reports, and
the server's value domain never widens to free text — which is also
why selectize's `create = TRUE` is deliberately not taken.

The browser build extends the box-binding rule to its logical end:
binding and current value live on the box (`data-g-selected`), the
option list is pre-rendered, and every interaction reads and writes
DOM state. That is not a style preference — the client **adopts**
server markup when ui_revision matches, so a control whose state
lives in JS memory would come up empty on exactly the pages the
server rendered. Flutter is one widget swap: Material's
`DropdownMenu(enableFilter:)` is this component natively.

**Round-13 bug, found by the port's own check:** an empty JSON
array from the wire normalized to `NULL` — `unlist(list())` — so
deselecting the last item of a multi select set the server's value
to NULL where the seed for the identical state is `character(0)`.
The array-at-every-length rule held everywhere except the server's
own front door. Fixed in normalize_value ([] → character(0)); the
old behavior was even pinned by a test, which is the reminder that
a pin proves stability, not correctness. Surfaced only because
drive.R was ALSO bypassing normalize_value (feeding raw lists), and
the two wrongs disagreed — the harness now routes input through the
live dispatch path, per its own header promise.

Ported unfaithfully: e0/e1/e2/e5 (plain, zero-config→search, multi,
capped-multi→uncapped). Not taken: create (domain), maxOptions /
maxItems (display knobs), raw-JS placeholder/onInitialize/render/
score/load and the GitHub remote search (the escape hatch this
vocabulary removes; server-driven choices already have
update_select_input). Live-verified in the browser end to end:
type-to-filter, arrow-key highlight, Enter pick reporting the value,
label snap-back, and the select-then-deselect chr(0) round trip.
Flutter: headless only this round (281 tests, incl. DropdownMenu
value-vs-label reporting); the viewer tab's compositor wedge now
blocks semantics entirely, not just capture.

## Round 14: onFlushed (shiny-examples 014, 2026-08-17)

The deferred-expensive-render pattern: paint placeholders, start the
real work only after they reached the client. glinty had no seam for
"after the flush" — an observer flips the flag inside the same flush
and the slow work then blocks the first paint, which is precisely
what the pattern exists to prevent. Added `session$on_flushed(fn)`,
sibling of the existing `on_ended`: fires once, from the event loop,
**after `drain_all_sessions()`** — so "flushed" means the messages
left for the client, not merely got computed. A fired callback zeroes
the next select timeout, so state it changed flushes immediately
instead of waiting out the tick.

Semantics pinned by tests: once per registration (re-register inside
the callback for every-flush, and a callback registering another
defers it to the *next* fire, so the idiom terminates each round);
one failing callback warns without eating its neighbors; an ended
session's callbacks never fire. The port then drops the original's
`invalidateLater(0)` — Shiny's 2013 example needs it, here flipping
the reactive_val already invalidates every render that read it.

Numbers from the in-process check: boot flush 0.04s carrying
placeholders, settle 5.4s doing the deferred work — and the live
trace shows the same order per fresh session (Please wait → This
happens later). A browser reload mid-work resumes and replays the
finished outputs instantly, which is the resume machinery composing
with the new hook for free.

drive.R grew the matching seam: drive_boot() now stops at the queued
first flush, and `drive_settle()` is the explicit "let the loop
spin" (timers → flush → fire, until quiet) so a check can look at
both phases.

DX note for later: session methods (`on_ended`, now `on_flushed`,
`flush_now`) are documented only in source comments — there is no
?glinty_session for app authors to find them.

## Round 15: Layout pair (shiny-examples 015-sidebar + 015-navbar, 2026-08-17)

Both 015s in one app, because each alone is a fragment. Zero
framework changes — the sixth such round.

- **sidebar-right is child order.** Shiny needs
  `sidebarLayout(position = "right")`; glinty's row() already says
  where things are by where they are. The check pins it as a
  lowering fact: the plot slot lowers before the sidebar panel.
- **navbarPage ports as tabset on a full-width page.** Same
  navigation, in-page chrome. The real distinction — top-level
  window chrome with a brand bar vs a tabset in the page flow — is
  left open in the gap table on purpose: the example is three empty
  tabPanels, which is not enough signal to design chrome against.
  A consumer app that actually wants a navbar should drive it.

Live: full-width page, tab strip, right-hand slider sidebar,
histogram at measured full width; tab swap is pure visibility (zero
re-renders, pinned in-process).

## Rounds 16-21 skip sweep (2026-08-17, per Troy)

Six examples skipped with reasons, not silence:

- **016-knitr-pdf, 020-knit-html, 019-mathjax** — knitr/MathJax
  document rendering inside the app: ecosystem embeds, outside the
  closed vocabulary by design (the htmlwidgets boundary already in
  the gap table). Skipped at Troy's direction.
- **017-select-vs-selectize** — a behavior-comparison demo of
  Shiny's two select widgets. glinty has one select (+ search flag,
  round 13); the choose-prompt/clearability nuance it demos is
  selectize-specific UI. Nothing to port that rounds 7/13 didn't.
- **018-datatable-options** — the DT options tour. Round 12's
  data_table covers display length, length menu and search toggle;
  a paginate-off switch is a large page_length; the "function
  callback" tab is raw-JS configuration, refused by design.
- **021-selectize-plot** — the substance is
  `session$registerDataObj`, a custom HTTP responder hanging off
  Shiny internals (`shiny:::httpResponse`). glinty serves derived
  media through render_image/render_plot and the ticket path
  instead of handing apps raw HTTP; the selectize half is round 13.

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
   animate; skip animate, range is the gap. **CLOSED round 5:
   range_slider() in all three renderers.** animate and pre/sep
   formatting remain (see round 5 deferred gaps).
2. **interactive table** — renderDataTable/dataTableOutput/DT
   (20+16+2): sort/filter/paginate. glinty table is static. Biggest
   strategic gap; whole "DataTables" demos rest on it. **CLOSED
   round 12: data_table() in all three renderers**, client-side
   over the existing table value. orderClasses tinting remains
   cosmetic-out-of-scope.
3. **selectize-style select** — selectizeInput (16) + update (10):
   searchable dropdown, server-side choices, multi/tags. A
   `search = TRUE` flag on select_input covers most uses. **CLOSED
   round 13: select_input(search = TRUE) in all three renderers**;
   create/maxItems/raw-JS options deliberately not taken.
4. **plot interaction** — brushedPoints (14) + nearPoints (9): click/
   brush/hover on plot_output reported to the server. Protocol-level
   (new input frames). Gates the whole "Interactive Plots" section.
5. **checkbox group** — checkboxGroupInput (12) + update (4). Clear,
   small vocabulary gap. **CLOSED round 12: checkbox_group() in all
   three renderers**, array-valued at every length; update_* still
   open (choices push exists for select/radio only).
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
