# glinty (development version)

**The workspace vocabulary.** A workspace app -- an editor, a
dashboard, anything built from side-by-side panels -- could not be
said without a custom stylesheet. Now it can (#34):

- `page(width = "full")` takes the whole viewport instead of the
  centred reading column, at workspace density.
- `row(align = "stretch")` makes side-by-side children match heights.
- `panel(fill = TRUE)` hands the panel's height to its children, so
  one of them can grow into it.
- `column(scroll = TRUE)` scrolls its overflow instead of growing the
  page; grown and scrolling is the message-list shape.
- `txt()` and `text_output()` take variants `"mono"` (timecodes, file
  listings, hashes -- anything that aligns by character) and `"small"`
  (fine print).

All of it is component vocabulary, not CSS: the Flutter lowering maps
`stretch` onto `IntrinsicHeight`, `fill` onto a max-size `Column` with
`Expanded` children, `scroll` onto `SingleChildScrollView`, and the
text variants onto the theme's type scale, while a `page` width stays
a viewport hint it may ignore.

**Four S3 methods were shipping with no documentation.** `$`, `[[`,
`$<-` and `[[<-` on the input and output proxies had help pages that
`R CMD build` was silently dropping: their file names contain
characters that are not legal on every platform, so the build printed
"excluding invalid files" and carried on, and the `R CMD check` that
followed read a tarball they were no longer in. Every CI job stayed
green. Fixed in tinyrox (>= 0.4.1.1), which now names them
`cash-.glinty_input.Rd` and so on, with the real topic kept in
`\name{}` so help still resolves. CI reads the build's own account of
what it excluded now, rather than only the check that follows it.

**Background jobs report progress.** `job_progress(job)` is a reactive
read of what the job last reported, and inside the job the reporting
call is the same `set_progress()` / `inc_progress()` an in-process
operation would make -- they notice they are running in a background
process and write where the server is reading. Instrumented code moves
into a job without being rewritten.

```r
job <- run_job(function(n) {
    for (i in seq_len(n)) {
        glinty::set_progress(i / n, detail = paste("step", i))
        one_step(i)
    }
}, args = list(n = 10))

output$bar <- render_text(function() {
    p <- job_progress(job)
    if (is.null(p)) "starting" else paste0(round(p$value * 100), "%")
})
```

- The path travels in the child's environment, so the job's function
  needs no extra argument of its own -- and a job that does not report
  progress carries no spare parameter.
- The file holds one line, overwritten: progress is a level, not a
  stream, and a file that grew with every update would make each poll
  cost more than the one before.
- Resolution is `getOption("glinty.job_poll", 0.25)` seconds rather
  than every call the job makes.
- `run_example("jobs")` shows the percentage while the work runs.

**`css_computed_conflicts()`.** The check `css_variant_conflicts()`
documents itself as not being. It renders every variant of every
family, loads the stylesheets in the order a real page loads them, and
reads `getComputedStyle()` out of headless Chrome -- so it sees what
the cascade actually did rather than what the selectors look like.

- Catches the three shapes source reading cannot: a `:hover` rule on a
  base class overruling a variant's hover, `!important`, and a
  shorthand cancelling a longhand (`background` on `.g-btn` wipes the
  `background-color` every variant sets).
- Differential: the page is measured with and without the app's
  stylesheet, and only a distinction glinty makes and the app removes
  is a finding. Nothing has to be kept in step with glinty.css.
- States are forced by rewriting `:hover` into `.g-force-hover`, which
  has the same specificity, so hover, focus and active are measured
  alongside the default state.
- Needs a browser and says so. A missing one is an error naming what
  to install, never a quiet pass, and `GLINTY_REQUIRE_BROWSER` (set in
  CI) turns "there was no browser" into a failure.

**`render_image()`.** The renderer the docs for `image_output()` had
promised all along. Sends kind `image` (`{src, width?, height?}`): a
`data:` URI, `/static/` path, or URL passes through, and a source
naming an existing file on the server is embedded as a data URI with
the media type read off the extension -- an unknown extension is an
error naming the fix, exactly as in `render_audio()`. No protocol
change: both clients already display the `image` kind; this fills the
server-side gap where the only way to put an existing PNG in an
`image_output()` was to redraw it through `render_plot()`.

**Background jobs.** `run_job()` hands a function to a fresh R process
and returns a handle; `job_status()`, `job_result()` and `job_error()`
are reactive reads, so an output that calls one re-renders when the job
settles. The handle is polled from the event loop's own timer heap, so
there is no second wakeup mechanism and no busy loop, and nothing
crosses the wire -- a client cannot tell a job from a slow observer
except that the page stayed alive while it ran.

- The function runs in a session that has never seen the caller's, so
  it sees its arguments and nothing else. `k <- 5; run_job(function()
  k + 1)` fails in the child; pass `k` in.
- A session-scoped job (the default) survives a dropped connection and
  a resume, and dies when the resume grace expires with nobody having
  come back. `scope = "app"` outlives every session.
- `run_app(job_lanes =)` sizes named lanes, each
  `list(concurrency =, queue =)`, merging over the built-in
  `default = list(concurrency = 2, queue = 8)`. A job picks its lane;
  the app sizes it. Under the queue depth a job waits; past it the
  handle comes back with status `"refused"` and a reason, following
  the ticket cap -- a refusal is a value the caller can see, never a
  silent drop.
- Lanes bound this app's concurrency, not the device. Two glinty apps
  each holding themselves to one GPU job still send two requests at
  the same card.
- Lane settings are not coerced and not ignored: `2.5`, `"2"` and an
  unknown setting name all stop the app starting, rather than letting
  it run at numbers nobody wrote.
- New dependency: `callr`, which brings `otel`, `processx`, `ps` and
  `R6`. Not the "same cost as processx" the issue estimated; taken
  anyway because the serialization plumbing processx would leave us to
  write is the half that has to be right.
- `run_example("jobs")` is the demo: start a few, watch the clock keep
  ticking, open a second tab.

**Protocol v3 is frozen.** The component vocabulary, the message
types and their field shapes are settled, and three lowerings render
them: R to HTML, `glinty.js` to DOM, `dart/glinty_flutter` to Flutter
widgets. PROTOCOL.md said the spec would stay draft until two clients
agreed on shared fixtures; they do.

Breaking: protocol 2 is gone, and `run_app_native()` with it. flitR is
retired rather than retrofitted -- Flutter desktop covers the same
platforms with real widgets, real text input and an accessibility tree
flitR could not offer.

The freeze came out of eight adversarial review rounds, and what they
were best at was catching claims nothing checked:

- The fixture list said "every component, once" and was missing 13 of
  them; the test asserted `length >= 20`. It now asserts against
  `COMPONENT_SCHEMA`, so the claim is checked rather than repeated.
- `INPUT_META`'s own documentation said it was "what the conformance
  test holds both lowerings to". Nothing read the field. It is now
  checked against what each input actually seeds -- which is how
  `select_input` was found declaring `"string"` for a control whose
  value is a list.
- The Flutter client declared the `measure` feature and never
  measured, three lines below a comment stating that a feature named
  without an implementation is a claim the server believes.

Fixed in those rounds:

- `select_input(multiple = TRUE)` was scalar in five places: the
  schema rejected `c("a", "b")` outright, both lowerings compared a
  choice against the whole selection by equality (so an app choosing
  three options rendered none chosen), the browser's `input_update`
  assigned an array to `el.value` and silently cleared the control,
  and R seeded `NULL` where the browser harvests `[]`. `selected` is
  now plural, held to `multiple` by a new cross-field check, and is an
  array at **every** length -- a one-element selection that collapsed
  to a bare string would have clients parsing a list sometimes and a
  string other times. `update_select_input()` follows the same rule
  and gained a `multiple` argument for the one- and zero-value cases.
- The Flutter client dropped `modal`, `progress` and `custom` frames,
  making `show_modal()` and `with_progress()` no-ops against it. All
  three are handled now: dialogs and progress reports draw, and a
  `custom` frame naming a handler nothing registered is named on
  screen. Handlers arrive as `GlintyApp(customHandlers:)`.
- `modal_button()` closed nothing in either client. The browser's
  click delegation had always looked for `data-g-modal-close`; no
  lowering ever set it, so a Cancel rendered and did nothing.
- `plot_output` and `image_output` render in Flutter, which is what
  makes the `measure` declaration true. Every plot reports its box --
  fixed ones included, because the size is only half of a measurement
  and the device pixel ratio is the half the app cannot supply.
- Outputs carry their `kind` and their scoped errors through to the
  Flutter renderer. A `text_output` handed an image value used to
  stringify the payload; an errored slot used to go blank.
- Input handling in Flutter: a `settle` slider reports on release
  rather than streaming, a `settle` text field reports on blur as
  well as enter, and a server push refused because a field has focus
  is counted rather than compared -- so an identical later push still
  lands instead of being swallowed.
- Transport: the welcome deadline is armed before the connect, not
  after, so a socket that never opens still spends the retry budget;
  attempts are numbered so a late socket is closed rather than
  adopted; and a terminal stop closes the wire it stopped on.

Protocol v3, stages 1 through 4. The wire now carries semantic
components rather than DOM instructions, which is what lets a
frontend that is not a browser render a glinty app; the bootstrap
travels over the wire, with the browser hydrating its pre-rendered
markup against a tree revision; and outputs are typed by what the
renderer produced rather than by the DOM property a browser would
patch. See PROTOCOL.md.

Stage 6, the Flutter client becomes an app:

- `dart/glinty_flutter` grew a transport. `GlintyApp(url:)` connects,
  renders whatever the server sends, and keeps the wire open;
  `GlintyConnection` owns the socket, the hello, and a bounded
  reconnect that carries `resume`. A refused connection stops
  retrying and says why; one that exhausts its retries says that
  instead of spinning.
- Fixed: the Dart session never put `resume` in its hello, so it
  could not actually resume -- caught by the first transport test
  that asked it to.
- `download_button` presses now request a ticket rather than firing
  an event, in Flutter as in the browser; the resolved https URL
  goes to an `onDownload` callback, since saving a file is platform
  work this package leaves to the embedder.
- New test: `server_e2e_test.dart` spawns a real R server and drives
  the real client through bootstrap, seeded inputs, an input round
  trip, events, a ticket grant, resume with state replay, and an
  auth refusal. CI installs R for it and then asserts it did not
  skip.
- **Inputs are state, not tree fields.** The session keeps an input
  store, seeded from the tree exactly the way the server seeds its
  own, updated by user edits and by `input_update` frames; controls
  read from it. Before this a text field lost what you typed on the
  next rebuild, and checkboxes, selects, sliders and radios sat at
  their initial values forever. `conditional_panel` now evaluates
  its condition against that store, by the same matching rules R and
  the browser use.
- A refused resume (`resumed: false`) clears values, inputs and
  tickets and bumps a generation the widget tree keys on, so
  controllers belonging to the dead session go with it. The browser
  reloads the page for the same reason.
- Transport corrections: `live` waits for `welcome` rather than a
  merely-open socket, a welcome resets the retry budget (a
  long-lived app that drops once a day used to exhaust it), and
  interactions made during a reconnect are queued and flushed
  instead of silently dropped.
- Honest declarations: `hello.features` lists `download` only when
  an `onDownload` is wired, and a link with no `onLink` renders as
  styled text rather than an `InkWell` that looks tappable and does
  nothing.
- `GlintyApp` reconnects when its `url` or `token` changes, or when
  wiring `onDownload` changes what `hello` declares. A rebuilt
  closure is the same capability and does not reconnect; the
  connection just points at the current callbacks.
- A local edit notifies the connection, so a tap redraws the app
  immediately rather than at whatever moment the next server frame
  happens to arrive. (The tests that were supposed to cover this
  repainted on the app's behalf and so proved nothing; the new ones
  pump and expect, and nothing else.)
- `input_update` carries `label`, `choices`, `min`, `max` and `step`
  through to the control -- `update_select_input()` changes the
  choices of a control the tree still describes with the old ones.
  A focused text field is never overwritten by a server push, the
  same rule the browser follows.
- A hidden `conditional_panel` goes offstage rather than being
  destroyed: hiding is display, not destruction, which is the
  documented difference from `render_ui()`.
- The reconnect queue is cleared on a refused resume, so one
  session's interactions cannot be replayed into another's, and
  frames queue until `welcome` rather than slipping past a
  half-open socket ahead of what is already waiting.
- A socket that opens and then goes silent times out
  (`welcomeTimeout`, 15s) and counts as a failed attempt. Without
  it the bounded-retry promise was untrue: an app faced with a
  silent server span forever.
- A slider with no value seeds to the midpoint, matching R's
  `slider_default()`, rather than to `min`.

Stage 5, authentication and deployment surface:

- Resume is principal-bound under auth: the re-verified principal's
  `id` must match the detached session's, so a valid token for user
  B plus user A's session id gets B a fresh session, never A's
  replayed outputs. Verifiers that return principals without ids
  give resume nothing to bind to and authenticated resume is refused
  for them.
- Ticket tokens and session ids come from a real CSPRNG (openssl
  when present, /dev/urandom otherwise) -- hashed process state is
  unique, not unpredictable, and both are bearer credentials. Live
  tickets are capped per session even within the TTL, so rapid
  requests cannot grow memory.
- The first frame on a socket must be a well-formed `hello`;
  anything else is refused before authentication runs or a session
  exists.
- A refused connection is visible in Flutter too
  (`GlintyRefusalView`), and the shared transcripts carry the
  refusal exchange all three clients replay. Refusals on
  **reconnect** are visible too: both clients decide by whether the
  socket that sent hello is still awaiting its welcome, not by
  whether they have ever connected -- an expired token on a
  reconnect used to read as an ordinary error and retry forever.
- **New dependency**: `openssl` moves from Suggests to Imports.
  Session ids and tickets are bearer credentials on every platform,
  base R has no CSPRNG, and the previous `/dev/urandom` fallback was
  not cross-platform (a Windows server had no source at all). A
  dependency that is always required belongs in Imports rather than
  behind a `requireNamespace()` guard; RS256 JWTs come along for
  free.
- Hitting the per-session ticket cap now answers with an `error`
  scoped to the resource instead of dropping the request, so a
  waiting upload control is re-enabled rather than left disabled
  forever.
- `resume_allowed()` handles principals of any shape. A verifier may
  return anything non-NULL and glinty keeps it; those without a
  comparable `id` (bare strings, vectors) simply get no resume
  rather than an error.

- New: `run_app(auth = )` takes a verifier for the opaque token a
  client sends in `hello`; its return becomes `session$principal`,
  NULL refuses the connection with one visible error frame and a
  closed socket. The gate covers resume too. glinty never parses
  the token. In the browser, set `window.GLINTY_AUTH` before
  `DOMContentLoaded`.
- New: `jwt_auth()` verifies HS256 JWTs (signature via digest's
  HMAC, `exp` required, `nbf` and `aud` when present/configured)
  and returns the claims with `sub` as `id`. RS256 works when the
  openssl package (now in Suggests) is installed. The configured
  algorithm is pinned: a token claiming any other `alg`, including
  `none`, is refused unread.
- **Breaking**: uploads and downloads ride short-lived single-use
  tickets minted over the WebSocket (`/upload?ticket=`,
  `/download?ticket=`); the session id is out of every URL, browser
  history, and server log. Tickets are scoped to one session, one
  resource, one purpose, expire in
  `getOption("glinty.ticket_ttl", 30)` seconds, and die on first
  redemption.
- Fixed: download buttons were dead in the browser since stage 1 --
  the lowering never emitted `data-g-download`, so a press sent a
  bare event frame and no download. They work again, through
  tickets, and a press is one action: the event frame is not also
  sent.
- New: `GET /healthz` returns `{status, sessions, uptime}` so a
  supervisor can tell "listening" from "working" without opening a
  WebSocket.
- `run_app(port = NULL)` (the new default) reads `GLINTY_PORT` then
  `PORT` from the environment before falling back to 8080, so a
  scheduler-allocated port needs no plumbing. Startup now names the
  all-interfaces exposure in the same breath as the URL.

Stage 4, theme and variants:

- New: `app(theme = app_theme(...))` declares a closed token set --
  nine semantic colors, spacing, radius, fonts -- validated at
  construction, with partial arguments merging over glinty's
  defaults. `welcome` carries the tokens, the served page embeds
  them inline so the first paint is themed, the browser applies them
  as CSS custom properties and Flutter maps them onto `ThemeData`.
  A themeless app keeps each frontend's own defaults, browser dark
  mode included; a supplied theme is exact, with no automatic dark
  variant. Named `app_theme()` rather than `theme()` for the same
  reason `text()` became `txt()`: `theme()` would mask
  `ggplot2::theme()` in the one place glinty most needs plotting to
  work.
- The stylesheet is token-driven throughout and now styles the v3
  class set. This fixes real rot: `--g-space` was referenced but
  never defined (every `spacer()` collapsed to zero height), and the
  stage 1 classes (`.g-field`, `.g-panel-card`, text variants, button
  variants) had no rules at all -- buttons all rendered primary-blue
  regardless of variant. **Breaking** for app stylesheets: the CSS
  variables are now named for the tokens (`--g-primary`,
  `--g-background`, `--g-text`, ...); `--g-accent`, `--g-fg`,
  `--g-bg` are gone.
- Unknown variants fall back to the first listed with a warning, in
  both lowerings and for every variant-bearing component (buttons,
  panels and dividers included, not just text) -- a same-protocol
  server one release newer may know variants a client does not.
- Theme precedence is stable across the connection: the client
  updates the same `#g-theme` style block the served page carried
  (creating one after the stylesheet link if the page had none)
  rather than writing inline properties on the root, so app
  stylesheets that out-cascade the tokens at first paint keep doing
  so after `welcome`.
- Flutter consumes the full token set: `muted` lands on
  `onSurfaceVariant`, `radius` shapes cards and the button family,
  `font$mono` reaches verbatim output, danger buttons take the
  danger token instead of a hardcoded red, sidebar panels are
  visually distinct from plain ones, and a spacing of 0 is honoured
  as a unit rather than replaced with the default.
- The `success` color is dropped from the token set: no component in
  any lowering consumed it, and a closed set should not carry tokens
  nothing renders. It can return alongside the component that uses
  it, which is a compatible addition.
- Font tokens are one family name each (or a CSS generic like
  `system-ui`, meaning the platform's own), constrained to letters,
  digits, spaces and hyphens on both sides -- they are interpolated
  into the served style block, so the character set is the injection
  surface, and validating identically in `app_theme()` and the
  client keeps first paint and hydrated state from diverging.
  Flutter lowers each generic to a role-preserving fallback stack
  (the generic name, which Android resolves natively, then faces
  Apple and desktop ship), so a monospace body stays mono and a
  serif mono token goes serif rather than every generic collapsing
  to sans.
- The Flutter spacer now uses the theme's spacing unit (default 4,
  matching the browser) instead of a hardcoded 8.

Stage 3, typed outputs and measurement:

- **Breaking**: `output` messages (`id`, `kind`, `value`) replace
  `update` messages and their DOM `property`; `input_update`
  replaces `update_input`. `render_plot()` sends
  `{src, width, height}`, `render_audio()` sends `{src}`.
- **Breaking**: `output_property()` is removed. It named a DOM
  property, which is exactly the coupling v3 exists to end;
  renderers say what they produce. Its one documented use (audio
  src) is `render_audio()`.
- Client-sized plots use `measure` messages: the element's box in
  logical pixels plus the device pixel ratio, replacing the reserved
  `..clientdata_output_*` inputs (which the input channel now
  rejects). The raster is produced at `dpr` times the logical size
  with resolution scaled to match, so plots are sharp on high-dpi
  displays instead of upscaled. Clients deduplicate per id -- a dpr
  change alone re-reports, a hidden (zero) box never does -- and the
  server keeps the last real measurement across rebuilds, as session
  state.
- Fixed-size plots (`render_plot(width=, height=)`) keep their
  declared size but still render at the client's density: dpr comes
  from the same measurement, so a fixed 400x300 on a 2x display is
  an 800x600 raster shown at 400x300, not upscaled blur.
- Measurements are resource-capped server-side (logical sides to
  8192, dpr to 8, physical area to 32 megapixels, at most 256
  measured ids per session), so a hostile client gets a stale plot,
  not an allocation.
- The browser re-measures when a tab switches, a conditional panel
  toggles, or dynamic UI arrives -- and, where `ResizeObserver`
  exists, whenever a plot's box changes for reasons glinty cannot
  see: a sibling growing, a font loading, CSS.
- An output kind the browser does not recognise draws a named
  placeholder in the slot, same as an unknown component: a version
  gap the user can see, never a silent console line.

Stage 2, bootstrap over the wire:

- **Breaking**: the wire protocol is now v3 end to end. `welcome`
  (session, protocol, `ui`, `ui_revision`) replaces `config`;
  clients open with `hello`, which also carries `resume` on
  reconnect; buttons send `event` frames instead of `click`; `init`
  is gone. A page cached from 0.4.x should be hard-refreshed once
  after upgrading.
- Sessions seed their inputs from the component tree before the
  server function runs. Reactives read defaults on their very first
  run instead of NULL-then-rerender, nothing is harvested from the
  client, and `observe_event()`'s `ignore_init` now means what it
  says: a seeded default is init state, not a change, so handlers no
  longer fire once at connect for prefilled inputs. An app that
  relied on that accidental startup fire should call the handler
  directly at server start.
- The served page embeds `<meta name="g-ui-revision">`. A client
  whose markup matches the welcome's revision adopts it; a mismatch
  rebuilds from `welcome.ui`; a protocol mismatch draws a visible
  refusal naming both versions.
- The browser client gained a full component renderer. This also
  fixes a stage 1 regression: `render_ui()` output and modal bodies
  travel as component trees, which the client could not build (and
  stage 1's buttons carried no `data-g-event`, so clicks never
  bound). Dynamic UI, modals and buttons work again, and
  `tools/jsbridge.js` now replays the shared transcripts against the
  real client in CI so a gap like that cannot reopen silently.
- `slider_input()` fills in its value when not given: the midpoint,
  which is where an HTML range input sits anyway. The position is on
  the wire, so every frontend starts the thumb in the same place.

Stage 1, semantic components:

- **Breaking**: every UI builder returns a component, not an HTML tag.
  `div()`, `span()`, `p()` and `h1()`-`h4()` are removed; use
  `column()`, `panel()`, `txt()` and `heading(level=)`. `text()` is
  now `txt()`, because `text()` masks `graphics::text()` and a glinty
  app calls that inside `render_plot()`.
- **Breaking**: `tag()` takes a raw HTML string and produces
  `raw_html`, the browser-only escape hatch. It is trusted HTML: the
  string is inserted unescaped, so never interpolate untrusted text
  into it. Use `txt()` for text of any provenance, or
  `html_escape()` first.
- **Breaking**: the flitR native backend is removed. `run_app_native()`
  and its scene translation are gone, and flitR is archived. The
  second frontend is now the Flutter client in `dart/glinty_flutter`,
  which renders the same component trees as real widgets.
- New: `inst/fixtures/components.json` and
  `inst/fixtures/transcripts.json`, generated from R and read by both
  clients. The first covers what a tree looks like, the second what a
  conversation looks like: `hello`/`welcome`, both hydration
  outcomes, the protocol refusal, an input driving an output, and a
  `measure` driving an image. Tests on each side assert the files
  match the definitions they came from.
- New: `ui_revision()`, the SHA-256 of a tree's wire form, so a client
  can tell whether markup it was handed describes the tree it was just
  sent. Defined and pinned by the transcripts here; the server starts
  sending it in stage 2, when `welcome` becomes the bootstrap.

# glinty 0.0.4

- Secrets no longer reach the page. run_app() refuses to start when
  the rendered page contains the value of a secret-looking environment
  variable, and password_input() no longer accepts a value at all.
  Prefilling an input from Sys.getenv() renders the secret into page
  source as a plain attribute, where type="password" masks the screen
  and not the HTML. New env_secrets_in() exposes the same check for
  apps to assert in their own tests. **Breaking**: password_input()
  drops its value argument.
- Fixed: SVG built by render_ui() never rendered. buildTagNode() used
  createElement() for every node, which puts SVG in the HTML namespace
  as an HTMLUnknownElement. Inline icons in dynamic UI silently
  vanished; static UI was unaffected.

Everything an app needs beyond the reactive core: app-supplied
assets, a two-way JavaScript bridge, and the widgets Shiny users
reach for first. Driven by porting two real Shiny apps onto glinty,
so every addition below is a wall one of them hit.

- Native parity for the new set is explicit: verbatim_output() and
  conditional_panel() render natively (the condition is evaluated
  server-side against the same inputs), and tabset, password_input,
  download_button and modal_button fail fast by name rather than
  drawing something wrong. Modals, progress and custom messages are
  inert natively.
- show_modal()/remove_modal()/modal_button(): dialogs built from tag
  trees, mounted inside the app root so inputs in them bind normally.
- with_progress()/inc_progress()/set_progress(): progress bars that
  update during a blocking call, via a new session flush_now() that
  pushes queued messages instead of waiting for the event loop.
- download_handler()/download_button(): serve bytes over a plain GET,
  alongside the existing upload route.
- password_input() and verbatim_output().
- tabset()/tab_panel(): client-side tab switching. Hidden panels keep
  their DOM, so inputs inside them keep their values. With an id the
  tabset is also an input carrying the open tab's title.
- conditional_panel() with input_is(), cond_and(), cond_or() and
  cond_not(): show and hide content without rebuilding it, so nested
  inputs survive. No JavaScript expression and no eval().
- JavaScript bridge: window.Glinty exposes setInputValue(),
  addCustomMessageHandler() and sessionId(). Calls made before the
  socket opens queue and flush on connect. A glinty:connected event
  fires once per page load.
- send_custom_message() sends server-to-app-JavaScript messages.
- Object-valued inputs keep their names. normalize_value() collapsed
  named lists, which destroyed JSON objects sent from app JS; only
  unnamed lists (JSON arrays) collapse now.
- Click binds may carry a value, setting the input to that value
  instead of bumping a counter, so one handler serves a list of rows.
  Bind attributes are escaped like every other attribute.
- page() takes css, js, favicon and head arguments, so apps can ship
  a stylesheet, a tab icon and their own scripts. App CSS is linked
  after glinty's own; app scripts load after the JS client at the end
  of the body.
- run_app() takes max_upload instead of leaving the cap to a hidden
  option. Request bodies are buffered whole in memory, so the ceiling
  belongs to the app.
- serve_static() handles webm, m4a, ogg, flac, woff, woff2, gif, webp
  and txt, and matches extensions case-insensitively.
- render_ui()/ui_output(): dynamic tag-tree content on both
  frontends, with show/hide via NULL and last-state replay for
  nested outputs.

# glinty 0.0.3

- Native parity: select, textarea, number, and table_output render
  natively (needs flitR >= 0.0.1.3); native sessions seed inputs
  from widget defaults like the browser init harvest.
- Shared layout: row() and column() map to flexbox in the browser
  and flitR layouts natively.
- Tables travel as structure (header + rows) instead of HTML;
  frontends render them natively.

# glinty 0.0.2

- flitR native backend: run_app_native() renders apps in a native
  window (Flutter Engine) from the same reactive core and protocol;
  plots ride flitR's new image op.
- File uploads: `file_input()` posts multipart bodies to a per-session
  upload dir; the input value is a data.frame(name, size, type,
  datapath).
- Fixed session id collisions that could route a new connection into
  a detached session (also affected 3+ simultaneous tabs in 0.1.0).
- Reconnect-with-resume: dropped connections keep their session alive
  for a grace window and the client resumes with state intact
  (protocol 2).
- Client-sized plots: `plot_output()`/`render_plot()` default to
  responsive sizing driven by the browser's reported dimensions,
  re-rendering on window resize.
- New inputs: `radio_buttons()` and `date_input()`, with
  `update_radio_buttons()` and `update_date_input()`.

# glinty 0.0.1

Initial release.

- Pure base R reactive engine: `reactive_val()`, `reactive()`,
  `observe()`, `observe_event()`, `isolate()`, `req()`,
  `invalidate_later()`.
- Session-scoped state: one session per browser tab, observers torn
  down on disconnect.
- HTML tag DSL with `data-g-*` event binding; inputs (text, textarea,
  checkbox, select, slider, number, button) and outputs (text, html,
  table, plot, audio).
- Renderers: `render_text()`, `render_html()`, `render_table()`,
  `render_plot()` (PNG data URIs), `render_audio()`; render errors
  surface per-output.
- Server-driven input updates: `update_text_input()` and friends.
- HTTP + RFC 6455 WebSocket server on base R sockets
  (`serverSocket()`/`socketSelect()`), no compiled code; SHA-1
  handshake via digest.
- Zero-dependency JS client (~7 KB) with debounced events, focus-safe
  input updates, and a disconnect overlay.
- Examples: `run_example("counter")`, `run_example("gallery")`,
  `run_example("clock")`.
