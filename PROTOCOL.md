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
| `hello` | `protocol`, `client`, `components`, `kinds`, `features`, `token?`, `resume?` | opening frame; declares what this client can render |
| `input` | `id`, `value` | an input changed |
| `event` | `id`, `kind`, `value?` | a click or other discrete event |
| `measure` | `id`, `width`, `height` | a client-sized output's rendered box |
| `ticket` | `id`, `purpose` | request a short-lived upload/download ticket |
| `ack` | `seq` | optional flow control, reserved |

`hello` replaces both `init` and `resume`. It carries `resume` when
reconnecting. It no longer carries harvested input values: under v3
the server sent the tree, so it already knows the defaults.

### Server to client

| type | fields | meaning |
|---|---|---|
| `welcome` | `session`, `protocol`, `theme`, `ui`, `ui_revision`, `resumed?` | the bootstrap: session, theme, and the initial component tree |
| `output` | `id`, `kind`, `value` | an output's current value, including `kind: "ui"` |
| `input_update` | `id`, fields | server-driven input change |
| `ticket` | `id`, `purpose`, `token`, `expires` | short-lived credential for one transfer |
| `modal` | `action`, `title?`, `body?`, `footer?` | dialog |
| `progress` | `action`, `id`, `message?`, `detail?`, `value?` | progress bar |
| `custom` | `handler`, `value` | app-defined channel |
| `error` | `id?`, `message` | render error, scoped to an output |

`welcome.ui` is **canonical**. Every client can rely on receiving the
tree there, and a client that ignores everything else is correct.

A transport **may** additionally deliver the tree ahead of time as an
optimisation. The browser can keep server-rendering the initial markup
into the HTTP response and hydrate it when `welcome` arrives, matching
on a `ui_revision` the server includes in both; a mismatch means the
client discards the pre-render and builds from `welcome`.

An earlier draft required server-side rendering to be deleted and
accepted a round-trip regression on first paint. That was conflating
"the protocol must be able to carry the UI" with "the protocol must be
the only way the UI arrives." There is no reason to make the browser
slower to make Dart possible.

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

**Static content**: `text`, `heading`, `link`, `icon`, `divider`,
`spacer`

These are what `p()`, `span()`, `h1()`–`h4()` and `a()` become. Without
them the migration is not mechanical, because today's apps are full of
them.

**Layout**: `page`, `row`, `column`, `panel`, `tabset` / `tab_panel`,
`conditional_panel`

**Inputs**: `text_input`, `password_input`, `textarea_input`,
`number_input`, `select_input`, `checkbox_input`, `radio_buttons`,
`slider_input`, `date_input`, `file_input`, `button`,
`download_button`

**Outputs**: `text_output`, `verbatim_output`, `table_output`,
`plot_output`, `image_output`, `audio_output`, `ui_output`

**Escape hatch**: `raw_html` — what `tag()` now produces:
`{"component": "raw_html", "html": "<details>..."}`, a single opaque
string. Rendered by the browser client, reported unsupported by
everyone else. This is the deliberate cost of the redesign: arbitrary
markup has no Flutter equivalent, so anything that must render on both
frontends comes from the set above.

### Field schemas

Every component has a fixed field set with declared types and
defaults. Unknown fields are ignored so optional additions stay
backwards compatible; missing required fields are a client-side error,
not a silent default.

| component | required | optional |
|---|---|---|
| `text` | `value: string` | `variant`, `id` |
| `heading` | `value: string` | `level: 1..4` (2), `id` |
| `link` | `value: string`, `href: string` | `external: bool` (false) |
| `icon` | `name: string` | `size: int` (16) |
| `divider` | — | `label: string`, `variant` |
| `spacer` | — | `size: int` (1, in theme spacing units) |
| `row` / `column` | `children: []` | `gap: int`, `align`, `id` |
| `panel` | `children: []` | `variant`, `title: string`, `id` |
| `text_input` | `id` | `label`, `value` (""), `placeholder`, `variant` |
| `password_input` | `id` | `label`, `placeholder` — **never `value`** |
| `select_input` | `id`, `choices: [{value,label}]` | `label`, `selected`, `multiple: bool` |
| `slider_input` | `id`, `min: num`, `max: num` | `label`, `value`, `step` |
| `button` | `id`, `label` | `variant`, `icon` |
| `plot_output` | `id` | `width: int?`, `height: int?`, `alt` |
| `audio_output` | `id` | `controls: bool` (true), `autoplay: bool` (false) |
| `tabset` | `id`, `panels: [{title, children}]` | `selected` |
| `conditional_panel` | `condition`, `children: []` | — |

`password_input` has no `value` field **in the schema**, not merely by
convention. A field that cannot be expressed cannot leak.

### The Flutter column

Every component names the Flutter widget it is expected to lower to.
This is a paper check, and it is the one that actually points at the
target.

flitR cannot serve that purpose. It is a **falsifier, not a
validator**: where it cannot lower something the component is probably
DOM-shaped, which is how `gap` became a number and `spacer` became
theme units. But flitR is more primitive than the DOM in the opposite
direction from Flutter — absolutely-positioned draw ops with layout
computed in R, versus a framework that owns layout, retains widget
state, and has its own focus and text models. **flitR disagreeing is a
signal; flitR agreeing is not a clearance.**

| component | Flutter | note |
|---|---|---|
| `text` | `Text` | variant → `TextStyle` from theme |
| `heading` | `Text` | level → `textTheme.headlineN` |
| `link` | `InkWell` + `Text` | `external` → `url_launcher` |
| `icon` | `Icon` | name → `IconData`; needs a name→icon map |
| `divider` | `Divider` | `labelled` → `Row` with `Expanded` rules |
| `spacer` | `SizedBox` | size × theme spacing |
| `row` / `column` | `Row` / `Column` | `gap` → `spacing` (Flutter 3.27+) or separators |
| `panel` | `Card` / `Container` | variant selects |
| `text_input` | `TextField` | `emit` → `onChanged` vs `onEditingComplete` |
| `password_input` | `TextField(obscureText: true)` | |
| `textarea_input` | `TextField(maxLines:)` | |
| `number_input` | `TextField` + `TextInputType.number` | Flutter has no spinner |
| `select_input` | `DropdownButton` | `multiple` has no direct widget |
| `checkbox_input` | `CheckboxListTile` | |
| `radio_buttons` | `RadioListTile` | |
| `slider_input` | `Slider` | `divisions` = range / step |
| `date_input` | `showDatePicker` | a dialog, not an inline field |
| `file_input` | `file_picker` package | not in the SDK |
| `button` | `FilledButton` etc. | variant selects the constructor |
| `tabset` | `TabBar` + `TabBarView` | retains child state, unlike flitR |

Three of those already flag real work, none of which flitR would have
surfaced: `select_input(multiple = TRUE)` has no single Flutter
widget, `date_input` is a dialog rather than an inline control, and
`file_input` needs a package outside the SDK. `icon` needs a
name-to-`IconData` map that has to exist somewhere.

None are blocking. All are cheaper to know now than after the
vocabulary is frozen.

### Output kinds

`output` messages carry a `kind`, which is what the renderer produced:

| kind | value | from |
|---|---|---|
| `text` | string | `render_text()` |
| `table` | `{header, rows}` | `render_table()` |
| `image` | `{src, width, height}` | `render_plot()` |
| `audio` | `{src, mime, duration?}` | `render_audio()` |
| `ui` | component tree | `render_ui()` |
| `html` | string | `render_html()`, browser-only |

`kind` describes **the value**, and comes from the renderer. How it is
displayed belongs to the receiving component.

So there is no `verbatim` kind. `render_text()` always produces
`text`; `verbatim_output` is the component that chooses to display a
string in a monospace block, exactly as `text_output` chooses not to.
An earlier draft had `verbatim` as a kind derived from its placeholder,
which contradicted the rule this section exists to state.

For the same reason there is no separate `ui` message: `render_ui()`
is an output like any other, so it travels as `output` with
`kind: "ui"`. One message type, not two.

`image` and `audio` carry structure rather than a bare string, because
a native client needs the dimensions and MIME type a browser would
sniff.

### Client measurement

`plot_output()` with NULL dimensions renders at the size the client
gives it. Protocol 2 smuggled this through reserved input names
(`..clientdata_output_<id>_width`), which is DOM-era hackery that a
native client would have to fake.

v3 makes it a message:

```json
{"type": "measure", "id": "scatter", "width": 640, "height": 480}
```

Sent on first layout and on resize, debounced by the client. The
server exposes it to `render_plot()` and re-renders reactively, same
as today, without pretending a measurement is an input.

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

## Capability declaration

Not negotiation. The client states what it can do; the server never
adapts the wire format in response.

```json
{"type": "hello", "protocol": 3, "client": "glinty-js/0.5.0",
 "components": ["text_input", "select_input", "..."],
 "kinds": ["text", "table", "image", "audio", "ui", "html"],
 "features": ["upload", "download", "modal", "progress", "measure"]}
```

Three lists, not one: a client may render every component and still
be unable to accept an `html` output kind or perform an upload.

The server exposes them as `session$capabilities`. A client that
receives something it cannot render draws a visible placeholder naming
it, rather than omitting it silently.

**A caveat that constrains this more than it first appears:** static
UI is built before any client connects. `app(ui = ...)` is evaluated
once, so `session$capabilities` cannot influence it. Only `render_ui()`
output, which is per-session and reactive, can branch on capabilities.

So capability declaration is useful for dynamic content and for
diagnostics, and is *not* a mechanism for shipping a different static
UI to different frontends. An app that needs that writes two `ui`
functions and picks one at `app()` time.

## Authentication

Protocol 2 used the session id as the credential, and the README
called it weak. v3 separates identity from session.

### The seam

`hello` may carry an opaque `token`. `run_app(auth = )` takes a
verifier:

```r
run_app(app, auth = function(token) {
    # NULL rejects the connection; anything else becomes the principal
    list(id = "u_123", email = "troy@cornball.ai")
})
```

The return value lands on `session$principal` and is available to the
app. glinty never parses, stores, or refreshes the token — it holds a
string, hands it to your function, and keeps what comes back. The
default verifier accepts everything, so localhost development stays
frictionless.

That shape is deliberately format-agnostic, because the account model
it has to serve is still a draft. It is not, however, meant to leave
you writing a JWT parser.

### The batteries

For the likely case, glinty ships `jwt_auth()`:

```r
run_app(app, auth = jwt_auth(secret = Sys.getenv("SUPABASE_JWT_SECRET")))
```

It verifies signature, `exp`, and `aud`, then returns the claims with
`sub` as `id`. One line, no JWT knowledge required.

Two honest constraints:

- **HS256 is free.** HMAC-SHA256 comes from `digest`, already an
  Import. No new dependency.
- **RS256 / JWKS needs `openssl`**, which goes in Suggests, and
  `jwt_auth()` errors with a clear install message if asked for an
  asymmetric algorithm without it. Fetching and caching a JWKS is the
  app's job, not glinty's.

If the account model lands somewhere other than JWTs, the seam is
unchanged and `jwt_auth()` is simply unused.

### Uploads and downloads

These are plain HTTP, so they cannot ride the WebSocket's
authentication. Protocol 2 put the session id in the URL, which made
it a bearer credential in browser history and server logs.

v3 issues a **short-lived signed ticket** per transfer: the server
mints it over the WebSocket when the client needs one, scoped to one
session, one resource id, and a few seconds. The bearer token never
appears in a URL, and a leaked ticket expires before it is useful.

### Binding and TLS

**Neither loopback-only binding nor TLS is implementable in glinty
itself**, and the spec should not pretend otherwise.

Base R's `serverSocket(port)` takes no bind address and listens on all
interfaces. There is no argument to pass. A loopback default would
need native code, another server dependency, or network isolation —
so "default to loopback" was wrong in the previous draft and is
withdrawn.

What glinty can do is **say so loudly at startup**, naming the
interface exposure in the same breath as the URL, rather than burying
it in `?run_app`.

The containment belongs to the layer that can actually enforce it:
firewall rules, a container network namespace, or viento's own network
isolation around the allocated port. A reverse proxy alone is not
enough — if the raw glinty port stays reachable, the proxy is simply
one of several ways in.

So the deployment contract is: **glinty warns, authentication gates
the session, and the scheduler isolates the port.** No native code, no
extra dependency, and the one component that can bind selectively is
the one doing it.

TLS is the same story: base R sockets cannot terminate it, and
`openssl` in Imports is a dependency decision against the tinyverse
budget. The supported deployment is a reverse proxy terminating TLS in
front of glinty, with the network scoped by firewall or namespace.

Apple's ATS makes TLS non-negotiable for a mobile client, so a
documented, tested proxy configuration is a precondition for the Dart
client rather than polish.

## Deployment surface

If glinty apps are scheduled as long-running services — viento models
exactly this, with `service` jobs, port resources, a health model and
an authenticated principal — the protocol needs two things it does not
have:

- **A health endpoint.** `GET /healthz` returning session count and
  uptime, so a supervisor can distinguish "listening" from "working"
  without opening a WebSocket.
- **Port from the environment.** An allocated port arrives at runtime;
  `run_app()` should read one before falling back to its default
  rather than requiring the caller to plumb it.

Both are small, and both are much easier to add before a second client
exists than after.

## What this costs

- `tag()` becomes browser-only. Both existing app migrations lean on
  it for `<details>`/`<summary>`, `<small>`, `<hr>`, the audio player
  and the header link. Those need component equivalents or they stop
  being portable.
- Class-based styling becomes browser-only. `class = "history-item"`
  keeps working in the browser and does nothing elsewhere.
- Protocol 2 clients stop working. There is one, and it ships in this
  repo.
- `run_app_native()` stops working at stage 1 and stays broken until
  someone retrofits it. See below.

First paint is **not** a cost: the browser keeps pre-rendering and
hydrating against `ui_revision`, so `welcome` being canonical does not
make it slower.

## Staging

1. **Component representation.** Builders emit components. Two
   lowerings land together: component -> DOM in the browser client,
   and component -> flitR ops in `native_scene.R`.
2. **Bootstrap over the wire.** `welcome` carries the tree; the
   browser keeps pre-rendering and hydrates against `ui_revision`.
3. **Typed outputs.** Renderers carry `kind`; `measure` replaces the
   `..clientdata_output_*` reserved inputs.
4. **Theme and variants.**
5. **Auth, tickets, `/healthz`, port from the environment.**
6. **Then** the Dart client, in its own repo.

### flitR is retrofitted in stage 1, on a strict leash

Two lowerings land together: component → DOM, and component → flitR
ops. flitR is a cheap, already-working second frontend, and its only
job here is to expose DOM-shaped mistakes in the vocabulary while they
are still free to fix. Finding them from Dart — across a repo
boundary, a language barrier and a frozen spec — is not free.

Do not overclaim what it buys. flitR catches **browser bias**, not
Flutter readiness — see "The Flutter column". It is a falsifier, and
nothing about its shape may be allowed back into the schema. flitR has
no live/settle distinction and therefore cannot honour `emit`; `emit`
stays regardless, because Flutter's `onChanged` and
`onEditingComplete` need it.

The scope is deliberately narrow:

- **Direct lowering only.** No bridge through legacy tag trees. A
  bridge would validate the DOM model twice and prove nothing, since
  every component would have already been squeezed through an
  HTML-shaped intermediate before flitR saw it.
- **Only flitR's current subset.** Whatever renders natively today
  keeps rendering. Nothing more.
- **No new flitR widgets**, and no chasing glinty's feature set.
- **Unsupported components stay explicit** — named failure or a
  visible placeholder, never an approximation.
- **Shared fixtures.** One set of component trees, both lowerings
  asserted against it. That is the artifact that makes the check real
  rather than aspirational, and it is the same mechanism stage 6 uses
  for Dart.

This is what freezing flitR means in practice: **feature freeze, not
breakage.** It stops growing; it does not stop working.

### The spec stays draft until two clients agree

Freeze after the browser and the Dart MVP both pass shared golden
fixtures — the same component tree rendering equivalently in each.
The second implementation always exposes assumptions the first one
silently satisfied, and a spec frozen before that is a spec frozen
around the browser's habits.
