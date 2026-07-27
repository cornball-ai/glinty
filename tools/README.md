# tools

Developer scripts. Not part of the package build (`.Rbuildignore`d).

## jsbridge.js

Runtime checks for `inst/www/glinty.js`, the browser client. R tests
can only grep that file; this runs it, against a hand-rolled mini-DOM
and a fake WebSocket, and drives it through the protocol 3 paths that
matter: the hello/welcome bootstrap, all four hydration invariants,
component rendering against `inst/fixtures/components.json`, and
replays of `inst/fixtures/transcripts.json` -- the same two files the
R and Dart suites consume.

```sh
node tools/jsbridge.js inst/www/glinty.js
```

Requires only node, no packages. Wired into CI as the `browser` job:
the stage 2 hydration gate (adoption emits nothing; one press is one
frame across adoption) lives here, because only the browser adopts
pre-rendered markup and no other suite can stand in for it.

Its track record: the SVG namespace bug (inline icons built by
`render_ui()` parsed cleanly and never rendered), and the stage 1
regression where the client still built the retired tag-tree format
while the server had moved to components, leaving dynamic UI and
buttons dead in the browser.
