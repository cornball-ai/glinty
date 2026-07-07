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
