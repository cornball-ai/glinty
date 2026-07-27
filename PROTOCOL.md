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
| `event` | `id` | a button press or other discrete event |
| `measure` | `id`, `width`, `height`, `dpr?` | a client-sized output's box, in logical pixels |
| `ticket` | `id`, `purpose` | request a short-lived upload/download ticket |
| `ack` | `seq` | optional flow control, reserved |

`hello` replaces both `init` and `resume`. It carries `resume` when
reconnecting. It no longer carries harvested input values: under v3
the server sent the tree, so it already knows the defaults.

### Server to client

| type | fields | meaning |
|---|---|---|
| `welcome` | `session`, `protocol`, `theme?`, `ui`, `ui_revision`, `resumed?` | the bootstrap: session, theme, and the initial component tree |
| `output` | `id`, `kind`, `value` | an output's current value, including `kind: "ui"` |
| `input_update` | `id`, fields | server-driven input change |
| `ticket` | `id`, `purpose`, `token`, `expires` | short-lived credential for one transfer |
| `modal` | `action`, `title?`, `body?`, `footer?` | dialog |
| `progress` | `action`, `id`, `message?`, `detail?`, `value?` | progress bar |
| `custom` | `handler`, `value` | app-defined channel |
| `error` | `id?`, `message` | render error, scoped to an output |

`welcome.ui` is **canonical**. Every client can rely on receiving the
tree there, and a client that ignores everything else is correct.

### ui_revision and hydration

A transport **may** deliver the tree ahead of time as an
optimisation. The browser keeps server-rendering the initial markup
into the HTTP response and adopts it when `welcome` arrives.

`ui_revision` is **opaque to clients**: a token to compare for string
equality against the one in the pre-rendered document, nothing more.
A client never computes it, parses it, or checks its shape --
reproducing the server's serialization in a second language is
exactly the kind of cross-language agreement this protocol exists to
avoid needing.

Server-side it is the SHA-256 of the canonical JSON serialization of
`welcome.ui`, lowercase hex. The server computes it once, embeds it
in the pre-rendered document as
`<meta name="g-ui-revision" content="...">`, and repeats it in
`welcome`. Canonical means the same serializer that produces the wire
form: field order as the schema declares, absent optionals omitted,
no insignificant whitespace. All of that binds the server alone; a
future server could switch algorithms without any client noticing.

Hydration has four invariants. They exist because the failure modes
are silent, and each is asserted rather than assumed:

1. **Event handlers are never duplicated.** The pre-rendered DOM
   already carries `data-g-target`; adopting it must not attach a
   second listener. Delegation from the root makes this structural
   rather than careful.
2. **No spurious initial inputs.** Adoption is not user interaction.
   A hydrating client sends nothing on adoption -- the server built
   the tree and already knows every default. Protocol 2 harvested
   inputs at init; v3 must not, or every reload writes the whole
   form back. Measurements of client-sized outputs are the one thing
   a client still reports after adopting, because a rendered box is
   the one thing the server cannot know from the tree.
3. **A revision mismatch rebuilds.** If the meta tag and `welcome`
   disagree, the pre-render is from a different tree: discard it and
   build from `welcome`. Patching a stale DOM is how a hydration bug
   becomes a data bug.
4. **A protocol mismatch is visible.** A client that speaks 3 and
   receives 4 refuses and says so on screen, rather than rendering
   the half it recognises.

An earlier draft required server-side rendering to be deleted and
accepted a round-trip regression on first paint. That conflated "the
protocol must be able to carry the UI" with "the protocol must be the
only way the UI arrives." There is no reason to make the browser
slower to make Dart possible.

## Shared artifacts

Two generated files are the contract. Both are produced from the R
definitions and read directly by every client, so neither a
description in this document nor a client's own reading of it is what
conformance is measured against.

| file | generated by | covers |
|---|---|---|
| `inst/fixtures/components.json` | `component_fixtures()` | what a tree looks like: every component, once, with its fields populated |
| `inst/fixtures/transcripts.json` | `wire_transcripts()` | what a conversation looks like: frames in order, for the exchanges above |

A client that renders every component and fumbles the opening
exchange is broken in a way no component fixture would notice, which
is why the second file exists. The transcripts pin `hello`/`welcome`,
both hydration outcomes, the protocol refusal, an input driving an
output, and a `measure` driving an image.

Both files are checked in and both have a test on each side asserting
the file matches the definition it came from, so they cannot fall
behind. Adding a fixture or a transcript obliges every client to
answer for it.

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

Every component names the Flutter widget it lowers to. This started
as a paper check; dart/glinty_flutter now executes it against the
same fixture file, so the table below is a summary of behaviour
rather than an intention.


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
| `tabset` | `TabBar` + `TabBarView` | both retain hidden child state |

Three of those flagged real work before any Dart existed, and all
three still hold: `select_input(multiple = TRUE)` has no single
Flutter widget, `date_input` is a dialog rather than an inline
control, and `file_input` needs a package outside the SDK.

`icon` needed a name-to-`IconData` map, which dart/glinty_flutter now has.
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
{"type": "measure", "id": "scatter", "width": 640, "height": 480,
 "dpr": 2}
```

**Units: logical pixels.** `width` and `height` are the element's
box in logical pixels -- CSS pixels in the browser, Flutter's native
logical pixels in Flutter -- rounded to integers. Both frameworks
already speak this unit, which is the point: neither side ever
converts. Physical pixels never cross the wire as dimensions.

**`dpr` is the device pixel ratio**, how many physical pixels back
one logical pixel (`window.devicePixelRatio`,
`MediaQuery.devicePixelRatio`). Optional; a missing `dpr` means 1.
The server rasterizes at `width x dpr` by `height x dpr` physical
pixels with resolution scaled by the same factor, and reports the
image's *logical* size back in the output value, so text and lines
keep their size while the raster matches the screen. That is what
makes a plot sharp on a 2x display instead of upscaled soup.

An `image` output's value is therefore
`{src, width, height}` in logical pixels: the client sets the
display size from it and never inspects the raster.

**When to send, when not to:**

- On first layout, on resize, and whenever a measured element
  becomes visible or newly exists (a tab switch, a conditional panel
  showing, dynamic UI arriving). Debounced by the client.
- Only when the triple `(width, height, dpr)` differs from the last
  one this client sent for that id. Dedup is per id, client-side.
- **Never for a box that cannot be seen.** A hidden or detached
  element measures zero; zero is not a size, it is the absence of
  one, and reporting it would have the server render a 0x0 plot for
  an element that is about to come back. The server keeps the last
  real measurement instead.
- A client that rebuilds its UI re-reports only what changed. The
  server's measurements survive rebuilds because they are session
  state, not element state.

**Server side:** last write wins, per id. A measurement for an id
the server has no renderer for is stored and harmless -- the output
may be about to exist (dynamic UI races layout) -- but bounded: a
session holds at most 256 measured ids, so a client inventing ids
cannot grow memory without limit. Measurements reach renderers as
reactive reads, so a new measurement re-renders exactly the outputs
that depend on it, and fixed-size plots read the dpr from the same
box. The reserved `..clientdata_output_*` input names are gone, and
input ids starting with `..` are rejected so a client cannot spoof
measurement state through the input channel.

**Resource caps.** A measurement sizes a raster the server will
allocate, so the server ignores wholesale anything outside: logical
sides in [1, 8192], dpr in (0, 8], physical sides at most 16384, and
physical area at most 32 megapixels (a 4K display at dpr 2, with
room). A hostile client gets a stale plot, not an allocation.

## Theme

Sent once in `welcome`. A closed set of tokens, not a stylesheet.

```json
{
  "colors": {
    "primary": "#6366f1", "on_primary": "#ffffff",
    "surface": "#ffffff", "background": "#f8fafc",
    "text": "#1e293b", "muted": "#64748b",
    "border": "#e2e8f0", "danger": "#f43f5e"
  },
  "spacing": 4,
  "radius": 8,
  "font": {"body": "Inter", "mono": "JetBrains Mono", "size": 14}
}
```

The browser client emits these as CSS custom properties (and the
served page carries the same tokens inline, so the first paint is
themed before any socket work). A Flutter client maps them onto
`ThemeData`. Apps that want more can still ship a stylesheet — it
just only affects the browser.

`theme` is omitted when the app never set one, and each frontend's
own defaults apply — in the browser that includes the stylesheet's
automatic dark mode. A supplied theme is exact: one token set, no
automatic dark variant, because the server cannot know which the
user prefers and silently restyling a declared palette would be
inference magic.

Each font token names **one family**, or a CSS generic (`system-ui`,
`ui-monospace`, `monospace`, ...) meaning the platform's own face
for that role. The role is preserved everywhere: the browser
resolves generics natively, and Flutter lowers each one to a
per-platform fallback stack (the generic name itself, which Android
registers as a real family, then faces Apple and desktop platforms
ship), so a monospace body stays mono and a serif mono token goes
serif rather than collapsing to sans. A custom family leads its
role's stack and only takes effect where the client has the font —
a name a client cannot resolve degrades within its role, silently,
which is how fonts have always failed.
Values are limited to letters, digits, spaces and hyphens: they are
interpolated into a style block, so the character set is the
injection surface, and the server and client enforce the same rule
so the first paint and the hydrated state cannot diverge.

## Variants

Every component takes an optional `variant`, drawn from a small closed
set per component. Variants are semantic, never presentational: a
client is free to render `danger` however it likes.

| component | variants |
|---|---|
| `button`, `download_button` | `default`, `primary`, `secondary`, `danger`, `ghost` |
| `panel` | `plain`, `card`, `sidebar` |
| `text` | `normal`, `muted`, `strong`, `heading` |
| `text_output` | `normal`, `muted`, `strong` |
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

A refused hello (verifier returned NULL, or threw — failing open on
an exception would make a bug in the verifier a bypass of it) gets
one id-less `error` frame naming the reason, and the socket closes.
Clients draw that refusal; the browser shows it the way it shows a
protocol mismatch. The gate sits before any session exists, resume
included: a token that no longer verifies does not get its old
session back. In the browser, an app script sets
`window.GLINTY_AUTH` to the token its login flow produced before
`DOMContentLoaded`, and hello carries it.

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

v3 issues a **short-lived single-use ticket** per transfer: the
server mints it over the WebSocket when the client needs one, scoped
to one session, one resource id, one purpose, and a few seconds
(`expires` is a relative TTL). Redeeming a ticket consumes it,
success or not -- a retry asks for a new one over the socket, and a
replayed URL gets nothing. The session id never appears in a URL,
and a leaked ticket is dead within seconds either way.

The ticket is an opaque token held server-side, not a signed
payload: a single-process server is the authority on what it issued,
and a store it can consult beats cryptography it could get wrong.
Signing would buy verification by a process that did not mint the
ticket, which is not this architecture. (An earlier draft said
"signed"; this is the honest replacement.)

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

1. **Component representation.** *(done)* Builders emit components;
   the browser client lowers them to DOM. The Flutter client in
   `dart/glinty_flutter` lowers the same trees to widgets. Both
   suites read `components.json`; the wire transcripts and
   `ui_revision` land here too, so stage 2 has something to conform
   to before it is written.
2. **Bootstrap over the wire.** *(done)* `welcome` carries the tree;
   the browser keeps pre-rendering and hydrates against
   `ui_revision`. The server seeds each session's inputs from the
   tree it built, so `hello` carries no values and adoption sends
   nothing. The browser grew the component renderer this required
   (welcome rebuilds, `render_ui()`, modal bodies all build from
   component trees now).
   **Gate, met:** the two browser-side hydration tests -- one press
   producing one frame across adoption, and adoption emitting
   nothing -- run in `tools/jsbridge.js` against the shared
   transcripts, wired into CI as the `browser` job. They are the two
   invariants Flutter cannot stand in for, because only the browser
   adopts pre-rendered markup. All four invariants are
   mutation-tested: breaking any one of them fails its check.
3. **Typed outputs.** *(done)* `output` messages carry `kind`
   (`update` and its DOM `property` are gone from the wire, as is
   `update_input` in favour of `input_update`), and `measure`
   replaces the `..clientdata_output_*` reserved inputs -- logical
   pixels plus device pixel ratio, deduplicated per id, zero boxes
   never sent, resource-capped server-side, spoofing via
   `..`-prefixed inputs rejected. Fixed-size plots keep their size
   but take the client's dpr, so they stay sharp too. The dpr dedup
   and the zero-box guard are mutation-tested; the browser layers
   `ResizeObserver` over the manual re-measure triggers where it
   exists.
4. **Theme and variants.** *(done)* `app(theme = app_theme(...))`
   declares a token set; `welcome` carries it, the served page
   embeds the same tokens in a `#g-theme` style block so the first
   paint is themed, and the client updates that same block on
   welcome -- never inline root properties, so the cascade (tokens
   beat glinty.css, app CSS beats tokens) holds identically before
   and after the socket connects. Flutter consumes every token:
   colors onto the scheme (`muted` -> `onSurfaceVariant`, `danger`
   -> `error`), radius onto cards and buttons, fonts including mono,
   spacing feeding spacer() on both sides. A themeless app keeps
   each frontend's own defaults, browser dark mode included. The
   stylesheet was rewired to the token set and the v3 class
   inventory while there -- `--g-space` had never been defined
   (spacers collapsed to zero) and several stage 1 classes had no
   rules. Unknown variants fall back to the first listed with a
   warning, in both lowerings, for every variant-bearing component.
5. **Auth, tickets, `/healthz`, port from the environment.** *(done)*
   `run_app(auth = )` verifies the hello token and the result becomes
   `session$principal`; `jwt_auth()` ships the HS256 batteries with
   RS256 behind a Suggests on openssl, alg-pinned against confusion.
   Transfers ride single-use tickets minted over the socket -- the
   session id is out of every URL, and the browser's download
   buttons, dead since stage 1 (the lowering never emitted
   `data-g-download`), work again through them. `GET /healthz`
   reports sessions and uptime; `run_app(port = NULL)` reads
   GLINTY_PORT then PORT before falling back to 8080; startup names
   the all-interfaces exposure in the same breath as the URL. The
   auth gate is proven over a real socket in the e2e suite: no
   token refused and closed, wrong token refused, right token
   welcomed with the principal readable by the app.
6. **Then** the Flutter client grows a transport and becomes an app
   rather than a renderer.

### flitR is retired, not retrofitted

An earlier draft had flitR retrofitted alongside the browser in stage
1, as a falsifier: a cheap second lowering to catch DOM-shaped
mistakes before Dart existed to catch them properly.

**Dart exists now.** dart/glinty_flutter renders every fixture as
real Flutter widgets, in the framework the protocol was designed for.
Keeping a proxy once you have the thing it stood in for is just a
third lowering to maintain, and Flutter desktop covers Linux, macOS
and Windows with real widgets, real text input and an accessibility
tree flitR cannot offer.

So there are two lowerings, not three: component → DOM here, and
component → Flutter widgets in dart/glinty_flutter. `run_app_native()` and
`native_scene.R` stay on protocol 2 and stop working when stage 1
switches the builders over. flitR is archived.

The falsifier reasoning was right while Dart was hypothetical. It
stopped being right the moment the Flutter SDK was installed, which
is a good reason to change a decision rather than a bad one.

### The spec stays draft until two clients agree

Freeze after the browser and the Dart MVP both pass shared golden
fixtures — the same component tree rendering equivalently in each.
The second implementation always exposes assumptions the first one
silently satisfied, and a spec frozen before that is a spec frozen
around the browser's habits.
