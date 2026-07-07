# Lessons

- **Don't hand-roll crypto when a tiny dep exists.** The plan
  originally included a pure-R SHA-1 for the WebSocket handshake;
  Troy redirected to `digest` (zero recursive deps, Eddelbuettel).
  Pattern: for hashing/crypto primitives, reach for digest before
  writing bit arithmetic, even in a minimal-deps package.
- **Check what's already listening on a port before debugging the
  server.** The first smoke test "failed" because port 8123 is Home
  Assistant on this machine; the client was happily talking to it.
  `ss -tln | grep <port>` first.
- **`[[` on a named character vector errors for missing names**
  (unlike lists, which return NULL). Header lookups need a guard.
- **tinyrox ignores standalone roxygen blocks** (e.g. a bare
  `@importFrom` block) and doesn't do `@rdname`. Fully qualify with
  `pkg::` and give each exported function its own doc block.
- **Never save/restore .Random.seed around id generation.** Restoring
  the seed replays the identical draw on the next call: consecutive
  session ids collided and new connections were routed into detached
  strangers' sessions (silent black hole, latent since 0.1.0). Derive
  ids from digest over pid + clock + a monotonic counter instead.
- **`trace(pkg::fn, ...)` ATTACHES pkg**, ahead of whatever was
  attached before. That's how flitR::app masked glinty::app in a test
  harness. Attach order matters; qualify calls in harness scripts.
- **flitR masks graphics primitives** (rect, text, image, app, run).
  Never `library(flitR)` next to glinty or graphics code; call it
  qualified. run_app_native() only needs it installed.
- **Async decodes need a settle window in one-shot renderers.** The
  flitR spike captured the FIRST presented frame; image ops decode
  async and only appear on a follow-up frame. Capture the LAST frame
  after a settle period when verifying async pipelines.
- **Headless Chrome --virtual-time-budget cannot verify WebSocket
  apps post-resume.** Virtual time burns the budget before the real
  network round trip (upgrade -> client init -> session -> updates)
  completes, so dump-dom shows a pre-update DOM and looks like a
  regression. It cost an hour of false debugging against healthy
  code. Verify browser behavior with headed Chrome under Xvfb +
  xwd screenshot after real seconds instead.
- **Never kill background helpers with pgrep/pkill -f patterns that
  appear in your own command line** (third strike). Split spawn and
  cleanup into separate tool calls and kill by PID file.
- **`cd X && cmd & rest` backgrounds the whole `cd X && cmd`**, and
  `rest` runs in the original directory. Files land where you were,
  not where you meant.
