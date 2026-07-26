# tools

Developer scripts. Not part of the package build (`.Rbuildignore`d).

## jsbridge.js

Runtime checks for `inst/www/glinty.js`, the client. R tests can only
grep that file; this actually runs it against a stubbed DOM and
WebSocket, driving it through boot, the pre-connect send queue, resume,
custom-message dispatch, and dynamic-UI construction.

```sh
node tools/jsbridge.js inst/www/glinty.js
```

Requires only node, no packages. Not wired into CI: adding a JS
toolchain to a base-R package's CI is a real cost for one file. Run it
by hand when touching the client.

It earned its place by catching the SVG namespace bug, where inline
icons built by `render_ui()` parsed cleanly and never rendered.
