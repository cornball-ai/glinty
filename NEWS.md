# glinty (development version)

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
