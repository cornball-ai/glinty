# glinty protocol v3

Status: **frozen**. On `main`, unreleased. Three independent
lowerings render it: R to HTML for the server-rendered first paint,
`inst/www/glinty.js` to DOM, and `dart/glinty_flutter` to Flutter
widgets. Protocol 2 is gone.

Frozen means what already exists does not move. Clients may still
grow — the Flutter one refuses markup and `date_input` by name,
and that is implementation work behind a stable wire, not a
protocol gap.

**The test is not "is it additive". It is: what does a client that
ignores this do?**

- If it fails *visibly* — a named placeholder, a warning, a layout
  that is wrong but obviously so — the addition is safe. The
  honest-failure rule is what buys this.
- If it fails *silently* — the app looks fine and does the wrong
  thing — it is a version bump, however optional the field is.

By that test:

| addition | an older client... | safe? |
|---|---|---|
| a component | draws a placeholder naming it | yes |
| a variant | falls back to the first listed, warns | yes |
| a feature | the server sees it undeclared | yes |
| `grow`, `width` | lays out wrong — possibly *plausibly* wrong | borderline |
| `link.children` | draws a link with no content | **no** |
| `button.value` | reports a press with no value, and the handler reads nothing | **no** |

`grow` and `width` are marked borderline rather than safe on purpose:
a layout that is merely *wrong* can still look plausible, and "you
would notice" is a weaker guarantee than a placeholder saying the
name of what is missing. Treat borderline as needing the bump.

Two earlier drafts of this paragraph were both wrong. The first said
adding a component was a v4 conversation, which is stricter than the
design requires. The second said any optional field was safe because
an older client ignores it — but *ignoring* `button.value` is exactly
the silent wrong answer this protocol refuses everywhere else. Being
optional is not the property that matters.

**Why v3.1 did not bump the version anyway.** Protocol 3 has never
been released: every published glinty (0.0.1 through 0.0.4) speaks
protocol 2, and 3 exists only on `main`. Both protocol-3 clients ship
in this repository and both implement v3.1. There is no client
anywhere that could receive `button.value` and drop it. The additions
below are safe *because no older protocol-3 client exists*, not
because optional fields are safe in general.

That justification expires the moment protocol 3 ships. After that,
any addition that is not clearly in the "fails visibly" column bumps
the version, or gates itself behind a declared capability. There is
no third option where it is fine because the field is optional.

### v3.2

Protocol still 3. One addition, driven by an NLE: `shortcut`, a key
binding, described under "The set" below.

**Why this one is safe by the test at the top.** It is a new component,
not a new field, and an unknown component renders `[unsupported
component: shortcut]` in both lowerings — visible and named, never
silent. That is the column an addition has to be in. It is also the
mildest possible gap: a shortcut is an accelerator for something a
button already does, so a client that cannot bind it loses the
shortcut, not the action.

The alternative was a page-level `keys =` argument beside `css` and
`js`. Those live outside the component tree because they are
browser-only transport — a Flutter client has no use for a stylesheet.
A key binding is not that. Flutter has `HardwareKeyboard` and
`PhysicalKeyboardKey`; a terminal frontend has its own key loop.
Something every frontend must implement belongs in the vocabulary, and
putting it there is what obliged the Dart lowering to answer for it.

### v3.1

Protocol still 3. Additions, driven by porting two real apps onto the
frozen vocabulary — the third consumer after the browser and Flutter,
and the first that had to *build* a UI with it rather than render one:

- `grow` and `width` on `row`, `column` and `panel`. A fixed sidebar
  beside a filling centre could not be said. Not a CSS import: CSS
  spends it as flex-grow and flex-basis, Flutter as `Expanded(flex:)`
  and `SizedBox(width:)`, and every layout system has the pair.
- `image`, a picture that is part of the UI. `image_output` is a slot
  the server fills; a logo in a header is not that.
- `collapse`, a section the user can fold. `<details>` in the browser,
  `ExpansionTile` in Flutter — native to both, so neither has to
  rebuild it out of a button and a hidden div.
- `children` on `link`, so a link can wrap a logo. `value` stopped
  being required and the two are now alternatives; a link carrying
  neither is refused, because it would be an invisible clickable
  nothing.
- `value` on `button`, carried on the event it emits. One server
  handler then serves a whole list — the press says which row. Every
  row needing its own id and its own observer is impossible when the
  rows are built per render, which is what both apps' history lists
  do.
- `icon`'s `name` became a closed set. It had been free text, so a
  name no frontend drew rendered nothing in the browser and a
  question-mark glyph in Flutter — silent in both at once.

Two checked-in artifacts are the contract, generated from R and read
by all three test suites: `inst/fixtures/components.json` (every
component in the schema, at least once) and
`inst/fixtures/transcripts.json` (the frames of an exchange, in
order). A component only counts as frontend-neutral once more than
one lowering has had to answer for it.

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
| `event` | `id`, `value?` | a button press or other discrete event; `value` is present only when the button declared one |
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
| `ticket` | `id`, `purpose`, and either `token` + `expires` or `error` | the answer to a ticket request: a credential, or why not |
| `modal` | `action`, `title?`, `body?`, `footer?` | dialog |
| `progress` | `action`, `id`, `message?`, `detail?`, `value?` | progress bar |
| `custom` | `handler`, `value` | app-defined channel |
| `error` | `id?`, `message` | a renderer failed, scoped to that output; id-less before `welcome` means the connection was refused |

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
ignored. That makes an addition *renderable* by an older client; it
does not make it *correct* there — see the compatibility test at the
top of this document, which is about what ignoring the field does.

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

**Static content**: `text`, `heading`, `link`, `icon`, `image`,
`divider`, `spacer`

These are what `p()`, `span()`, `h1()`–`h4()` and `a()` become. Without
them the migration is not mechanical, because today's apps are full of
them.

**Layout**: `page`, `row`, `column`, `panel`, `collapse`, `tabset` /
`tab_panel`, `conditional_panel`

**Inputs**: `text_input`, `password_input`, `textarea_input`,
`number_input`, `select_input`, `checkbox_input`, `radio_buttons`,
`slider_input`, `date_input`, `file_input`, `button`,
`download_button`, `shortcut`

`shortcut` is a button you cannot see: it emits the same `event` frame,
so one server handler serves the visible control and its accelerator
under one id. It renders nothing and occupies no space.

```json
{"component": "shortcut", "id": "play", "key": "space",
 "ctrl": false, "shift": false, "alt": false,
 "typing": false, "hold": false}
```

`key` is a token from a closed set — letters, digits, `f1`–`f12`, and
the named keys an editor needs — for the same reason `icon.name` is. A
browser calls one key `"Escape"` and Flutter calls it
`LogicalKeyboardKey.escape`; a name each lowering guesses at produces a
shortcut that never fires, which is invisible in a way a missing button
is not. Both lowerings carry the whole set, asserted against it.

Modifiers are three booleans rather than a packed `"ctrl+shift+k"`
string. The alternative is every frontend parsing that spec for itself
and two of them disagreeing about a case nobody wrote a test for; the R
constructor parses once. `ctrl` also means Command: an app that means
"the platform's command modifier" should say it once, and each frontend
knows which key that is locally.

The key named is the PHYSICAL key, so `shift`+`1` is that and never
`"exclam"`, and a binding survives a layout where the character would
not.

Two fields exist because both defaults are traps. `typing` is false by
default, so a bare `d` does not delete a clip halfway through typing a
filename; `escape` and the function keys usually want it true. `hold`
is false by default, so a held `space` does not fire play sixty times;
a nudge wants it true.

A declared shortcut takes the keypress — the frontend's own binding for
it does not also run. Bind `ctrl+s` and it saves the project rather
than offering to save the page.

The binding lives in the tree, not in a registry beside it. A rebuilt
UI then has exactly the shortcuts its new tree declares, with none left
over from the old one — the drift a `bind_key()` call could not avoid.

**Outputs**: `text_output`, `verbatim_output`, `table_output`,
`plot_output`, `image_output`, `audio_output`, `video_output`,
`ui_output`

**Escape hatch**: `raw_html` — what `tag()` now produces:
`{"component": "raw_html", "html": "<details>..."}`, a single opaque
string. Rendered by the browser client, reported unsupported by
everyone else. This is the deliberate cost of the redesign: arbitrary
markup has no Flutter equivalent, so anything that must render on both
frontends comes from the set above.

### Field schemas

Every component has a fixed field set with declared types and
defaults. Missing required fields are a client-side error, not a
silent default. Unknown fields are ignored — which, again, is not the
same as safe to add.

| component | required | optional |
|---|---|---|
| `text` | `value: string` | `variant`, `id` |
| `heading` | `value: string` | `level: 1..4` (2), `id` |
| `link` | `href: string`, and one of `value: string` or `children: []` | `external: bool` (false) |
| `icon` | `name`: one of `play`, `stop`, `rotate`, `trash`, `microphone`, `bookmark`, `download`, `upload` | `size: int` (16) |
| `divider` | — | `label: string`, `variant` |
| `spacer` | — | `size: int` (1, in theme spacing units) |
| `page` | `children: []` | `title` ("glinty app"), `width`: `content` \| `full` (`content`), `id` |
| `row` | `children: []` | `gap: int`, `align`: `start` \| `center` \| `end` \| `stretch`, `grow: int`, `width: int`, `id` |
| `column` | `children: []` | `gap: int`, `grow: int`, `width: int`, `scroll: bool` (false), `id` |
| `panel` | `children: []` | `variant`, `title: string`, `grow: int`, `width: int`, `fill: bool` (false), `id` |
| `image` | `src: string` | `alt` (""), `width: int`, `height: int` |
| `collapse` | `children: []`, `title: string` | `open: bool` (false), `id` |
| `text_input` | `id` | `label`, `value` (""), `placeholder`, `variant` |
| `password_input` | `id` | `label`, `placeholder` — **never `value`** |
| `select_input` | `id`, `choices: [{value,label}]` | `label`, `selected`, `multiple: bool` |
| `radio_buttons` | `id`, `choices: [{value,label}]` | `label`, `selected: string` |
| `slider_input` | `id`, `min: num`, `max: num` | `label`, `value`, `step` |
| `button` | `id`, `label` | `variant`, `icon`, `value: string` |
| `plot_output` | `id` | `width: int?`, `height: int?`, `alt` |
| `audio_output` | `id` | `controls: bool` (true), `autoplay: bool` (false) |
| `video_output` | `id` | `controls: bool` (true), `autoplay: bool` (false), `muted: bool` (false), `loop: bool` (false) |
| `tabset` | `id`, `panels: [{title, children}]` | `selected` |
| `conditional_panel` | `condition`, `children: []` | — |

`password_input` has no `value` field **in the schema**, not merely by
convention. A field that cannot be expressed cannot leak.

`select_input` is the one component whose value type depends on a
field rather than only on the component. With `multiple: false`,
`selected` is a bare string and so is the `input` value it reports.
With `multiple: true`, both are an **array at every length** —
including one element and none:

```json
{"component": "select_input", "id": "tags", "multiple": true,
 "selected": ["a"], "choices": [{"value": "a", "label": "Alpha"}]}
```

`["a"]`, not `"a"`. A one-element selection that collapses to a bare
string makes a client parse a list on Tuesday and a string on
Wednesday, and every lowering then grows its own guess about which
it got. The same rule holds for `input` and `input_update`.

### The Flutter column

Every component names the Flutter widget it lowers to. This started
as a paper check; dart/glinty_flutter now executes it against the
same fixture file, so the table below is a summary of behaviour
rather than an intention.


| component | Flutter | note |
|---|---|---|
| `text` | `Text` | variant → `TextStyle` from theme |
| `heading` | `Text` | level → `textTheme.headlineN` |
| `link` | `InkWell` + `Text` or children | `external` → `url_launcher` |
| `icon` | `Icon` | name → `IconData`; needs a name→icon map |
| `divider` | `Divider` | `labelled` → `Row` with `Expanded` rules |
| `spacer` | `SizedBox` | size × theme spacing |
| `page` | `Column` | `width` is a viewport-layout hint; native keeps its own padding |
| `row` / `column` | `Row` / `Column` | `gap` → separators; `grow` → `Expanded`, `width` → `SizedBox`; `align: stretch` → `IntrinsicHeight`; `scroll` → `SingleChildScrollView` |
| `panel` | `Card` / `Container` | variant selects; `fill` → a max-size `Column` whose grown children take `Expanded` |
| `text_input` | `TextField` | `emit` → `onChanged` vs blur/submit |
| `password_input` | `TextField(obscureText: true)` | |
| `textarea_input` | `TextField(maxLines:)` | |
| `number_input` | `TextField` + `TextInputType.number` | Flutter has no spinner; bounds show as helper text |
| `select_input` | `DropdownButton`, or `FilterChip`s | `multiple` has no dropdown; chips carry the list |
| `checkbox_input` | `CheckboxListTile` | |
| `radio_buttons` | `RadioGroup` + `RadioListTile` | |
| `slider_input` | `Slider` | `divisions` = range / step; `settle` reports on `onChangeEnd` |
| `date_input` | `showDatePicker` | a dialog, not an inline field: **refused by name** |
| `file_input` | `file_picker` package | not in the SDK: **refused by name** |
| `button` | `FilledButton` etc. | variant selects the constructor |
| `download_button` | `FilledButton` + ticket request | disabled without an `onDownload` embedder callback |
| `tabset` | `TabBar` + `TabBarView` | both retain hidden child state |
| `conditional_panel` | `Offstage` | hiding keeps the subtree, and its state, alive |
| `text_output` / `verbatim_output` / `table_output` | `Text` / mono `Container` / `Table` | a kind they cannot draw is named, not stringified |
| `plot_output` | `LayoutBuilder` + `Image.memory` | always reports, fixed size included; a declared axis wins, an unbounded height becomes 4:3 |
| `image` | `Image.memory` / `Image.network` | data:, http(s), or relative resolved against the server address |
| `collapse` | `ExpansionTile` | `open` becomes `initiallyExpanded` |
| `image_output` | `Image.memory` / `Image.network` | sized from the value's logical `width`/`height`; data: and http(s) only, any other scheme is named |
| `ui_output` | the same `build()`, on a subtree that arrived as a value | seeds the input store the way `welcome` does, and takes those inputs back when the slot stops carrying them |
| `audio_output` | the embedder's player, through `audioBuilder` | src resolved, `mime` passed on; without a builder the slot names the gap, and `hello` does not claim the component |
| `video_output` | the embedder's player, through `videoBuilder` | the same seam as audio (video_player, media_kit: the embedder's pick); src and poster resolved, `mime` passed on |
| `file_input` | the embedder.s picker and POST, through `onUpload` | glinty owns the ticket in between, and asks for it only once files are in hand |
| `html_output`, `raw_html` | — | **refused by name**; see below |

Of the three this table flagged before any Dart existed, one turned
out not to be a gap and two hold. `select_input(multiple = TRUE)` has
no single Flutter widget and does not need one: the value is a list,
and a `Wrap` of `FilterChip`s carries a list. `date_input` is still a
dialog rather than an inline control, so it is refused by name.


That one, plus the markup pair below, is the whole refusal list.
`plot_output`, `ui_output`, `audio_output` and `file_input` were all
on it once and are not now.

`icon` needed a name-to-`IconData` map, which dart/glinty_flutter now
has.

The rest of the refusals are deliberate rather than pending.
`raw_html` and `html_output` carry markup, which has no Flutter
equivalent by design -- the first in the tree, the second as a value.

`audio_output` is neither refused nor built in. Playing sound needs a
platform plugin, and a client with one dependency does not take on an
audio engine that every app using it would inherit. It renders
through `audioBuilder`, the same seam `onLink` and `onDownload` use,
and a client without one leaves `audio_output` out of its `hello`
rather than claiming a component it can only draw a placeholder for.
**Declaring what is wired, not what could be, is the rule** -- the
same reason the `download` feature is conditional.

None are blocking. All are cheaper to know now than after the
vocabulary is frozen.

A word on who sizes a plot. `measure` says the client picks, so an
unbounded height is the client's to answer, not the server's. Flutter
lays a `Column` out with an infinite main axis, so a responsive plot
is routinely asked how tall it wants to be; it answers 4:3 off the
measured width, which is the ratio the browser's CSS commits to for
the same case. Neither answer is in the protocol, and neither should
be.

**A fixed-size plot is measured too.** The size is only half of what
a measurement carries; the other half is the device pixel ratio,
which the app cannot know and the server needs. `plot_output(width =
400, height = 300)` that never reports is rasterized at 400x300 and
drawn on a 2x screen at half the resolution it should be — the app
said how big, not how sharp. Both clients report every plot for this
reason, and the dedup means a fixed one reports once.

### Frames beyond the tree

Three message types are about the app rather than parts of it, and
both clients draw all three:

| frame | browser | Flutter |
|---|---|---|
| `modal` | an overlay built from the body tree | an overlay `Card` behind a scrim |
| `progress` | a stack of `.g-progress` bars | a stack of `LinearProgressIndicator`s |
| `custom` | the handler registered with `Glinty.addCustomMessageHandler()` | the handler passed as `GlintyApp(customHandlers:)` |

A `custom` frame naming a handler nothing registered is warned about
in the browser console and named on screen in Flutter. The same rule
as an unsupported component: an app whose client half was never
ported looks like it works and quietly does part of what it says.

### The one reserved id

`..modal_close`, which `modal_button()` builds. A button carrying it
dismisses the open dialog **locally** and reports nothing — the
Cancel case, where the server does not need to hear that a question
was declined. Every other button reports.

It is reserved rather than app-chosen because the server refuses ids
opening with `..` on the input path, so no app can collide with it.
Both lowerings read it: the browser marks the button with
`data-g-modal-close` and omits the event binding, Flutter checks the
id and wires the press to a local dismissal. A magic string either
side does not know is a button that renders and does nothing.

### Output kinds

`output` messages carry a `kind`, which is what the renderer produced:

| kind | value | from |
|---|---|---|
| `text` | string | `render_text()` |
| `table` | `{header, rows}` | `render_table()` |
| `image` | `{src, width, height}` | `render_plot()` |
| `audio` | `{src, mime, duration?}` | `render_audio()` |
| `video` | `{src, mime, poster?, duration?}` | `render_video()` |
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

`video` follows audio's shape with one deliberate difference: its
`src` is a URL, never embedded bytes. Seeking works by byte-range
requests against a URL -- which the static file server answers with
206s -- and a data URI has no ranges to ask for. The server refuses
to embed a video file rather than shipping one that plays but cannot
scrub. Invalidation is by URL: a re-rendered cut arrives under a new
name, because clients cache by the old one. `poster` is one image
and may be a data URI.

### Video playback

A new output value *replaces* the video; driving the player that is
already there is its own message:

```json
{"type": "video_update", "id": "preview", "current_time": 1.5,
 "playing": true}
```

Sent by `update_video()`. Both fields are optional and an absent
field leaves that half of the playback state alone: a seek does not
decide whether to play, a pause does not move the position. The
shape that wants it is an external playhead -- a timeline, a
transport slider -- kept in sync with a preview player.

A `playing: true` may still be refused by the client (browsers block
unmuted playback before the user has interacted with the page); a
refusal leaves the player paused and is the client's to report. The
browser client declares the `video_control` feature; a client
without it ignores the message the way every client ignores message
types it does not know.

The reporting direction -- the component telling the server its
position and playing state -- is deliberately absent for now; it is
input-shaped and wants designing as one.

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
| `text` | `normal`, `muted`, `strong`, `heading`, `mono`, `small` |
| `text_output` | `normal`, `muted`, `strong`, `mono`, `small` |
| `divider` | `line`, `labelled` |

Unknown variants fall back to the first listed, with a console warning
rather than an error.

## Capability declaration

Not negotiation. The client states what it can do; the server never
adapts the wire format in response.

```json
{"type": "hello", "protocol": 3, "client": "glinty-js/0.5.0",
 "components": ["text_input", "select_input", "..."],
 "kinds": ["text", "table", "image", "audio", "video", "ui", "html"],
 "features": ["upload", "download", "modal", "progress", "measure",
              "video_control"]}
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
Every client draws that refusal the way it draws a protocol
mismatch. The gate sits before any session exists, resume included:
a token that no longer verifies does not get its old session back.
In the browser, an app script sets `window.GLINTY_AUTH` to the token
its login flow produced before `DOMContentLoaded`, and hello carries
it.

The first frame on a socket must be a well-formed `hello` (type and
a numeric protocol). Anything else is refused the same way, before
the verifier runs and before any session exists.

A client decides "is this id-less error a refusal?" by whether the
socket that sent hello is still waiting for its welcome — not by
whether it has ever connected. Refusals happen on reconnects, where
a token that worked an hour ago has expired, and a client keyed to
"first connection only" would read that as an ordinary error and
retry forever against a server that will never let it in.

**Resume is principal-bound.** Authentication ties a session to an
identity, and resume honours the tie: the freshly verified
principal's `id` must be non-NULL and identical to the session's.
A valid token for user B plus user A's session id gets B a fresh
session, never A's replayed outputs. A verifier that returns
principals without `id`s gives resume nothing to bind to, so
authenticated resume is refused for them rather than cross-linked.
Without auth configured there is no identity to bind, and the
session id alone remains the documented, weak resume credential.

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

HS256 uses HMAC-SHA256 from `digest`; RS256 uses `openssl`. Both are
Imports, so neither costs the app an install. Fetching and caching a
JWKS is the app's job, not glinty's.

**Why `openssl` is an Import and not a Suggests.** Session ids and
transfer tickets are bearer credentials, minted on every platform
glinty runs on, and base R has no CSPRNG. An earlier draft had
`openssl` optional with `/dev/urandom` as the fallback — which is
not cross-platform, so a Windows server would have had no source at
all. A dependency that is always required is an Import; hiding it
behind `requireNamespace()` would only make the list look shorter
than the truth. RS256 comes along for free.

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

**A refusal is a ticket frame, not an error.** When the server will
not grant one — at the live-ticket cap, say — it answers on the
channel the request was made on, with `error` where a grant carries
`token`:

```json
{"type": "ticket", "id": "report", "purpose": "download",
 "error": "too many pending transfers"}
```

Answering is not optional. A client waiting on a grant that never
comes leaves its control disabled forever, which is the silent
failure this protocol keeps refusing to ship.

It rides the ticket channel rather than an `error` frame for two
reasons. The client is already holding the request that asked, so it
knows exactly which control to give back — an `error` scoped to a
resource id only names a *handler*, and several controls may share
one, so the client would be guessing. And it keeps `error` meaning one
thing: a renderer failed, scoped to that output. When refusals came
through `error`, the two clients quietly disagreed about which — the
browser marked every control routing to the id, Flutter stored it
against an output slot and so showed nothing at all.

A refusal is transient state belonging to one attempt. Both clients
clear it when the control asks again.
Signing would buy verification by a process that did not mint the
ticket, which is not this architecture. (An earlier draft said
"signed"; this is the honest replacement.)

Tokens are bearer credentials, so they come from a real CSPRNG
(`openssl::rand_bytes`, one source on every platform) — hashed
process state is unique, not unpredictable. Session ids get the same
source, for the same reason. The store is bounded: live tickets are
capped per session even inside the TTL window, and a request at the
cap gets an `error` scoped to the resource rather than silence — a
client waiting on a grant that never comes leaves its upload control
disabled forever, which is the same silent failure this protocol
keeps refusing to ship.

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

TLS is the same story for a different reason: base R sockets cannot
terminate it, and `openssl` being an Import buys the primitives, not
a TLS socket. The supported deployment is a reverse proxy
terminating TLS in front of glinty, with the network scoped by
firewall or namespace.

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
- Protocol 2 clients stop working. There was one, it shipped in this
  repo, and it was replaced rather than retrofitted.
- `run_app_native()` and the flitR backend are gone, not retrofitted.
  See below.

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
   RS256 through openssl, alg-pinned against confusion.
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
6. **The Flutter client grows a transport.** *(done)*
   `GlintyConnection` owns a WebSocket (`package:web_socket`, one
   transitive dependency, same API on the VM and in the browser),
   sends hello, routes frames into the session, and reconnects with
   backoff carrying `resume`. `GlintyApp(url:)` is the whole
   embedding surface. Two rules it exists to keep, both about not
   lying to the user: a refused connection stops retrying, and one
   that has given up says so instead of sitting on a spinner.
   Downloads resolve a ticket into an https URL and hand it to the
   embedder -- saving a file is platform work this package does not
   pretend to do.

   The proof is `test/server_e2e_test.dart`: it spawns R, serves a
   real app, opens a real socket, and drives the real client through
   the bootstrap, seeded inputs, an input round trip, events, a
   ticket grant, resume with state replay, and an auth refusal. It
   skips when R is absent, so CI installs R and then asserts the run
   was not skipped.

   **A client holds its own input state.** The component tree is the
   shape of the UI; the current value of each input is session
   state, seeded from that tree by the same rules the server seeds
   its own (an empty text field is `""`, a checkbox `false`, a
   single select its first choice), then owned by user edits and
   `input_update` frames. A client that reads a control's value out
   of the component draws the initial value forever, and a
   `conditional_panel` evaluated against anything else disagrees
   with the server about what is visible.

   A `resumed: false` welcome means the session the client described
   is gone: values, inputs and transfer tickets are dropped and any
   retained widget state goes with them. The browser reloads the
   page for exactly this reason.

7. **Adversarial review to a freeze.** *(done)* Eight rounds against
   a second reviewer, each one gated on fixing everything it found.
   What the rounds were actually good at was catching claims nothing
   checked: a fixture list that said "every component, once" and was
   missing thirteen; an `INPUT_META` whose doc said the conformance
   test held both lowerings to it while nothing read the field; a
   `hello` declaring the `measure` feature from a client that never
   measured, three lines under a comment stating that a feature
   named without an implementation is a claim the server believes.

   Each fix is mutation-tested — the fix reverted, the test watched
   to fail, the fix restored — because the rounds also caught tests
   that passed for the wrong reason. One of them was mine: a test
   for a refused input push used a `settle` field, whose blur report
   writes the local value back through the store and moves it, which
   let a naive value comparison pass by accident. `live` is where it
   actually breaks.

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
component → Flutter widgets in dart/glinty_flutter. `run_app_native()`
and `native_scene.R` were deleted rather than ported; flitR is
archived.

The falsifier reasoning was right while Dart was hypothetical. It
stopped being right the moment the Flutter SDK was installed, which
is a good reason to change a decision rather than a bad one.

### The spec stays draft until two clients agree

Freeze after the browser and the Dart MVP both pass shared golden
fixtures — the same component tree rendering equivalently in each.
The second implementation always exposes assumptions the first one
silently satisfied, and a spec frozen before that is a spec frozen
around the browser's habits.

**That condition is met, and the spec is frozen.** Both clients pass
the shared fixtures, and the second implementation earned its keep as
predicted. A partial list of what it exposed, none of which the
browser had complained about:

- `select_input(multiple = TRUE)` was scalar in five places. HTML has
  a native multi-select, so the browser satisfied the shape without
  the schema ever having to state it. Flutter has no such widget, and
  asking what the value *is* found a `field("string")` that could not
  hold two.
- `emit` was a DOM event name in disguise. `input` and `change` do
  the live/settle distinction for free in a browser; Flutter has to
  spend it deliberately, which is how a `settle` slider that streamed
  and a `settle` field that never reported on blur both surfaced.
- Refusing a server push while a field has focus needs a push
  *counter*, not a value comparison. `document.activeElement` made
  the browser's version look like a value check.
- `measure` needed the device pixel ratio for fixed-size plots too,
  which is invisible on a 1x display and obvious on a phone.
- Every dead control — a download button with no handler, a
  `modal_button()` no lowering marked — was a listener with no
  producer. Two lowerings make that a compile-time-shaped question
  rather than something you notice in a running app.

None of these were protocol bugs the browser would ever have found.
That is the whole argument for a second frontend, and it held.
