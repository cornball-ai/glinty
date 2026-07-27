# glinty_flutter

glinty's Flutter client. Connects to a glinty server, renders the
component tree it sends, and reports input back.

Not an alternative to Flutter — the Flutter equivalent of
`glinty.js`. Flutter is the UI framework; this is the small runtime on
top of it that speaks glinty's protocol.

```dart
// Regular Flutter: you write the UI
MaterialApp(home: TextField(...));

// glinty_flutter: the server sends it
final renderer = GlintyRenderer(
  onInput: (id, value) => socket.input(id, value),
  onEvent: (id) => socket.event(id),
  values: outputValues,
);
renderer.build(context, GlintyComponent.fromJson(tree));
```

## Conformance

Tests read `../../inst/fixtures/components.json` — the same file
glinty's R tests use. One repository, one fixture list, no copy to
keep in step. Adding a component on the R side fails here until this
client answers for it.

```sh
flutter test
```

A component this client does not know draws a **visible placeholder
naming it**, never nothing. `unsupportedComponents` lists what is
deliberately not rendered, and why.

## Versioning

Living in glinty's repository means the client and server are authored
together. It does **not** mean they deploy together: an installed app
runs against whatever server it can reach, which may be weeks ahead.
`hello` and `welcome` carry `protocol` for exactly that reason, and
those checks are load-bearing.

## Status

Early. Renders the static, layout, input and simple-output components.
Not yet: the WebSocket transport, `plot_output` (needs the `measure`
round trip), `ui_output` (needs runtime subtrees), `audio_output` and
`file_input` (packages outside the SDK), `date_input` (a dialog rather
than an inline control).
