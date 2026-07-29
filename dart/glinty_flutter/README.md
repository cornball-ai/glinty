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

## Seams

Five things need a platform plugin, and this package has exactly one
dependency. Rather than take on the plugins each would need --
which every glinty app would inherit whether or not it used them --
`GlintyApp` asks:

| seam | without it |
|---|---|
| `onDownload` | download buttons render disabled |
| `onLink` | links render as styled text, not tappable |
| `audioBuilder` | an `audio_output` names the missing player |
| `onUpload` | a `file_input` names the missing picker |
| `customHandlers` | a `custom` frame draws a notice naming its handler |

```dart
GlintyApp(
  url: Uri.parse('ws://10.0.2.2:8080/ws'),
  audioBuilder: (context, source) => MyPlayer(
    // resolved for you: a data URI as-is, a relative path joined to
    // the address serving the app
    url: source.src,
    // what it is, which a platform player asks and a browser sniffs
    mime: source.mime,
    autoplay: source.autoplay,
  ),
)
```

None of them fails quietly. That is the rule the whole client is
built on.

## Versioning

Living in glinty's repository means the client and server are authored
together. It does **not** mean they deploy together: an installed app
runs against whatever server it can reach, which may be weeks ahead.
`hello` and `welcome` carry `protocol` for exactly that reason, and
those checks are load-bearing.

## Status

Alpha, and rendering the whole vocabulary bar one: `date_input`,
which is a dialog rather than an inline control. `raw_html` and
`html_output` carry markup and are refused by design, not by
omission.
