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
