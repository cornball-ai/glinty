# glinty protocol v3

Status: **draft**. Not implemented. Protocol 2 is what ships today.

## Why

Protocol 2 cannot carry a UI, and its messages describe the DOM rather
than the app.

The browser receives its initial tree as server-rendered HTML from
`full_page_html()`. The only UI that ever crosses the wire is
`render_ui()` output. Update messages say `{"property": "textContent"}`
and `{"property": "src"}` — instructions for a DOM, not values from an
app.

flitR looks like a counterexample but is not a protocol client at all:
it reads `app_obj$ui` directly in-process and calls `handle_input()`
from widget callbacks, with JSON flowing only downward.

So there is currently no wire format a third frontend could implement.
A Dart/Flutter client would be reverse-engineering the DOM.

v3 makes the wire format the actual seam: a semantic component tree
and typed output values, which each client lowers to its own
primitives. The browser client and the Dart client are peers. Neither
is a translation of the other.

## Principles

1. **Components, not tags.** The wire says `text_input`, not
   `<input type="text" class="g-input">`.
2. **Values, not DOM properties.** An output message carries a value
   and its kind. How to display it is the client's problem.
3. **Above both frontends.** The vocabulary is glinty's, which is
   higher-level than DOM and than Flutter widgets, so each lowers
   cleanly. Modelling on either one distorts the other.
4. **Theme and variants, not stylesheets.** Flutter has no CSS.
   Cross-frontend styling is a theme plus semantic variants.
5. **Honest failure.** A client that meets a component it cannot
   render says so visibly. It does not approximate.

## Messages

### Client to server

| type | fields | meaning |
|---|---|---|
| `hello` | `protocol`, `client`, `components`, `token?`, `resume?` | opening frame; declares what this client can render |
| `input` | `id`, `value` | an input changed |
| `event` | `id`, `kind`, `value?` | a click or other discrete event |
| `ack` | `seq` | optional flow control, reserved |

`hello` replaces both `init` and `resume`. It carries `resume` when
reconnecting. It no longer carries harvested input values: under v3
the server sent the tree, so it already knows the defaults.

### Server to client

| type | fields | meaning |
|---|---|---|
| `welcome` | `session`, `protocol`, `theme`, `ui`, `resumed?` | the bootstrap: session, theme, and the initial component tree |
| `output` | `id`, `kind`, `value` | an output's current value |
| `input_update` | `id`, fields | server-driven input change |
| `ui` | `id`, `tree` | replace a `ui_output`'s subtree |
| `modal` | `action`, `title?`, `body?`, `footer?` | dialog |
| `progress` | `action`, `id`, `message?`, `detail?`, `value?` | progress bar |
| `custom` | `handler`, `value` | app-defined channel |
| `error` | `id?`, `message` | render error, scoped to an output |

The page served over HTTP becomes a shell: charset, viewport, title,
the client script, and a mount point. No app markup. Everything else
arrives in `welcome`.

## Components

A component is an object with a `component` field. Unknown fields are
ignored, so adding optional properties is backwards compatible.

```json
{
  "component": "text_input",
  "id": "name",
  "label": "Name",
  "value": "",
  "placeholder": "",
  "variant": "default"
}
```

Layout nests:

```json
{"component": "column", "gap": 8, "children": [ ... ]}
```

### The set

**Layout**: `page`, `row`, `column`, `panel`, `tabset` / `tab_panel`,
`conditional_panel`, `spacer`, `divider`

**Inputs**: `text_input`, `password_input`, `textarea_input`,
`number_input`, `select_input`, `checkbox_input`, `radio_buttons`,
`slider_input`, `date_input`, `file_input`, `button`,
`download_button`

**Outputs**: `text_output`, `verbatim_output`, `table_output`,
`plot_output`, `image_output`, `audio_output`, `ui_output`

**Escape hatch**: `raw_html` — what `tag()` now produces. Rendered by
the browser client, reported unsupported by everyone else. This is the
deliberate cost of the redesign: arbitrary markup has no Flutter
equivalent, so anything that must render on both frontends comes from
the set above.

### Output kinds

`output` messages carry a `kind`, which is what the renderer produced:

| kind | value | from |
|---|---|---|
| `text` | string | `render_text()` |
| `verbatim` | string | `render_text()` into a `verbatim_output` |
| `table` | `{header, rows}` | `render_table()` |
| `image` | `{src, width, height}` | `render_plot()` |
| `audio` | `{src, mime, duration?}` | `render_audio()` |
| `ui` | component tree | `render_ui()` |
| `html` | string | `render_html()`, browser-only |

`kind` comes from the renderer, not the placeholder, so the client
never has to infer intent from an element type. Note `image` and
`audio` carry structure rather than a bare string: a native client
needs the dimensions and the MIME type that a browser would sniff.

## Theme

Sent once in `welcome`. A closed set of tokens, not a stylesheet.

```json
{
  "colors": {
    "primary": "#6366f1", "on_primary": "#ffffff",
    "surface": "#ffffff", "background": "#f8fafc",
    "text": "#1e293b", "muted": "#64748b",
    "border": "#e2e8f0", "danger": "#f43f5e", "success": "#10b981"
  },
  "spacing": 4,
  "radius": 8,
  "font": {"body": "Inter", "mono": "JetBrains Mono", "size": 14}
}
```

The browser client emits these as CSS custom properties. A Flutter
client maps them onto `ThemeData`. Apps that want more can still ship
a stylesheet — it just only affects the browser.

## Variants

Every component takes an optional `variant`, drawn from a small closed
set per component. Variants are semantic, never presentational: a
client is free to render `danger` however it likes.

| component | variants |
|---|---|
| `button`, `download_button` | `default`, `primary`, `secondary`, `danger`, `ghost` |
| `panel` | `plain`, `card`, `sidebar` |
| `text_output` | `normal`, `muted`, `strong`, `heading` |
| `divider` | `line`, `labelled` |

Unknown variants fall back to the first listed, with a console warning
rather than an error.

## Capabilities

`hello` carries the component names the client can render:

```json
{"type": "hello", "protocol": 3, "client": "glinty-js/0.5.0",
 "components": ["text_input", "select_input", "..."]}
```

The server does not negotiate. It exposes the list as
`session$capabilities` so an app can branch if it wants to, and
otherwise sends what the app asked for. A client that receives a
component it cannot render draws a visible placeholder naming it.

That is deliberately simpler than negotiation, and more honest: the
failure is visible in the running app rather than silently absent.

## Authentication

Protocol 2 used the session id as the credential, and the README
called it weak. v3 separates them.

`hello` may carry a `token`. `run_app(auth = function(token) ...)`
gates session creation on it; the default accepts everything, which
keeps localhost development frictionless. Upload and download
endpoints are keyed on the token rather than the session id.

**TLS is out of scope for glinty itself.** Base R sockets cannot
terminate it, and adding `openssl` to Imports is a dependency decision
against the tinyverse budget. The supported deployment is a reverse
proxy terminating TLS with glinty bound to loopback. `run_app()`
should default to loopback and require opting into `0.0.0.0`, which is
the right default regardless and would have prevented a secret
exposure on 2026-07-26.

Apple's ATS makes TLS non-negotiable for a mobile client, so this is a
precondition for the Dart client rather than polish.

## What this costs

- `tag()` becomes browser-only. Both existing app migrations lean on
  it for `<details>`/`<summary>`, `<small>`, `<hr>`, the audio player
  and the header link. Those need component equivalents or they stop
  being portable.
- Class-based styling becomes browser-only. `class = "history-item"`
  keeps working in the browser and does nothing elsewhere.
- The initial paint costs a round trip. The page shell arrives, then
  the tree. Server-side rendering could be added back later as an
  optimisation for the browser only.
- Protocol 2 clients stop working. There is one, and it ships in this
  repo.

## Staging

1. Component representation: builders emit components; the browser
   client lowers them to DOM. Everything else unchanged.
2. Bootstrap over the wire: the HTTP response becomes a shell,
   `welcome` carries the tree.
3. Typed outputs: renderers carry `kind` instead of a DOM property.
4. Theme and variants.
5. Auth, loopback default.
6. Only then: the Dart client, in its own repo, against a frozen spec.

Each stage keeps the browser client working. Stage 6 is the first
point at which a second frontend is possible, which is the whole
purpose.
