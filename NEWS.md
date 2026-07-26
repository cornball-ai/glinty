# glinty (development version)

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
