# glinty (development version)

Protocol v3, stages 1 through 3. The wire now carries semantic
components rather than DOM instructions, which is what lets a
frontend that is not a browser render a glinty app; the bootstrap
travels over the wire, with the browser hydrating its pre-rendered
markup against a tree revision; and outputs are typed by what the
renderer produced rather than by the DOM property a browser would
patch. See PROTOCOL.md.

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
- Fixed-size plots (`render_plot(width=, height=)`) do not subscribe
  to measurements at all: they render once, at dpr 1.
- The browser re-measures when a tab switches, a conditional panel
  toggles, or dynamic UI arrives -- the moments a plot can appear at
  a size the server has never heard about.

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

# glinty 0.4.1

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

# glinty 0.4.0

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

# glinty 0.3.0

- Native parity: select, textarea, number, and table_output render
  natively (needs flitR >= 0.0.1.3); native sessions seed inputs
  from widget defaults like the browser init harvest.
- Shared layout: row() and column() map to flexbox in the browser
  and flitR layouts natively.
- Tables travel as structure (header + rows) instead of HTML;
  frontends render them natively.

# glinty 0.2.0

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

# glinty 0.1.0

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
