/// Component -> Flutter widget lowering.
///
/// The second lowering, and the one the protocol was actually designed
/// for. The browser lowering catches nothing on its own -- a component
/// vocabulary derived from HTML lowers to HTML without complaint. This
/// is where it meets a framework that owns layout, retains widget
/// state, and has its own focus and text models.
///
/// Anything reached for here that the component tree does not supply
/// is a finding, not a workaround.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/services.dart';

import 'component.dart';
import 'theme.dart' show GlintyStatusColors;

/// What a client can do, declared in `hello`.
///
/// The server never negotiates: a component this renderer does not
/// know draws a visible placeholder naming it.
const supportedComponents = <String>{
  'text', 'heading', 'link', 'icon', 'divider', 'spacer',
  'rich_text',
  'page', 'row', 'column', 'panel', 'feed',
  'text_input', 'password_input', 'textarea_input', 'number_input',
  'select_input', 'checkbox_input', 'checkbox_group', 'radio_buttons',
  'slider_input', 'range_slider', 'button', 'download_button',
  'text_output', 'verbatim_output', 'table_output', 'data_table',
  'plot_output', 'image_output', 'image',
  'tabset', 'conditional_panel', 'collapse', 'ui_output',
  // Drawn by the embedder's player, through audioBuilder. Declared
  // supported because the protocol asks what this client can render,
  // and it can -- given somewhere to send the sound.
  'audio_output',
  // The same seam again, through videoBuilder.
  'video_output',
  // Same shape: the app picks the files and posts them, through
  // onUpload; glinty owns the ticket in between.
  'file_input',
  // A key binding. Nothing to draw, so "render" here means "bind": a
  // HardwareKeyboard handler that lives exactly as long as the widget
  // does. Declared supported because the protocol asks what this
  // client can do with a component, and it can do the whole of this
  // one.
  'shortcut',
};

/// Components the protocol defines that this client cannot render.
///
/// Named rather than omitted, so the gap is visible in a running app.
/// The fixtures suite holds supported + unsupported equal to the
/// schema's component list, so a new component fails there until this
/// client answers for it -- render it, or refuse it by name.
const unsupportedComponents = <String>{
  'date_input', // showDatePicker is a dialog, not an inline control
  // Both carry markup, which has no Flutter equivalent by design.
  // raw_html is markup in the tree; html_output is markup arriving
  // as a value. Same refusal for the same reason.
  'raw_html',
  'html_output',
};

/// The spec's fallback rule: unknown variants take the first listed,
/// with a warning rather than an error, because a same-protocol
/// server one release newer may know variants this client does not.
///
/// Restates the schema on purpose -- each entry gates this client's
/// own style choices -- and the fixtures suite holds it equal to the
/// schema's variant lists, order included (the first value is the
/// fallback), so a new variant fails there until this client styles
/// it.
const knownVariants = <String, List<String>>{
  'text': [
    'normal', 'muted', 'strong', 'heading', 'mono', 'small', //
    'success', 'warning', 'danger'
  ],
  'text_output': [
    'normal', 'muted', 'strong', 'heading', 'mono', 'small', //
    'success', 'warning', 'danger'
  ],
  'button': ['default', 'primary', 'secondary', 'danger', 'ghost', 'listing'],
  'download_button': [
    'default', 'primary', 'secondary', 'danger', 'ghost', 'listing'
  ],
  'panel': ['plain', 'card', 'sidebar'],
  'divider': ['line', 'labelled'],
};

/// The one reserved component id.
///
/// A button carrying it closes the open dialog locally and reports
/// nothing -- what `modal_button()` builds. Reserved rather than
/// app-chosen because the server refuses `..` ids on the input path,
/// so no app can collide with it.
const glintyModalCloseId = '..modal_close';

/// Reports an input change back to the server.
typedef GlintySink = void Function(String id, dynamic value);

/// Reports a discrete event back to the server, carrying the button's
/// value when it has one -- that is what lets one server handler
/// serve a list of rows.
typedef GlintyEventSink = void Function(String id, {String? value});

/// Asks the server for a transfer ticket.
typedef GlintyTicketSink = void Function(String id, String purpose);

/// Reports an output's box in logical pixels, with the device pixel
/// ratio the server should rasterize at.
typedef GlintyMeasureSink = void Function(
    String id, double width, double height, double dpr);

/// Reports a video's playhead and playing state for one output id.
typedef GlintyVideoReportSink = void Function(
    String id, double currentTime, bool playing);

/// An audio value, ready to hand to a player.
///
/// The src is resolved: a data URI stays as it is, a relative path
/// has been joined to the address serving the app. [mime] is what the
/// protocol requires an audio value to carry, because a platform
/// player asks what it is being given.
class GlintyAudioSource {
  const GlintyAudioSource({
    required this.src,
    required this.mime,
    this.duration,
    this.controls = true,
    this.autoplay = false,
  });

  final Uri src;
  final String mime;

  /// Length in seconds, when the server knew it.
  final double? duration;

  /// What the component asked for. A player that shows no transport
  /// makes `controls` meaningless, which is the app's call to make,
  /// not this renderer's.
  final bool controls;
  final bool autoplay;
}

/// A video value, ready to hand to a player.
///
/// The same resolution rule as [GlintyAudioSource]: src and poster
/// arrive resolved against the address serving the app, and [mime]
/// is required because a platform player asks what it is given.
class GlintyVideoSource {
  const GlintyVideoSource({
    required this.src,
    required this.mime,
    this.poster,
    this.duration,
    this.controls = true,
    this.autoplay = false,
    this.muted = false,
    this.loop = false,
    this.onReport,
  });

  final Uri src;
  final String mime;

  /// The frame shown before play, when the server sent one.
  final Uri? poster;

  /// Length in seconds, when the server knew it.
  final double? duration;

  /// What the component asked for; the player decides what each
  /// means, the same deal audio's flags make.
  final bool controls;
  final bool autoplay;
  final bool muted;
  final bool loop;

  /// Where position and state reports go, non-null exactly when the
  /// component asked for them (`video_output(report = TRUE)`).
  ///
  /// The embedder's player calls this from its position listener --
  /// as often as it likes, on every tick: glinty owns the throttle
  /// and the dedup behind it, the same discipline the browser's
  /// timeupdate wiring keeps, so the wire sees at most ~4 reports a
  /// second and a paused player is silent. Null means the component
  /// never asked; a player with nothing to call simply does not
  /// report, and wiring a listener anyway costs the app nothing but
  /// the listener.
  final void Function(double currentTime, bool playing)? onReport;
}

/// The server refused a transfer, or the connection did.
///
/// Thrown out of [GlintyUploadRequest.target] so a handler that only
/// wants the happy path can ignore it: glinty catches it and puts the
/// reason beside the control that asked.
class GlintyTransferRefused implements Exception {
  const GlintyTransferRefused(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One file_input's request to pick files and send them.
///
/// Picking is a platform dialog and posting is an HTTP request;
/// neither belongs to a package with one dependency. The ticket does
/// belong here, so [target] is glinty's half: call it once files are
/// in hand and it asks the server for an upload ticket and resolves
/// the URL to POST to.
///
/// Ordering matters, which is why this is a callback rather than a
/// URL handed over up front. A ticket is short-lived and a picker
/// dialog is as long as the user takes; one minted before the dialog
/// opened would routinely expire in front of them. The browser
/// client asks in the same order for the same reason.
class GlintyUploadRequest {
  const GlintyUploadRequest({
    required this.id,
    required this.accept,
    required this.multiple,
    required this.target,
  });

  /// The input this belongs to, which is also what the server will
  /// deliver the files to.
  final String id;

  /// Extensions the app asked for, as written: `['.wav', '.mp3']`.
  /// Empty means it did not narrow.
  final List<String> accept;
  final bool multiple;

  /// Asks for an upload ticket and resolves the POST target.
  ///
  /// The body is `multipart/form-data` with each file under the field
  /// name `file`. Throws [GlintyTransferRefused] when the server says
  /// no or the connection goes away.
  final Future<Uri> Function() target;
}

/// Picks files and sends them, for a `file_input`.
///
/// Returns when the upload is done. Throwing -- or letting
/// [GlintyUploadRequest.target]'s refusal through -- puts the message
/// beside the control. Returning without calling `target` is how a
/// handler says the user cancelled.
typedef GlintyUploadHandler = Future<void> Function(
    BuildContext context, GlintyUploadRequest request);

/// Builds the widget that plays an audio value.
///
/// Playing audio needs a platform plugin, which this package does not
/// take on: it has exactly one dependency and a note explaining why.
/// Every app that used glinty would inherit an audio engine whether
/// or not it ever played a sound.
///
/// So the same seam as [GlintyRenderer.onLink] and
/// [GlintyRenderer.onDownload]: glinty says where the player goes and
/// what to play, the app says how. Without one, the slot draws a
/// visible placeholder rather than an empty box that looks like
/// silence.
typedef GlintyAudioBuilder = Widget Function(
    BuildContext context, GlintyAudioSource source);

/// The video seam, cut where the audio one is and for the same
/// reason: a video engine (video_player, media_kit) is a dependency
/// the embedder chooses, not one every glinty app inherits. Without
/// a builder the slot draws a visible placeholder naming the gap.
typedef GlintyVideoBuilder = Widget Function(
    BuildContext context, GlintyVideoSource source);

class GlintyRenderer {
  GlintyRenderer(
      {this.onInput,
      this.onLocalInput,
      this.onFocusChanged,
      this.onLink,
      this.onEvent,
      this.onTicket,
      this.onModalClose,
      this.onMeasure,
      this.onVideoReport,
      this.assetBase,
      this.audioBuilder,
      this.videoBuilder,
      this.onUpload,
      this.tickets = const {},
      this.awaitTicket,
      this.values = const {},
      this.kinds = const {},
      this.uiValues = const {},
      this.errors = const {},
      this.inputs = const {},
      this.pushes = const {},
      this.clears = const {},
      this.focuses = const {},
      this.seedTicks = const {},
      this.feeds = const {},
      this.overrides = const {},
      this.condition,
      this.spacing = 4,
      this.monoStack = const ['monospace', 'Menlo', 'Courier New']});

  final GlintySink? onInput;

  /// A local edit that is not reported: what a `settle` control does
  /// while it is being changed. Without it a settle slider either
  /// reports every intermediate value (which is `live`) or refuses to
  /// move under the thumb.
  final GlintySink? onLocalInput;

  /// A text field gained or lost keyboard focus. What the session's
  /// tree-swap draft guard (#79) keys on: the focused field is the
  /// one whose live value a slot replacement must not rewrite.
  final void Function(String id, bool focused)? onFocusChanged;

  final GlintyEventSink? onEvent;

  /// Where a link tap goes. Opening a URL needs a platform plugin
  /// (url_launcher), which is outside this package's budget, so the
  /// embedder decides. Without it a link renders as styled text and
  /// is not tappable -- pretending to be a link that does nothing is
  /// the kind of quiet lie this client keeps refusing to tell.
  final void Function(String href, {bool external})? onLink;

  /// Where a download_button's press goes: a ticket request, not an
  /// event. The press IS the download, and an event frame as well
  /// would make one press two actions.
  final GlintyTicketSink? onTicket;

  /// Where a modal_button's press goes: dismissing the open dialog,
  /// locally. Null outside a dialog, which makes such a button
  /// visibly disabled rather than quietly inert.
  final VoidCallback? onModalClose;

  /// What a relative src is relative to: the origin serving this
  /// app. Null in a fixture render, where there is no server, and a
  /// relative src is then named rather than guessed at.
  final Uri? assetBase;

  /// Builds the player for an audio_output. Without one the slot
  /// says so, the way a download button with nowhere to send its
  /// grant renders disabled.
  final GlintyAudioBuilder? audioBuilder;

  /// Builds the player for a video_output; the same seam and the
  /// same default: without one the slot names the gap.
  final GlintyVideoBuilder? videoBuilder;

  /// Picks files and sends them for a file_input. Without one the
  /// control says so rather than opening nothing.
  final GlintyUploadHandler? onUpload;

  /// Ticket grants by "purpose:id", owned by the session. A file
  /// input reads its own grant back out to build the POST target.
  final Map<String, Map<String, dynamic>> tickets;

  /// Where a responsive plot reports its box. Null in a fixture
  /// render, where there is no server to tell -- the plot then draws
  /// whatever value it was given and measures nothing.
  final GlintyMeasureSink? onMeasure;

  /// Where a reporting video's position goes. Null in a fixture
  /// render for the same reason as [onMeasure]; with it, a
  /// `video_output(report = TRUE)` hands its player an
  /// [GlintyVideoSource.onReport] wired here.
  final GlintyVideoReportSink? onVideoReport;

  /// The theme's base spacing unit in logical pixels. spacer() sizes
  /// are multiples of it -- the same rule the browser applies through
  /// --g-space, and the same default when no theme was set.
  final double spacing;

  /// The family stack for verbatim output -- the same role
  /// --g-font-mono plays in the browser, resolved to families the
  /// platform can know (see glintyMonoStack). Leads with the theme's
  /// choice and degrades within the mono role.
  final List<String> monoStack;

  String _variant(String component, String? variant) {
    final known = knownVariants[component];
    if (known == null) return variant ?? '';
    if (variant == null) return known.first;
    if (known.contains(variant)) return variant;
    debugPrint('glinty: unknown $component variant "$variant" '
        '- falling back to ${known.first}');
    return known.first;
  }

  /// Current input values, owned by the session. A control reads
  /// its value from here, not from the component: the tree is the
  /// shape of the UI and this is its state, so an edit survives the
  /// next rebuild.
  final Map<String, dynamic> inputs;

  /// Decides whether a conditional_panel shows. Defaults to always,
  /// which is what a fixture render wants; an app passes the
  /// session so panels actually toggle.
  final bool Function(dynamic condition)? condition;

  /// Server-pushed field changes per input id, preferred over what
  /// the tree says: update_select_input() changes the choices of a
  /// control the tree still describes with the old ones.
  final Map<String, Map<String, dynamic>> overrides;

  /// How many `input_update` pushes each input has had. Stateful
  /// controls tell one push from the next by this count rather than
  /// by the value, so a repeat of the same value still registers.
  final Map<String, int> pushes;

  /// How many `clear_on` clears each input has had. Counted apart
  /// from [pushes] because the rules differ: a push refuses a focused
  /// field, a clear applies regardless -- it is causally the user's
  /// own emit, and the composer has focus at exactly that moment.
  final Map<String, int> clears;

  /// How many focus verbs each input has had. A third counter with a
  /// third rule: applied regardless of who is focused (moving the
  /// caret is not the never-stomp hazard), including by a field born
  /// with a nonzero count -- the tree swap and the focus for its
  /// composer routinely share one drain.
  final Map<String, int> focuses;

  /// How many times each input's region has been re-declared by a
  /// slot replacement (#79). The fourth counter, with the push's
  /// rule: the declared value applies unless the field is focused --
  /// a re-render is redecorating, not dictating text into the draft
  /// someone is typing -- and is spent either way. A widget state
  /// that survives the swap has no initState to reread the store;
  /// this is how it hears the region changed under it.
  final Map<String, int> seedTicks;

  /// Each feed's held window, written by the session from feed
  /// messages. The widget reads items plus the tick/lastOp pair that
  /// tells one message from the next.
  final Map<String, GlintyFeedState> feeds;

  /// Latest value per output id, as delivered by `output` messages.
  final Map<String, dynamic> values;

  /// What each value IS, from the `kind` field of the same message.
  /// A slot whose value arrives as a kind it cannot draw says so by
  /// name; without this it would stringify the payload instead, and
  /// an image would render as `{src: data:image/png;base64,iVBOR...`.
  final Map<String, String> kinds;

  /// The parsed tree behind each `ui` output, by output id.
  ///
  /// Parsed by the session rather than here, because this runs on
  /// every frame and the tree is the same tree until the next one
  /// replaces it.
  final Map<String, GlintyComponent> uiValues;

  /// Registers a control as waiting on the next ticket answer for a
  /// resource, and returns a canceller. Null in a fixture render,
  /// where there is no session to ask.
  final void Function() Function(String, String, void Function(String?))?
      awaitTicket;

  /// Render errors per output id. The server said why the value is
  /// missing, so the slot shows that rather than sitting blank.
  final Map<String, String> errors;

  /// Draws an output slot, or refuses it visibly.
  ///
  /// The order matters: an error outranks a value (the value is
  /// stale, the error is current), and a kind this slot cannot draw
  /// outranks drawing it wrong.
  Widget _slot(BuildContext context, GlintyComponent c, String expected,
      Widget Function() draw) {
    final id = c.str('id');
    final err = errors[id];
    if (err != null) {
      return _problem(const Color(0xFFF8D7DA), err);
    }
    final kind = kinds[id];
    // Whether this slot can draw a kind is a fact about the kind and
    // the slot, not about what happened to arrive in it. Gating on a
    // non-null value made an `output` carrying kind `image` and value
    // null render as an ordinary empty slot -- the client could not
    // have drawn it either way, and said nothing.
    if (kind != null && kind != expected) {
      return _problem(const Color(0xFFFFF3CD),
          '[cannot display $kind here: ${c.type} shows $expected]');
    }
    return draw();
  }

  /// A component tree that arrived as a value, built into its slot.
  ///
  /// The same `build()` the page goes through, on a subtree the
  /// server sent later. Bindings included: a button in here reports
  /// through the same sinks as one in the page, because it is the
  /// same lowering and there is nothing about arriving late that
  /// changes what a button is.
  ///
  /// Deliberately unkeyed. Every control that holds state is already
  /// keyed by its own id, because an input id really is an identity,
  /// so a field replaced by a different field does not inherit its
  /// controller. Wrapping the subtree in a key of its own would
  /// instead throw that state away on every re-render -- and a slot
  /// like a container-status panel on a five-second poll re-renders
  /// constantly.
  Widget _dynamicUi(BuildContext context, GlintyComponent c) {
    final tree = uiValues[c.str('id')];
    if (tree == null) return const SizedBox.shrink();
    return build(context, tree);
  }

  Widget _problem(Color background, String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: background,
        child: Text(message),
      );

  Widget build(BuildContext context, GlintyComponent c) {
    switch (c.type) {
      case 'text':
        return _text(context, c);
      case 'heading':
        return _heading(context, c);
      case 'rich_text':
        return _richText(c);
      case 'link':
        return _link(context, c);
      case 'icon':
        return Icon(_iconFor(c.str('name')), size: c.number('size')?.toDouble());
      case 'divider':
        return _divider(c);
      case 'spacer':
        return SizedBox(height: (c.number('size') ?? 1) * spacing);
      case 'image':
        return _staticImage(c);
      case 'collapse':
        // Where width is bounded the tile fills it, which is also
        // what the block-level div does; where it is not, the tile's
        // ListTile has nothing to lay its title against and
        // _widthBounded shrink-wraps it.
        return _widthBounded(_collapse(context, c));
      // page is never a flex child -- it is the root -- so it skips
      // the sizing wrapper the other three take.
      case 'page':
        {
          // Both variants scroll: the page is what scrolls in the
          // browser too. Full keeps workspace density -- every pixel
          // of width, .g-page-full's tighter padding -- while the
          // default is the centered reading column below. The height
          // record says what a scroll view always means: unbounded,
          // so grown children at page level stop growing, which is
          // what flex-grow against an auto-height page does.
          if (c.str('width') == 'full') {
            return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    spacing * 3, spacing * 2, spacing * 3, spacing * 3),
                child: _bounded(_column(context, c), height: false));
          }
          // The browser's reading column (.g-page: 760px, centered,
          // padded, the page is what scrolls). Width is tightened to
          // the cap so the column fills it the way the CSS box does,
          // rather than shrink-wrapping its widest child.
          return SingleChildScrollView(
              child: Center(
                  child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                      child: _column(context, c))));
        }
      case 'column':
        // scroll: overflow scrolls instead of growing the page. Grown
        // children inside stop growing, which _spaced documents -- a
        // scroll view has all the height it asks for and none spare.
        return _sized(
            c,
            c.boolean('scroll')
                ? SingleChildScrollView(
                    child: _bounded(_column(context, c), height: false))
                : _column(context, c));
      case 'feed':
        return _sized(c, _feed(context, c));
      case 'row':
        return _sized(c, _row(context, c));
      case 'panel':
        return _sized(c, _capped(c, _panel(context, c)));
      case 'text_input':
        return _textField(context, c);
      case 'password_input':
        return _textField(context, c, obscure: true);
      case 'textarea_input':
        return _textField(context, c, maxLines: c.integer('rows') ?? 4);
      case 'number_input':
        return _textField(context, c, numeric: true);
      case 'select_input':
        return _select(context, c);
      case 'checkbox_input':
        return _checkbox(c);
      case 'radio_buttons':
        return _radios(context, c);
      case 'checkbox_group':
        return _checkboxGroup(context, c);
      case 'slider_input':
        return _slider(context, c);
      case 'range_slider':
        return _rangeSlider(context, c);
      case 'button':
      case 'download_button':
        return _button(context, c);
      case 'text_output':
        return _slot(context, c, 'text',
            () => Text(_outputText(c), style: _textStyleFor(context, c)));
      case 'verbatim_output':
        return _slot(context, c, 'text', () => _verbatim(context, c));
      case 'table_output':
        return _slot(context, c, 'table', () => _table(c));
      case 'data_table':
        return _slot(context, c, 'table', () => _dataTable(c));
      case 'plot_output':
        return _slot(context, c, 'image', () => _plot(context, c));
      case 'image_output':
        return _slot(context, c, 'image', () => _image(c));
      case 'file_input':
        return _fileInput(context, c);
      case 'audio_output':
        return _slot(context, c, 'audio', () => _audio(context, c));
      case 'video_output':
        return _slot(context, c, 'video', () => _video(context, c));
      case 'ui_output':
        return _slot(context, c, 'ui', () => _dynamicUi(context, c));
      case 'tabset':
        return _tabset(context, c);
      case 'conditional_panel':
        // Evaluated against the same input store the controls draw
        // from, by the same rules R and the browser use. A fixture
        // render with no evaluator shows the children, which is what
        // makes the fixture a render test rather than a state test.
        final decide = condition;
        final visible = decide == null || decide(c.fields['condition']);
        // Offstage, not discarded: the documented difference between
        // conditional_panel and render_ui is that hiding keeps what
        // is inside alive (?conditional_panel). Destroying the
        // subtree would drop focus, scroll position and controllers
        // every time a panel toggled.
        return Offstage(
          offstage: !visible,
          child: _column(context, c),
        );
      case 'shortcut':
        return _shortcut(context, c);
      default:
        return _unsupported(c.type);
    }
  }

  // --- keyboard ---

  /// Physical keys, by the token the protocol carries.
  ///
  /// Physical rather than logical: a shortcut names the KEY, so
  /// "shift+1" is that and never "exclam", and the binding survives a
  /// layout where the character would not. Closed on both sides -- a
  /// token the server can send is a token this map answers for, so a
  /// shortcut can never bind to nothing.
  static const Map<String, PhysicalKeyboardKey> _keyFor = {
    'a': PhysicalKeyboardKey.keyA, 'b': PhysicalKeyboardKey.keyB,
    'c': PhysicalKeyboardKey.keyC, 'd': PhysicalKeyboardKey.keyD,
    'e': PhysicalKeyboardKey.keyE, 'f': PhysicalKeyboardKey.keyF,
    'g': PhysicalKeyboardKey.keyG, 'h': PhysicalKeyboardKey.keyH,
    'i': PhysicalKeyboardKey.keyI, 'j': PhysicalKeyboardKey.keyJ,
    'k': PhysicalKeyboardKey.keyK, 'l': PhysicalKeyboardKey.keyL,
    'm': PhysicalKeyboardKey.keyM, 'n': PhysicalKeyboardKey.keyN,
    'o': PhysicalKeyboardKey.keyO, 'p': PhysicalKeyboardKey.keyP,
    'q': PhysicalKeyboardKey.keyQ, 'r': PhysicalKeyboardKey.keyR,
    's': PhysicalKeyboardKey.keyS, 't': PhysicalKeyboardKey.keyT,
    'u': PhysicalKeyboardKey.keyU, 'v': PhysicalKeyboardKey.keyV,
    'w': PhysicalKeyboardKey.keyW, 'x': PhysicalKeyboardKey.keyX,
    'y': PhysicalKeyboardKey.keyY, 'z': PhysicalKeyboardKey.keyZ,
    '0': PhysicalKeyboardKey.digit0, '1': PhysicalKeyboardKey.digit1,
    '2': PhysicalKeyboardKey.digit2, '3': PhysicalKeyboardKey.digit3,
    '4': PhysicalKeyboardKey.digit4, '5': PhysicalKeyboardKey.digit5,
    '6': PhysicalKeyboardKey.digit6, '7': PhysicalKeyboardKey.digit7,
    '8': PhysicalKeyboardKey.digit8, '9': PhysicalKeyboardKey.digit9,
    'f1': PhysicalKeyboardKey.f1, 'f2': PhysicalKeyboardKey.f2,
    'f3': PhysicalKeyboardKey.f3, 'f4': PhysicalKeyboardKey.f4,
    'f5': PhysicalKeyboardKey.f5, 'f6': PhysicalKeyboardKey.f6,
    'f7': PhysicalKeyboardKey.f7, 'f8': PhysicalKeyboardKey.f8,
    'f9': PhysicalKeyboardKey.f9, 'f10': PhysicalKeyboardKey.f10,
    'f11': PhysicalKeyboardKey.f11, 'f12': PhysicalKeyboardKey.f12,
    'space': PhysicalKeyboardKey.space,
    'enter': PhysicalKeyboardKey.enter,
    'escape': PhysicalKeyboardKey.escape,
    'tab': PhysicalKeyboardKey.tab,
    'backspace': PhysicalKeyboardKey.backspace,
    'delete': PhysicalKeyboardKey.delete,
    'insert': PhysicalKeyboardKey.insert,
    'home': PhysicalKeyboardKey.home,
    'end': PhysicalKeyboardKey.end,
    'pageup': PhysicalKeyboardKey.pageUp,
    'pagedown': PhysicalKeyboardKey.pageDown,
    'left': PhysicalKeyboardKey.arrowLeft,
    'right': PhysicalKeyboardKey.arrowRight,
    'up': PhysicalKeyboardKey.arrowUp,
    'down': PhysicalKeyboardKey.arrowDown,
    'comma': PhysicalKeyboardKey.comma,
    'period': PhysicalKeyboardKey.period,
    'slash': PhysicalKeyboardKey.slash,
    'backslash': PhysicalKeyboardKey.backslash,
    'semicolon': PhysicalKeyboardKey.semicolon,
    'quote': PhysicalKeyboardKey.quote,
    'bracketleft': PhysicalKeyboardKey.bracketLeft,
    'bracketright': PhysicalKeyboardKey.bracketRight,
    'minus': PhysicalKeyboardKey.minus,
    'equal': PhysicalKeyboardKey.equal,
    'backquote': PhysicalKeyboardKey.backquote,
  };

  /// A key binding. Renders nothing and occupies no space.
  ///
  /// A handler on [HardwareKeyboard] rather than [Shortcuts]/[Actions]:
  /// those route by focus, and a shortcut declared anywhere in the tree
  /// is a page-wide accelerator whose owner may not be focusable at all
  /// -- the surface a plot_output draws into is an image. The
  /// suppression rules (typing, autorepeat) are the protocol's rather
  /// than Flutter's traversal's, so they are applied where they can be
  /// read next to the rest of the contract.
  Widget _shortcut(BuildContext context, GlintyComponent c) {
    final key = _keyFor[c.str('key')];
    // A token with no physical key cannot happen -- the set is closed
    // on both sides -- but rendering nothing beats crashing a whole
    // page over one binding if a client ever runs ahead of a server.
    if (key == null) return const SizedBox.shrink();
    final id = c.str('id');
    if (id == null) return const SizedBox.shrink();
    return _GlintyShortcut(
      physical: key,
      ctrl: c.fields['ctrl'] == true,
      shift: c.fields['shift'] == true,
      alt: c.fields['alt'] == true,
      typing: c.fields['typing'] == true,
      hold: c.fields['hold'] == true,
      fire: () => onEvent?.call(id, value: c.str('value')),
    );
  }

  // --- static content ---

  TextStyle? _textStyleFor(BuildContext context, GlintyComponent c) {
    final theme = Theme.of(context).textTheme;
    switch (_variant(c.type, c.str('variant'))) {
      case 'muted':
        // the muted token lands on onSurfaceVariant in glintyThemeData
        return theme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
      case 'strong':
        return theme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
      case 'heading':
        return theme.titleMedium;
      case 'mono':
        // the verbatim output's stack: the theme's mono token first
        return theme.bodySmall?.copyWith(
            fontFamily: monoStack.first,
            fontFamilyFallback: monoStack.sublist(1));
      case 'small':
        return theme.bodySmall;
      case 'success':
        return theme.bodyMedium?.copyWith(
            color: Theme.of(context)
                .extension<GlintyStatusColors>()
                ?.success);
      case 'warning':
        return theme.bodyMedium?.copyWith(
            color: Theme.of(context)
                .extension<GlintyStatusColors>()
                ?.warning);
      case 'danger':
        // the danger token lands on ColorScheme.error in
        // glintyThemeData, so the variant reads it back from there
        return theme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.error);
      default:
        return theme.bodyMedium;
    }
  }

  Widget _text(BuildContext context, GlintyComponent c) =>
      Text(c.str('value') ?? '', style: _textStyleFor(context, c));

  Widget _heading(BuildContext context, GlintyComponent c) {
    final theme = Theme.of(context).textTheme;
    final style = switch (c.integer('level') ?? 2) {
      1 => theme.headlineLarge,
      2 => theme.headlineMedium,
      3 => theme.headlineSmall,
      _ => theme.titleLarge,
    };
    return Text(c.str('value') ?? '', style: style);
  }

  Widget _richText(GlintyComponent c) {
    final raw = c.fields['runs'];
    final runs = raw is List
        ? raw.whereType<Map>().map((r) => GlintyRun.fromJson(r)).toList()
        : const <GlintyRun>[];
    return _GlintyRichText(
        runs: runs, onLink: onLink, monoStack: monoStack);
  }

  Widget _link(BuildContext context, GlintyComponent c) {
    final href = c.str('href') ?? '';
    final cb = onLink;
    // Children or text, never both -- the schema refuses a link that
    // carries neither. Wrapped children are not underlined or
    // recoloured: a logo inside a link is still a logo.
    final kids = c.children;
    final Widget label = kids.isNotEmpty
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: kids.map((k) => build(context, k)).toList())
        : Text(
            c.str('value') ?? '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          );
    // No handler, no tap target: an InkWell with an empty onTap
    // looks tappable and does nothing.
    if (cb == null) return label;
    return InkWell(
      onTap: () => cb(href, external: c.boolean('external')),
      child: label,
    );
  }

  Widget _divider(GlintyComponent c) {
    final label = c.str('label');
    if (_variant('divider', c.str('variant')) == 'labelled' && label != null) {
      return Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label),
        ),
        const Expanded(child: Divider()),
      ]);
    }
    return const Divider();
  }

  /// Icon names are tokens; the frontend owns the artwork.
  ///
  /// A name with no mapping renders `help_outline` rather than
  /// nothing, so a typo is visible instead of invisible.
  IconData _iconFor(String? name) => switch (name) {
        'play' => Icons.play_arrow,
        'stop' => Icons.stop,
        'rotate' => Icons.refresh,
        'trash' => Icons.delete_outline,
        'microphone' => Icons.mic,
        'bookmark' => Icons.bookmark_border,
        'download' => Icons.download,
        'upload' => Icons.upload,
        'folder' => Icons.folder_outlined,
        'file' => Icons.insert_drive_file_outlined,
        _ => Icons.help_outline,
      };

  // --- layout ---
  //
  // `gap` is a number, which is the only reason this can build
  // separators. A CSS length string would have been unusable.

  /// Children of a Row or Column, with gaps between them.
  ///
  /// [canGrow] says whether `Expanded` is legal here, which needs two
  /// things and not one. Being the direct child of a Flex is
  /// necessary -- Expanded anywhere else throws ParentDataWidget --
  /// but the Flex also has to have a *bounded* main axis, or the
  /// error is "children have non-zero flex but incoming constraints
  /// are unbounded". A Column inside a scroll view, or inside an
  /// ExpansionTile, has all the height it asks for and none to share
  /// out, so there is nothing for a grown child to take.
  List<Widget> _spaced(BuildContext context, List<GlintyComponent> kids,
      double gap, bool row,
      {required bool canGrow}) {
    final out = <Widget>[];
    for (var i = 0; i < kids.length; i++) {
      if (i > 0 && gap > 0) {
        out.add(row ? SizedBox(width: gap) : SizedBox(height: gap));
      }
      final grow = kids[i].integer('grow') ?? 0;
      final grown = canGrow && grow > 0;
      // Record what this flex gives the child: a tight main axis when
      // grown, an unbounded one when not (a Flex measures non-flex
      // children against infinity regardless of its own size). The
      // cross axis passes through untouched.
      final child = _bounded(build(context, kids[i]),
          width: row ? grown : null, height: row ? null : grown);
      out.add(grown ? Expanded(flex: grow, child: child) : child);
    }
    return out;
  }

  /// Builds a Flex, measuring its own main axis first.
  ///
  /// The LayoutBuilder is not decoration: whether a grown child is
  /// legal depends on constraints this widget only learns at layout
  /// time, and guessing wrong is a crash rather than a wrong pixel.
  /// When the axis is unbounded a grown child simply does not grow,
  /// which is what the browser does too -- flex-grow has nothing to
  /// divide when the container is auto-sized.
  ///
  /// EXCEPT under a stretch row, whose IntrinsicHeight makes the
  /// LayoutBuilder itself the crash: the intrinsics pass walks the
  /// subtree asking natural sizes, a LayoutBuilder cannot answer an
  /// intrinsics query, and a subtree that fails layout paints
  /// nothing -- a blank window with no error on screen. So the
  /// stretch branch marks its subtree, and any flex under the mark
  /// answers the question from [_Bounds] -- the record the
  /// containers above kept while building -- instead of measuring.
  /// Granting outright would be wrong: stretch does make height
  /// tight, but a row sitting as the non-grown child of another flex
  /// has unbounded WIDTH, and an Expanded there is the same crash in
  /// different clothes.
  ///
  /// The check happens in a Builder rather than during this eager
  /// recursion because the mark lives in the ELEMENT tree: an output
  /// slot that rebuilds alone under the stretch row still sees it,
  /// where a flag threaded through the recursion would have been
  /// lost with the call stack.
  Widget _flex(BuildContext context, GlintyComponent c, bool row) {
    final gap = c.number('gap')?.toDouble() ?? 0;
    final wants = c.children.any((k) => (k.integer('grow') ?? 0) > 0);
    Widget make(bool canGrow) {
      final kids = _spaced(context, c.children, gap, row, canGrow: canGrow);
      if (!row) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: canGrow ? MainAxisSize.max : MainAxisSize.min,
            children: kids);
      }
      final made = Row(
          mainAxisSize: canGrow ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: switch (c.str('align')) {
            'center' => CrossAxisAlignment.center,
            'end' => CrossAxisAlignment.end,
            'stretch' => CrossAxisAlignment.stretch,
            _ => CrossAxisAlignment.start,
          },
          children: kids);
      // stretch forces a tight cross axis on every child, which is an
      // error when the row's own height is unbounded -- the usual case
      // inside a page column. IntrinsicHeight bounds it at the tallest
      // child, which is what the browser's align-items: stretch does.
      // The marker sits INSIDE the IntrinsicHeight, so everything the
      // intrinsics pass can reach knows not to interpose a
      // LayoutBuilder; this row's own gate (below) stays outside it,
      // which is why a flat stretch row with grown children was never
      // broken.
      return c.str('align') == 'stretch'
          ? IntrinsicHeight(
              child: _UnderIntrinsics(child: _bounded(made, height: true)))
          : made;
    }

    // No grown child means no constraint to check, and no reason to
    // pay for a LayoutBuilder on every container in the tree.
    if (!wants) return make(false);
    return Builder(builder: (context) {
      if (_UnderIntrinsics.present(context)) {
        final b = _Bounds.maybeOf(context);
        return make(row ? (b?.width ?? false) : (b?.height ?? false));
      }
      return LayoutBuilder(builder: (context, box) {
        final bounded = row ? box.maxWidth.isFinite : box.maxHeight.isFinite;
        return make(bounded);
      });
    });
  }

  Widget _column(BuildContext context, GlintyComponent c) =>
      _flex(context, c, false);

  Widget _row(BuildContext context, GlintyComponent c) =>
      _flex(context, c, true);

  Widget _panel(BuildContext context, GlintyComponent c) {
    final title = c.str('title');
    final fill = c.boolean('fill');
    Widget makeBody(bool canGrow) => Column(
          // filled panels stretch children across their width, the way
          // the browser's flex column does; plain panels keep the old
          // start alignment
          crossAxisAlignment:
              fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          mainAxisSize: canGrow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child:
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
              ),
            ..._spaced(context, c.children, 0, false, canGrow: canGrow),
          ],
        );
    // Fill grants Expanded -- where there is height to hand over. No
    // LayoutBuilder gate here, unlike _flex: a filled panel's natural
    // home is a stretched row, which measures its children through
    // IntrinsicHeight, and a LayoutBuilder cannot answer an
    // intrinsics query. The _Bounds record can: where it says height
    // is unbounded (a scrolling page), the panel degrades to content
    // size, which is what the browser's flex column does in a
    // scrolling body -- and what this used to answer with a crash,
    // "a layout error by definition".
    final body = Builder(
        builder: (context) =>
            makeBody(fill && (_Bounds.maybeOf(context)?.height ?? true)));
    final variant = _variant('panel', c.str('variant'));
    if (variant == 'card') {
      return Card(child: Padding(padding: const EdgeInsets.all(12), child: body));
    }
    if (variant == 'sidebar') {
      // the CSS twin: surface background, a border on the trailing
      // edge of the content it sits beside
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(right: BorderSide(color: scheme.outline)),
        ),
        child: body,
      );
    }
    return body;
  }

  // --- inputs ---

  /// The current value of an input, falling back to what the tree
  /// declared. A control that reads only the tree draws its initial
  /// value forever.
  dynamic _value(String id, dynamic fallback) =>
      inputs.containsKey(id) ? inputs[id] : fallback;

  /// A field of an input, preferring what the server pushed since.
  dynamic _field(String id, String name, dynamic fromTree) {
    final o = overrides[id];
    return (o != null && o.containsKey(name)) ? o[name] : fromTree;
  }

  /// A control's label, after any server update.
  String? _label(GlintyComponent c) {
    final id = c.str('id');
    final v = id == null ? c.str('label') : _field(id, 'label', c.str('label'));
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// A control's choices, after any server update.
  List<GlintyChoice> _choices(GlintyComponent c) {
    final id = c.str('id');
    final pushed = id == null ? null : overrides[id]?['choices'];
    if (pushed is! List) return c.choices;
    return pushed
        .whereType<Map>()
        .map((m) =>
            GlintyChoice(m['value'].toString(), m['label'].toString()))
        .toList();
  }

  double? _numField(GlintyComponent c, String name) {
    final id = c.str('id');
    final v =
        id == null ? c.number(name) : _field(id, name, c.number(name));
    return v is num ? v.toDouble() : null;
  }

  Widget _textField(BuildContext context, GlintyComponent c,
      {bool obscure = false, int maxLines = 1, bool numeric = false}) {
    final id = c.str('id')!;
    final emit = GlintyEmit.parse(c.str('emit'));
    void report(String v) => onInput?.call(id, numeric ? num.tryParse(v) : v);
    // A StatefulWidget, because a text field owns a controller and a
    // selection: rebuilding one from a fresh TextEditingController
    // every frame drops the caret and (with any latency at all) the
    // characters typed since the last frame.
    // A number field has bounds and a step, and Flutter has no
    // spinner to spend them on -- but they are what the server just
    // told the user, so they are shown rather than stored and
    // ignored. Nothing is clamped: silently rewriting what someone
    // typed is worse than letting the server reject it.
    String? helper;
    if (numeric) {
      final min = _numField(c, 'min');
      final max = _numField(c, 'max');
      final step = _numField(c, 'step');
      final parts = [
        if (min != null && max != null)
          '$min to $max'
        else if (min != null)
          'at least $min'
        else if (max != null)
          'at most $max',
        if (step != null) 'step $step',
      ];
      if (parts.isNotEmpty) helper = parts.join(', ');
    }
    return _GlintyTextField(
      key: Key(id),
      value: _value(id, c.str('value') ?? '')?.toString() ?? '',
      push: pushes[id] ?? 0,
      clear: clears[id] ?? 0,
      focusTick: focuses[id] ?? 0,
      seedTick: seedTicks[id] ?? 0,
      obscure: obscure,
      maxLines: maxLines,
      numeric: numeric,
      label: _label(c),
      hint: c.str('placeholder'),
      helper: helper,
      // This is where `emit` is spent, and the only place that knows
      // Flutter calls these onChanged, onSubmitted and (for settle,
      // via a focus listener) blur.
      //
      // A settle field reports on enter OR on leaving -- typing and
      // then clicking away is how most forms are filled, and a field
      // that only reports on enter discards that silently.
      onChanged: emit == GlintyEmit.live ? report : null,
      onSubmitted: emit == GlintyEmit.settle ? report : null,
      onSettle: emit == GlintyEmit.settle ? report : null,
      onLocal: emit == GlintyEmit.settle && onLocalInput != null
          ? (v) => onLocalInput?.call(id, numeric ? num.tryParse(v) : v)
          : null,
      onFocusChanged: onFocusChanged == null
          ? null
          : (f) => onFocusChanged?.call(id, f),
    );
  }

  /// A control with its label above it, when it has one. Dropdowns,
  /// radio groups and sliders carry a label the same way text fields
  /// do -- and it can change under an input_update.
  Widget _labelled(BuildContext context, GlintyComponent c, Widget child) {
    final label = _label(c);
    if (label == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        child,
      ],
    );
  }

  Widget _select(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final choices = _choices(c);
    // A dropdown holds one value. Lowering a multiple select to one
    // silently turns "pick some" into "pick one" -- the control
    // looks fine, and every selection but the last is discarded on
    // the way to the server.
    if (c.boolean('multiple')) return _multiSelect(context, c, id, choices);
    final current = _value(id, c.str('selected'))?.toString() ??
        (choices.isNotEmpty ? choices.first.value : null);
    if (c.boolean('search')) {
      // The searchable select. Material's DropdownMenu filters its
      // entries as the user types -- the same contract as the
      // browser's combobox: typed text is a view, only picking a
      // real entry reports. Selection state lives in the menu's own
      // controller keyed by id; the reported value is the entry's.
      return _labelled(context, c, DropdownMenu<String>(
        key: Key(id),
        enableFilter: true,
        requestFocusOnTap: true,
        initialSelection:
            choices.any((ch) => ch.value == current) ? current : null,
        dropdownMenuEntries: choices
            .map((ch) => DropdownMenuEntry(value: ch.value, label: ch.label))
            .toList(),
        onSelected: (v) {
          if (v != null) onInput?.call(id, v);
        },
      ));
    }
    return _labelled(context, c, DropdownButton<String>(
      key: Key(id),
      // a value the choices no longer contain would assert; fall
      // back rather than crash on a tree that changed under us
      value: choices.any((ch) => ch.value == current) ? current : null,
      items: choices
          .map((ch) =>
              DropdownMenuItem(value: ch.value, child: Text(ch.label)))
          .toList(),
      onChanged: (v) {
        if (v != null) onInput?.call(id, v);
      },
    ));
  }

  /// A multiple select: chips, not a dropdown.
  ///
  /// Material has no stock multi-select menu, and the value on the
  /// wire is a list either way. Chips make the whole selection
  /// visible at once, which is what a list-valued control needs.
  Widget _multiSelect(BuildContext context, GlintyComponent c, String id,
      List<GlintyChoice> choices) {
    final raw = _value(id, c.fields['selected']);
    final chosen = raw is List
        ? raw.map((v) => v.toString()).toList()
        : (raw == null ? <String>[] : [raw.toString()]);
    return _labelled(
        context,
        c,
        Wrap(
          spacing: 8,
          children: choices
              .map((ch) => FilterChip(
                    key: Key('${id}_${ch.value}'),
                    label: Text(ch.label),
                    selected: chosen.contains(ch.value),
                    onSelected: (on) {
                      // Order follows the choice list, not the order
                      // they were tapped: the server compares this
                      // against a set, and a value that reorders
                      // itself on every toggle reads as a change
                      // when nothing changed.
                      final next = choices
                          .map((o) => o.value)
                          .where((v) => v == ch.value
                              ? on
                              : chosen.contains(v))
                          .toList();
                      onInput?.call(id, next);
                    },
                  ))
              .toList(),
        ));
  }

  Widget _checkbox(GlintyComponent c) {
    final id = c.str('id')!;
    final checked = _value(id, c.boolean('value')) == true;
    // Box then word at natural width, the browser's shape. A
    // CheckboxListTile is a full-width row with a trailing box --
    // a settings screen, not a form control -- and the same tree
    // must read the same way in both lowerings.
    // One gesture path: the box is display-only under IgnorePointer
    // and every tap -- box or label -- lands on the InkWell. Nesting
    // two live tap targets put box-clicks into a gesture arena that
    // could fizzle with neither firing (seen live on CanvasKit).
    return InkWell(
      key: Key(id),
      onTap: () => onInput?.call(id, !checked),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IgnorePointer(
            child: Checkbox(
                value: checked,
                visualDensity: VisualDensity.compact,
                onChanged: (_) {})),
        Text(_label(c) ?? ""),
      ]),
    );
  }

  Widget _radios(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    // RadioGroup replaced per-tile groupValue/onChanged in 3.32.
    return _labelled(
        context,
        c,
        RadioGroup<String>(
      groupValue: _value(id, c.str('selected'))?.toString(),
      onChanged: (v) {
        if (v != null) onInput?.call(id, v);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _choices(c)
            .map((ch) => RadioListTile<String>(
                  key: Key('${id}_${ch.value}'),
                  value: ch.value,
                  title: Text(ch.label),
                ))
            .toList(),
      ),
        ));
  }

  /// One id, many boxes: the group's value is the array of checked
  /// members' values in choice order, at every length -- the
  /// multiple-select rule. Each toggle emits the whole array.
  Widget _checkboxGroup(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final raw = _value(id, c.fields['selected']);
    final checked = raw is List ? raw.map((v) => '$v').toSet() : <String>{};
    final choices = _choices(c);
    return _labelled(
        context,
        c,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: choices
              .map((ch) => CheckboxListTile(
                    key: Key('${id}_${ch.value}'),
                    value: checked.contains(ch.value),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(ch.label),
                    onChanged: (v) {
                      final next = checked.toSet();
                      if (v == true) {
                        next.add(ch.value);
                      } else {
                        next.remove(ch.value);
                      }
                      // choice order, never click order
                      onInput?.call(
                          id,
                          choices
                              .map((o) => o.value)
                              .where(next.contains)
                              .toList());
                    },
                  ))
              .toList(),
        ));
  }

  Widget _slider(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final min = _numField(c, "min") ?? 0;
    final max = _numField(c, "max") ?? 1;
    final step = _numField(c, "step");
    final raw = _value(id, c.number('value'));
    final current = raw is num ? raw.toDouble() : min;
    final settle = GlintyEmit.parse(c.str('emit')) == GlintyEmit.settle;
    final theme = Theme.of(context);
    final value = current.clamp(min, max);
    final pct = max > min ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    // The browser's three number layers, mirrored: a value bubble
    // riding the thumb, min/max chips at the ends that yield when
    // the bubble reaches them, and a graded scale below the track.
    // Local edits rebuild this subtree, so every layer tracks the
    // finger under `settle` too.
    // _IntrinsicAnswer: the tight height answers height intrinsics at
    // the SizedBox; a width query would otherwise reach the
    // LayoutBuilder and throw. Chips contribute nothing to measured
    // width, which is the track's business anyway.
    final chipRow = SizedBox(
        height: 22,
        child: _IntrinsicAnswer(child: LayoutBuilder(
            builder: (context, box) => Stack(clipBehavior: Clip.none, children: [
                  if (pct >= 0.1)
                    Positioned(left: 0, top: 0,
                        child: _sliderChip(theme, _numLabel(min),
                            primary: false)),
                  if (pct <= 0.9)
                    Positioned(right: 0, top: 0,
                        child: _sliderChip(theme, _numLabel(max),
                            primary: false)),
                  Positioned(
                      left: _trackX(pct, box.maxWidth), top: 0,
                      child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: _sliderChip(theme, _numLabel(value),
                              primary: true))),
                ]))));
    // ticks take the materialized step: they sit where the thumb can
    // actually rest, and the thumb rests on the implied grid
    final effStep = step != null && step > 0
        ? step
        : (max > min ? _sliderImpliedStep(min, max) : null);
    final scale = _sliderScale(theme, min, max, effStep);
    // _widthBounded: the stretch column below forces its width onto
    // every layer, which in an unbounded-width spot is infinity.
    return _widthBounded(_labelled(
        context,
        c,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          chipRow,
          Slider(
            key: Key(id),
            min: min,
            max: max,
            // Flutter wants a division count where the protocol says
            // step size. Derivable because step is a number.
            divisions:
                step != null && step > 0 ? ((max - min) / step).round() : null,
            value: value,
            // Where `emit` is spent for a slider. A drag is one
            // gesture producing hundreds of onChanged calls; under
            // `settle` the server wants the number the user landed on,
            // not the sweep. Local edits keep the thumb (and any panel
            // keyed on it) tracking the finger in the meantime.
            // Every emitted value goes through _sliderQuantize: with
            // no divisions Material drags continuously, and a
            // sample-count slider must not report 394.326 samples --
            // the browser's range input quantizes to its step, so
            // this side quantizes to the same implied precision.
            onChanged: settle
                ? (v) => (onLocalInput ?? onInput)
                    ?.call(id, _sliderQuantize(v, min, max, step))
                : (v) => onInput?.call(id, _sliderQuantize(v, min, max, step)),
            onChangeEnd: settle
                ? (v) => onInput?.call(id, _sliderQuantize(v, min, max, step))
                : null,
          ),
          scale,
        ])));
  }

  /// Material's track is inset by max(overlay, thumb)/2 = 24 on each
  /// side (BaseSliderTrackShape.getPreferredRect); every overlay
  /// layer maps through the track's coordinate space or it only
  /// lines up with the thumb at the midpoint. Pinned by
  /// slider_geometry_probe_test so a Material redesign fails loud.
  static const double _trackInset = 24.0;

  static double _trackX(double f, double w) =>
      w > 2 * _trackInset ? _trackInset + f * (w - 2 * _trackInset) : f * w;

  Widget _sliderChip(ThemeData theme, String text, {required bool primary}) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
              color: primary
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4)),
          child: Text(text,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: primary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface)));

  /// The graded scale under a track, shared by _slider and
  /// _rangeSlider. Takes the EFFECTIVE step (materialized when the
  /// app set none), the grid the thumb actually rests on.
  Widget _sliderScale(
          ThemeData theme, double min, double max, double? effStep) =>
      SizedBox(
          height: 20,
          // Same shield as the chip rows: width intrinsics must not
          // reach the LayoutBuilder.
          child: _IntrinsicAnswer(child: LayoutBuilder(builder: (context, box) {
            // the label budget comes from the measured track width,
            // the same floor(width / 70) the browser client uses
            final maxLab = box.maxWidth.isFinite
                ? ((box.maxWidth - 2 * _trackInset) / 70).floor().clamp(2, 11)
                : 11;
            final marks = <Widget>[];
            for (final tk in _sliderTicks(min, max, effStep, maxLab)) {
              marks.add(Positioned(
                  left: _trackX(tk.f, box.maxWidth), top: 0,
                  child: Container(
                      width: 1,
                      height: tk.major ? 7 : 4,
                      color: tk.major
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.outlineVariant)));
              if (tk.major) {
                marks.add(Positioned(
                    left: _trackX(tk.f, box.maxWidth), top: 8,
                    child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Text(tk.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant)))));
              }
            }
            return Stack(clipBehavior: Clip.none, children: marks);
          })));

  /// One component, two thumbs: Material's RangeSlider under the
  /// same three number layers as _slider, emitting the pair
  /// [lo, hi]. The server keeps one value; every emitted end is
  /// quantized exactly as a single slider's would be.
  Widget _rangeSlider(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final min = _numField(c, "min") ?? 0;
    final max = _numField(c, "max") ?? 1;
    final step = _numField(c, "step");
    final raw = _value(id, c.fields['value']);
    var lo = min;
    var hi = max;
    if (raw is List && raw.length == 2) {
      lo = (raw[0] as num?)?.toDouble() ?? min;
      hi = (raw[1] as num?)?.toDouble() ?? max;
    }
    lo = lo.clamp(min, max);
    hi = hi.clamp(lo, max);
    final settle = GlintyEmit.parse(c.str('emit')) == GlintyEmit.settle;
    final theme = Theme.of(context);
    final span = max > min ? max - min : 1;
    final p1 = ((lo - min) / span).clamp(0.0, 1.0);
    final p2 = ((hi - min) / span).clamp(0.0, 1.0);
    // Shielded like _slider's: see _IntrinsicAnswer.
    final chipRow = SizedBox(
        height: 22,
        child: _IntrinsicAnswer(child: LayoutBuilder(
            builder: (context, box) => Stack(clipBehavior: Clip.none, children: [
                  if (p1 >= 0.1)
                    Positioned(left: 0, top: 0,
                        child: _sliderChip(theme, _numLabel(min),
                            primary: false)),
                  if (p2 <= 0.9)
                    Positioned(right: 0, top: 0,
                        child: _sliderChip(theme, _numLabel(max),
                            primary: false)),
                  Positioned(
                      left: _trackX(p1, box.maxWidth), top: 0,
                      child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: _sliderChip(theme, _numLabel(lo),
                              primary: true))),
                  Positioned(
                      left: _trackX(p2, box.maxWidth), top: 0,
                      child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: _sliderChip(theme, _numLabel(hi),
                              primary: true))),
                ]))));
    final effStep = step != null && step > 0
        ? step
        : (max > min ? _sliderImpliedStep(min, max) : null);
    List<double> quantized(RangeValues v) {
      final a = _sliderQuantize(v.start, min, max, step);
      final b = _sliderQuantize(v.end, min, max, step);
      return a <= b ? [a, b] : [b, a];
    }

    // _widthBounded for the same reason as _slider's.
    return _widthBounded(_labelled(
        context,
        c,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          chipRow,
          RangeSlider(
            key: Key(id),
            min: min,
            max: max,
            divisions:
                step != null && step > 0 ? ((max - min) / step).round() : null,
            values: RangeValues(lo, hi),
            onChanged: settle
                ? (v) => (onLocalInput ?? onInput)?.call(id, quantized(v))
                : (v) => onInput?.call(id, quantized(v)),
            onChangeEnd:
                settle ? (v) => onInput?.call(id, quantized(v)) : null,
          ),
          _sliderScale(theme, min, max, effStep),
        ])));
  }

  /// A dragged value quantized to the slider's real granularity:
  /// its step, or the implied step when the app set none. What the
  /// browser's range input does natively.
  static double _sliderQuantize(
      double v, double min, double max, double? step) {
    var s = step ?? 0;
    if (s <= 0 && max > min) s = _sliderImpliedStep(min, max);
    if (s <= 0) return v;
    final q = min + ((v - min) / s).round() * s;
    // step 1 must give exact integers, not 393.99999999999994
    final r = q.roundToDouble();
    return ((q - r).abs() < 1e-9 ? r : q).clamp(min, max);
  }

  /// The precision a stepless slider still has: Shiny's findStepSize
  /// rule. Integer ends spanning >= 2 mean whole numbers; otherwise
  /// a 1/2/5-ladder decimal near range/100. Mirrors
  /// slider_implied_step() in R and sliderImpliedStep() in glinty.js.
  static double _sliderImpliedStep(double min, double max) {
    final range = max - min;
    if (range >= 2 && min % 1 == 0 && max % 1 == 0) return 1;
    final raw = range / 100;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    return mag *
        (norm <= 1.5
            ? 1
            : norm <= 3.5
                ? 2
                : norm <= 7.5
                    ? 5
                    : 10);
  }

  static double _sliderSnap(double f, double min, double max, double? step) {
    var v = min + f * (max - min);
    var s = step ?? 0;
    if (s <= 0 && max > min) s = _sliderImpliedStep(min, max);
    if (s > 0) {
      v = min + ((v - min) / s).round() * s;
      v = v.clamp(min, max);
    }
    return v;
  }

  /// The scale as (fraction, major, label) ticks: on the stops when
  /// the step grid is coarse enough to see (ticks must sit where the
  /// thumb can rest), a fixed tenths grid when the slider reads as
  /// continuous. maxLabels caps the numbered majors so a narrow
  /// track stays legible; thinned positions keep their tick at
  /// minor size. Mirrors slider_ticks() in R and sliderTicks() in
  /// glinty.js; the three must agree.
  static List<({double f, bool major, String label})> _sliderTicks(
      double min, double max, double? step,
      [int maxLabels = 11]) {
    if (maxLabels < 2) maxLabels = 2;
    final ticks = <({double f, bool major, String label})>[];
    final n = step != null && step > 0 ? ((max - min) / step).round() : 0;
    if (n >= 1 &&
        n <= 20 &&
        (min + n * step! - max).abs() <
            1e-9 * (max.abs() > 1 ? max.abs() : 1)) {
      // at the default budget this is the old rule: every stop to
      // 10, every 2nd for 11-20
      final every = ((n + 1) / maxLabels).ceil();
      for (var i = 0; i <= n; i++) {
        // a regular label within one gap of the always-labeled last
        // stop yields to it
        final major = (i % every == 0 && n - i >= every) || i == n;
        ticks.add((
          f: i * step / (max - min),
          major: major,
          label: major ? _numLabel(min + i * step) : ''
        ));
        if (i < n && n <= 10 && every == 1) {
          ticks.add((f: (i + 0.5) * step / (max - min), major: false,
                     label: ''));
        }
      }
      return ticks;
    }
    final labelEvery = (11 / maxLabels).ceil();
    var prevLabel = '';
    for (var j = 0; j <= 40; j++) {
      final m = j ~/ 4;
      final major = j % 4 == 0 &&
          ((m % labelEvery == 0 && 10 - m >= labelEvery) || m == 10);
      var lab = '';
      if (major) {
        lab = _numLabel(_sliderSnap(j / 40, min, max, step));
        // a snap can land two majors on one value; a number printed
        // twice is the tick without the label
        if (lab == prevLabel) {
          lab = '';
        } else {
          prevLabel = lab;
        }
      }
      ticks.add((f: j / 40, major: major, label: lab));
    }
    return ticks;
  }

  /// The shortest plain rendering of a number: strip float noise
  /// (0.6000000000000001 from division stepping), no trailing zeros.
  /// Agrees with the browser's numLabel() and R's num_label().
  static String _numLabel(num v) {
    final d = v.toDouble();
    if (d == d.roundToDouble() && d.abs() < 1e15) {
      return d.round().toString();
    }
    var s = d.toStringAsPrecision(12);
    if (s.contains('.') && !s.contains('e')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  Widget _button(BuildContext context, GlintyComponent c) {
    // A download owns the answer to its own request, so it is
    // stateful. Keying it off the component id would put a refusal
    // earned by one button under every button sharing that id --
    // the id is routing, and several controls may share one. Flutter
    // matches unkeyed siblings positionally, which keeps each
    // button's State with the button that pressed.
    if (c.type == 'download_button' && onTicket != null) {
      return _GlintyDownloadButton(
        component: c,
        build: (context, fire, refusal, waiting) =>
            _buttonBody(context, c, fire, refusal, waiting: waiting),
        awaitTicket: awaitTicket,
        request: onTicket!,
      );
    }
    return _buttonBody(context, c, null, null);
  }

  /// The button itself, and the refusal beneath it when there is one.
  ///
  /// [onPress] overrides what a press does, which is how the stateful
  /// download wrapper registers its own waiter before asking.
  /// [waiting] disables it: a control with a request in flight has
  /// nothing to press, because the answer coming back is already
  /// spoken for.
  Widget _buttonBody(BuildContext context, GlintyComponent c,
      VoidCallback? onPress, String? refusal,
      {bool waiting = false}) {
    final id = c.str('id')!;
    final label = Text(c.str('label') ?? '');
    final icon = c.str('icon');
    final child = icon == null
        ? label
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_iconFor(icon), size: 16),
            const SizedBox(width: 6),
            label,
          ]);
    final isDownload = c.type == 'download_button';
    // modal_button(): dismisses the dialog and reports nothing.
    // Neither lowering knew the reserved id, so a Cancel rendered and
    // did nothing at all -- the same dead control the download button
    // was, arrived at the same way.
    final closes = id == glintyModalCloseId;
    // A download this client cannot deliver is a disabled button, not
    // a live one that asks for a ticket and throws it away. The gap
    // is the embedder's to close (onDownload); until then say so by
    // being unpressable rather than by doing nothing visibly. A close
    // button with nowhere to send the dismissal is dead the same way.
    final dead = waiting ||
        (isDownload && onTicket == null) ||
        (closes && onModalClose == null);
    void fire() {
      if (onPress != null) {
        onPress();
      } else if (closes) {
        onModalClose?.call();
      } else if (isDownload) {
        onTicket?.call(id, 'download');
      } else {
        onEvent?.call(id, value: c.str('value'));
      }
    }

    // Never keyed. Routing is not identity.
    //
    // A button's `id` says which handler hears the press, and nothing
    // makes it unique: two buttons may legitimately carry the same
    // one, with or without a value -- a form with Save at the top and
    // bottom is the plain case. Duplicate keys among siblings are an
    // error in Flutter, so deriving one from the id crashed on
    // exactly the trees the protocol permits.
    //
    // Unkeyed is correct rather than a workaround: a button holds no
    // state a key would preserve, and Flutter matches unkeyed
    // siblings positionally. Controls that *do* hold state -- text
    // fields, sliders -- keep their keys, because their ids really
    // are identities: an input id names one value in one store.

    final scheme = Theme.of(context).colorScheme;
    final button = switch (_variant(c.type, c.str('variant'))) {
      'primary' =>
        FilledButton(onPressed: dead ? null : fire, child: child),
      'secondary' =>
        OutlinedButton(onPressed: dead ? null : fire, child: child),
      // danger comes from the theme's danger token, which
      // glintyThemeData maps onto the scheme's error slot
      'danger' => FilledButton(
          onPressed: dead ? null : fire,
          style: FilledButton.styleFrom(
              backgroundColor: scheme.error, foregroundColor: scheme.onError),
          child: child),
      'ghost' =>
        TextButton(onPressed: dead ? null : fire, child: child),
      // one row of a list: start-aligned and body-coloured, so a
      // stack of them reads as a listing rather than a wall of pills
      'listing' => TextButton(
          onPressed: dead ? null : fire,
          style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: scheme.onSurface),
          child: child),
      _ =>
        ElevatedButton(onPressed: dead ? null : fire, child: child),
    };

    // A refused transfer, beside the control that asked. The label
    // stays its own -- overwriting it with an error string loses the
    // control -- and the message goes when the next attempt clears it.
    if (refusal == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button,
        Padding(
          padding: EdgeInsets.only(top: spacing),
          child: Text(refusal,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error)),
        ),
      ],
    );
  }

  // --- outputs ---

  String _outputText(GlintyComponent c) {
    final v = values[c.str('id')];
    return v == null ? '' : v.toString();
  }

  Widget _verbatim(BuildContext context, GlintyComponent c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        // no soft wrap: wrapping shatters the column alignment this
        // component exists to preserve; wide content scrolls
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(_outputText(c),
                softWrap: false,
                style: TextStyle(
                    fontFamily: monoStack.first,
                    fontFamilyFallback: monoStack.sublist(1)))),
      );

  Widget _table(GlintyComponent c) {
    final v = values[c.str('id')];
    if (v is! Map || v['header'] is! List) return const SizedBox.shrink();
    final header = (v['header'] as List).map((h) => h.toString()).toList();
    // A zero-column table (a server-side frame with no columns yet)
    // is an empty shell, like the browser's. Material's DataTable
    // asserts columns.isNotEmpty, and an assertion thrown mid-build
    // fails layout for everything above it -- _GlintyDataTable
    // already guards this; the plain table must too.
    if (header.isEmpty) return const SizedBox.shrink();
    // align marks numeric columns; DataColumn(numeric:) is
    // Material's own right-alignment for them
    final align =
        (v['align'] as List? ?? const []).map((a) => a.toString()).toList();
    bool numAt(int i) => i < align.length && align[i] == 'num';
    final rows = (v['rows'] as List? ?? const []).map((r) {
      final cells = (r as List).map((cell) => cell.toString()).toList();
      return DataRow(cells: cells.map((s) => DataCell(Text(s))).toList());
    }).toList();
    return DataTable(
      columns: [
        for (var i = 0; i < header.length; i++)
          DataColumn(label: Text(header[i]), numeric: numAt(i))
      ],
      rows: rows,
    );
  }

  /// The interactive table: same value as [_table], plus client-side
  /// sort, filter and pagination held in a stateful widget keyed by
  /// id. Mirrors renderDataTable in glinty.js: the two must agree.
  Widget _dataTable(GlintyComponent c) {
    final id = c.str('id')!;
    final v = values[id];
    final menu = (c.fields['length_menu'] as List? ?? const [10, 25, 50, 100])
        .whereType<num>()
        .toList();
    return _GlintyDataTable(
      key: Key(id),
      value: v is Map ? v : null,
      pageLength: c.integer('page_length') ?? 10,
      menu: menu,
      searchable: c.boolean('searchable', fallback: true),
      sortable: c.boolean('sortable', fallback: true),
    );
  }

  // --- composite ---

  Widget _tabset(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final panels = c.panels;
    final selected = _value(id, c.str('selected'))?.toString();
    final initial = panels.indexWhere((p) => p.title == selected);
    return DefaultTabController(
      key: Key(id),
      length: panels.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            tabs: panels.map((p) => Tab(text: p.title)).toList(),
            onTap: (i) => onInput?.call(id, panels[i].title),
          ),
          // Unlike flitR, every panel is built and Flutter retains the
          // state of the ones not on screen. That divergence is in
          // PROTOCOL.md; it is not something this renderer can hide.
          // IndexedStack rather than a fixed-height TabBarView: the
          // set sizes to its largest panel, so a plot living in a tab
          // keeps its real height instead of clipping at a hardcoded
          // viewport. (No swipe -- the browser's tabs don't swipe
          // either.)
          Builder(builder: (context) {
            final ctl = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: ctl,
              builder: (context, _) => IndexedStack(
                index: ctl.index,
                children: panels
                    .map((p) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: p.children
                              .map((k) => build(context, k))
                              .toList(),
                        ))
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// A fixed width, which is legal anywhere.
  ///
  /// `grow` is deliberately not handled here: it becomes `Expanded`,
  /// which is only legal as the direct child of a Flex, so [_spaced]
  /// owns it. A component that grows outside a row or column simply
  /// does not grow -- the browser behaves the same way, since
  /// flex-grow on a child of a non-flex parent does nothing.
  Widget _sized(GlintyComponent c, Widget child) {
    final width = c.integer('width');
    if (width == null) return child;
    // A declared width bounds the inside even where the outside was
    // not -- a fixed-width panel sitting shrink-wrapped in a row.
    return SizedBox(
        width: width.toDouble(), child: _bounded(child, width: true));
  }

  /// panel(max_height): the height cap, honored the way .g-capped is.
  ///
  /// A fill panel gets a bounded box for its children to divide --
  /// the letterbox shrinks media into the cap, which is the
  /// monitor-panel case the bound exists for -- so the record says
  /// height is real. (One divergence, accepted: fill under a cap
  /// sits AT the cap even when its content is short, where the
  /// browser's auto-height column hugs; the case that wants the cap
  /// is media that exceeds it, where both agree.) A plain panel
  /// scrolls what does not fit, like the browser's overflow-y, and a
  /// scroll view means unbounded inside, which the record says too.
  Widget _capped(GlintyComponent c, Widget child) {
    final cap = c.integer('max_height')?.toDouble();
    if (cap == null) return child;
    if (c.boolean('fill')) {
      return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cap),
          child: _bounded(child, height: true));
    }
    return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: cap),
        child: SingleChildScrollView(child: _bounded(child, height: false)));
  }

  /// Shrink-wraps [child] where the width record says unbounded, and
  /// leaves it alone where width is real.
  ///
  /// For widgets that need a width to lay against -- a collapse's
  /// ListTile, a slider's stretch column -- an unbounded-width spot
  /// (the non-grown child of a row) is otherwise a layout error. The
  /// browser shrink-wraps a block element there; IntrinsicWidth is
  /// that. Sizing by intrinsics means the subtree gets the same
  /// no-LayoutBuilder mark a stretch row imposes, and the tight width
  /// it resolves to is recorded.
  Widget _widthBounded(Widget child) => Builder(builder: (context) {
        if (_Bounds.maybeOf(context)?.width ?? true) return child;
        return IntrinsicWidth(
            child: _UnderIntrinsics(child: _bounded(child, width: true)));
      });

  /// The feed: a server-fed item log that owns its scroll.
  ///
  /// Items come from the session's feed store, never the tree -- the
  /// tree only places the shell. Each item is an ordinary component
  /// build wearing the record a scroller implies (width bounded by
  /// the viewport, height its own), so a grown flex inside an item
  /// answers its gate correctly. Where the feed's own height record
  /// says unbounded (a plain page), it shrink-wraps and the page
  /// scrolls, stick logic inert -- the browser's .g-feed does the
  /// same, since overflow never triggers without a bound.
  Widget _feed(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final st = feeds[id];
    final items = <Widget>[
      for (final it in st?.items ?? const <GlintyComponent>[])
        _bounded(build(context, it), width: true, height: false),
    ];
    return _GlintyFeed(
      key: Key(id),
      tick: st?.tick ?? 0,
      lastOp: st?.lastOp ?? '',
      gap: spacing * 2,
      items: items,
    );
  }

  /// A picture that is part of the UI, not an output.
  ///
  /// Same decoding as an `image` output value -- data: and http(s),
  /// anything else named rather than drawn -- because the difference
  /// between the two is where the src came from, not what it is.
  Widget _staticImage(GlintyComponent c) {
    final src = c.str('src');
    if (src == null || src.isEmpty) return const SizedBox.shrink();
    final w = c.integer('width')?.toDouble();
    final h = c.integer('height')?.toDouble();
    final label = c.str('alt');
    Widget wrap(Widget img) =>
        Semantics(label: label, image: true, child: img);
    // By scheme, not by prefix: a URI scheme is case-insensitive, so
    // DATA: names the same thing data: does, and matched literally it
    // read as a relative path to be joined to the server address.
    final scheme = (Uri.tryParse(src)?.scheme ?? '').toLowerCase();
    if (scheme == 'data') {
      try {
        return wrap(Image.memory(UriData.parse(src).contentAsBytes(),
            width: w, height: h, fit: BoxFit.contain));
      } on FormatException {
        return _problem(const Color(0xFFF8D7DA), '[this image did not decode]');
      }
    }
    if (scheme == 'http' || scheme == 'https') {
      return wrap(Image.network(src, width: w, height: h,
          fit: BoxFit.contain));
    }
    // A relative src is served by the glinty app itself. The
    // connection knows that origin because it is holding the address;
    // a bare renderer (a fixture test) does not, and says so rather
    // than guessing at a host.
    final base = assetBase;
    if (base != null) {
      return wrap(Image.network(base.resolve(src).toString(),
          width: w, height: h, fit: BoxFit.contain));
    }
    return _problem(const Color(0xFFFFF3CD),
        '[cannot load "$src": no server address to resolve it against]');
  }

  /// An audio value, handed to the app's player.
  ///
  /// The value carries what it is as well as where it is, which is
  /// the whole reason `mime` is required: a browser sniffs the bytes
  /// and a platform player asks. A value missing it is a server
  /// speaking the protocol wrongly, and saying so beats handing a
  /// player something it will fail on for reasons nobody can see.
  Widget _audio(BuildContext context, GlintyComponent c) {
    final build = audioBuilder;
    if (build == null) {
      return _problem(const Color(0xFFFFF3CD),
          '[no audio player wired: pass audioBuilder to play this]');
    }
    final value = values[c.str('id')];
    if (value is! Map) return const SizedBox.shrink();
    final src = value['src'];
    final mime = value['mime'];
    if (src is! String || src.isEmpty) return const SizedBox.shrink();
    if (mime is! String || mime.isEmpty) {
      return _problem(const Color(0xFFF8D7DA),
          '[this audio arrived without a media type]');
    }

    // By scheme, not by prefix. A URI scheme is case-insensitive, so
    // DATA:audio/wav is the same URI as data:audio/wav -- matched
    // literally it read as a relative path and got joined to the
    // server address, which is nowhere.
    final parsed = Uri.tryParse(src);
    final scheme = parsed?.scheme.toLowerCase() ?? '';
    final Uri resolved;
    if (parsed != null &&
        (scheme == 'data' || scheme == 'http' || scheme == 'https')) {
      resolved = parsed;
    } else {
      // The same rule an image follows: a relative src is served by
      // the glinty app itself, and only the connection knows that
      // address. A bare renderer says so rather than guessing a host.
      final base = assetBase;
      if (base == null) {
        return _problem(const Color(0xFFFFF3CD),
            '[cannot load "$src": no server address to resolve it against]');
      }
      resolved = base.resolve(src);
    }

    return build(
        context,
        GlintyAudioSource(
          src: resolved,
          mime: mime,
          duration: value['duration'] is num
              ? (value['duration'] as num).toDouble()
              : null,
          controls: c.boolean('controls'),
          autoplay: c.boolean('autoplay'),
        ));
  }

  /// _audio's twin: resolve, insist on the media type, hand the
  /// embedder a [GlintyVideoSource]. The value's src is a URL by the
  /// protocol's own advice -- seeking range-requests it -- so the
  /// resolution rule matters more here than anywhere.
  Widget _video(BuildContext context, GlintyComponent c) {
    final build = videoBuilder;
    if (build == null) {
      return _problem(const Color(0xFFFFF3CD),
          '[no video player wired: pass videoBuilder to play this]');
    }
    final value = values[c.str('id')];
    if (value is! Map) return const SizedBox.shrink();
    final src = value['src'];
    final mime = value['mime'];
    if (src is! String || src.isEmpty) return const SizedBox.shrink();
    if (mime is! String || mime.isEmpty) {
      return _problem(const Color(0xFFF8D7DA),
          '[this video arrived without a media type]');
    }

    Uri? resolve(String s) {
      final parsed = Uri.tryParse(s);
      final scheme = parsed?.scheme.toLowerCase() ?? '';
      if (parsed != null &&
          (scheme == 'data' || scheme == 'http' || scheme == 'https')) {
        return parsed;
      }
      return assetBase?.resolve(s);
    }

    final resolved = resolve(src);
    if (resolved == null) {
      return _problem(const Color(0xFFFFF3CD),
          '[cannot load "$src": no server address to resolve it against]');
    }
    final poster = value['poster'];

    return build(
        context,
        GlintyVideoSource(
          src: resolved,
          mime: mime,
          poster: poster is String && poster.isNotEmpty
              ? resolve(poster)
              : null,
          duration: value['duration'] is num
              ? (value['duration'] as num).toDouble()
              : null,
          controls: c.boolean('controls'),
          autoplay: c.boolean('autoplay'),
          muted: c.boolean('muted'),
          loop: c.boolean('loop'),
          // Non-null exactly when the component opted in and there is
          // a session to tell. The id is bound here so the embedder's
          // player never learns it; the throttle lives on the session.
          onReport: c.boolean('report') && onVideoReport != null
              ? (time, playing) =>
                  onVideoReport!(c.str('id')!, time, playing)
              : null,
        ));
  }

  /// A control that picks files and sends them.
  ///
  /// The button and the state around it are glinty's; the dialog and
  /// the POST are the app's, through [onUpload]. Without a handler it
  /// is a disabled control naming the gap -- the same answer a
  /// download button gives when its grant has nowhere to go.
  Widget _fileInput(BuildContext context, GlintyComponent c) {
    final id = c.str('id');
    final handler = onUpload;
    if (id == null || handler == null || awaitTicket == null) {
      return _problem(const Color(0xFFFFF3CD),
          '[no file picker wired: pass onUpload to send files]');
    }
    final base = assetBase;
    if (base == null) {
      return _problem(const Color(0xFFFFF3CD),
          '[no server address to upload to]');
    }
    return _GlintyFileInput(
      key: Key(id),
      id: id,
      label: c.str('label') ?? '',
      accept: c.strings('accept'),
      multiple: c.boolean('multiple'),
      handler: handler,
      awaitTicket: awaitTicket!,
      ticketFor: (key) => tickets[key],
      base: base,
    );
  }

  /// A section the user can fold away.
  Widget _collapse(BuildContext context, GlintyComponent c) => ExpansionTile(
        key: Key(c.str('id') ?? 'g-collapse-${c.str('title')}'),
        title: Text(c.str('title') ?? ''),
        initiallyExpanded: c.boolean('open'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(bottom: spacing * 2),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // The tile shrink-wraps its children: unbounded height inside,
        // whatever held outside.
        children: c.children
            .map((k) => _bounded(build(context, k), height: false))
            .toList(),
      );

  /// A plot: the client picks the size, the server draws to it.
  ///
  /// The half of `measure` that was missing. The protocol chose
  /// logical pixels precisely because that is Flutter's own unit, so
  /// nothing converts here -- the box goes out as-is with the device
  /// pixel ratio beside it, and the server rasterizes at their
  /// product.
  ///
  /// **Every** plot is measured, including a fixed one. The size is
  /// only half of what a measurement carries; the other half is the
  /// device pixel ratio, which the app cannot know and the server
  /// needs. A 400x300 plot that never reports is rasterized at
  /// 400x300 and drawn on a 2x screen at half the resolution it
  /// should be -- the app said how big, not how sharp. The browser
  /// walks every `img.g-plot-output` for exactly this reason.
  ///
  /// Declared dimensions win over the box on the axis that has one,
  /// which is also how a width-only plot works: the app fixed the
  /// width, the height is still the client's to decide.
  Widget _plot(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final declaredW = c.integer('width')?.toDouble();
    final declaredH = c.integer('height')?.toDouble();
    // _IntrinsicAnswer: measurement stops here with the declared
    // dimensions -- the honest answer, since that is the size the
    // plot will take -- or zero when the axis is the box's to
    // decide. The LayoutBuilder below must never see an intrinsics
    // query; see #62.
    return _IntrinsicAnswer(
        width: declaredW,
        height: declaredH,
        child: LayoutBuilder(builder: (context, box) {
      final width = declaredW ??
          (box.maxWidth.isFinite
              ? box.maxWidth
              // A height-only plot in a Row has neither a declared
              // width nor a bounded one, but it does have a ratio
              // and a height -- so the width follows, the same 4:3
              // rule read the other way. Without this the plot never
              // measured, which took the dpr with it.
              : (declaredH != null ? declaredH * 4 / 3 : double.infinity));
      if (!width.isFinite) {
        // Neither axis declared and both unbounded: nothing to
        // measure from at all. Draw what arrived, if anything, and
        // wait for a parent with an opinion about size.
        return _image(c);
      }
      // Height usually does not come from the parent: a Column lays
      // its children out with an unbounded main axis, so a plot is
      // routinely asked how tall it wants to be. The client owns that
      // answer -- "renders at the size the client gives it" is the
      // point of measure -- so it becomes a 4:3 box off the width,
      // which is the same ratio the browser's CSS commits to.
      final height = declaredH ??
          (box.maxHeight.isFinite ? box.maxHeight : width * 3 / 4);
      onMeasure?.call(
          id, width, height, MediaQuery.devicePixelRatioOf(context));
      return SizedBox(width: width, height: height, child: _image(c));
    }));
  }

  /// An `image` kind value: `{src, width, height, alt}`.
  ///
  /// `src` is a data: URI for a plot the server rasterized and may be
  /// an http(s) URL for an image an app supplied. Both decode inside
  /// the SDK; anything else is named rather than drawn, because a
  /// broken image icon says nothing about why.
  ///
  /// `width` and `height` are the value's own, in **logical** pixels,
  /// and the protocol is explicit that the client sets the display
  /// size from them and never inspects the raster. Flutter's default
  /// is the opposite: an [Image] with no size lays out at the
  /// raster's pixel count, so a plot rasterized at dpr 2 for a
  /// 400x300 box would draw 800x600 logical -- twice the size it was
  /// asked for. Inside a plot's SizedBox the constraint hides that;
  /// a bare image_output has no such constraint, so the size has to
  /// come from the wire.
  Widget _image(GlintyComponent c) {
    final v = values[c.str('id')];
    if (v is! Map) return const SizedBox.shrink();
    final src = v['src'];
    final alt = v['alt'] ?? c.str('alt');
    if (src is! String || src.isEmpty) return const SizedBox.shrink();
    final label = alt is String ? alt : null;
    final w = v['width'];
    final h = v['height'];
    final width = w is num ? w.toDouble() : null;
    final height = h is num ? h.toDouble() : null;
    if (src.startsWith('data:')) {
      try {
        return Semantics(
          label: label,
          image: true,
          child: Image.memory(UriData.parse(src).contentAsBytes(),
              width: width, height: height, fit: BoxFit.contain),
        );
      } on FormatException {
        return _problem(const Color(0xFFF8D7DA),
            '[this image did not decode]');
      }
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Semantics(
        label: label,
        image: true,
        child: Image.network(src,
            width: width, height: height, fit: BoxFit.contain),
      );
    }
    return _problem(const Color(0xFFFFF3CD),
        '[cannot load an image from ${Uri.tryParse(src)?.scheme ?? "that"}]');
  }

  Widget _unsupported(String name) => Container(
        padding: const EdgeInsets.all(8),
        color: const Color(0xFFFFF3CD),
        child: Text('[unsupported component: $name]'),
      );
}

/// Marks the subtree a stretch row measures through IntrinsicHeight.
///
/// A flex that finds this above itself answers its grow question from
/// [_Bounds] instead of interposing a LayoutBuilder, because a
/// LayoutBuilder cannot answer the intrinsics query the measurement
/// is made of -- it throws, and the whole subtree paints nothing. See
/// _flex.
///
/// An InheritedWidget rather than renderer state on purpose: the mark
/// must survive partial rebuilds (an output slot updating alone under
/// the stretch row), and only the element tree remembers ancestry
/// across those.
class _UnderIntrinsics extends InheritedWidget {
  const _UnderIntrinsics({required super.child});

  static bool present(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UnderIntrinsics>() != null;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Whether the incoming constraints are finite on each axis, recorded
/// at build time by the containers that decide it.
///
/// Under a stretch row a LayoutBuilder is off the table (see
/// [_UnderIntrinsics]), so a flex that wants to grow a child must
/// know its main axis is bounded without measuring. It can, because
/// every boundedness transition in the vocabulary is made by a
/// container this renderer builds: a Flex hands non-grown children an
/// unbounded main axis and grown ones a tight one, a scroll view and
/// a collapse un-bound height, a declared width bounds width, and the
/// stretch row's own IntrinsicHeight bounds height. Each writes what
/// it did here, and the grow gate reads the nearest record.
///
/// Inherited for the same reason the marker is: an output slot
/// rebuilding alone must still see it.
class _Bounds extends InheritedWidget {
  const _Bounds(
      {required this.width, required this.height, required super.child});

  /// True when the incoming max extent on that axis is finite.
  final bool width;
  final bool height;

  static _Bounds? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Bounds>();

  @override
  bool updateShouldNotify(_Bounds oldWidget) =>
      width != oldWidget.width || height != oldWidget.height;
}

/// Records a boundedness transition, inheriting the axis the caller
/// leaves unset. Inheriting means reading the previous record, which
/// needs a context BELOW it -- the eager recursion's [BuildContext]
/// is above the whole subtree being built -- hence the Builder.
Widget _bounded(Widget child, {bool? width, bool? height}) =>
    Builder(builder: (context) {
      final b = _Bounds.maybeOf(context);
      return _Bounds(
          // The defaults at the root, consulted only above the first
          // record: a window is finite, and a page scrolls.
          width: width ?? b?.width ?? true,
          height: height ?? b?.height ?? false,
          child: child);
    });

/// Answers intrinsics itself instead of asking its child.
///
/// The leaf LayoutBuilders -- a slider's chip and scale rows, a
/// plot's measuring box -- size overlays from the box they are given,
/// which no intrinsics answer can know. Asked anyway (a stretch row's
/// IntrinsicHeight, the IntrinsicWidth a collapse takes in an
/// unbounded row), a LayoutBuilder throws and the whole subtree
/// paints nothing. This proxy stops the question at the boundary:
/// declared dimensions when the component has them, zero when it does
/// not. Zero under-measures -- a shell sized purely by such a leaf
/// comes out too small -- and under-measuring beats a blank window.
/// Layout itself passes straight through; only measurement is
/// answered here.
class _IntrinsicAnswer extends SingleChildRenderObjectWidget {
  const _IntrinsicAnswer({this.width, this.height, required super.child});

  /// The answer for that axis, or null for zero.
  final double? width;
  final double? height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderIntrinsicAnswer(width: width, height: height);

  @override
  void updateRenderObject(
      BuildContext context, _RenderIntrinsicAnswer renderObject) {
    renderObject
      ..answerWidth = width
      ..answerHeight = height;
  }
}

class _RenderIntrinsicAnswer extends RenderProxyBox {
  _RenderIntrinsicAnswer({double? width, double? height})
      : answerWidth = width,
        answerHeight = height;

  double? answerWidth;
  double? answerHeight;

  @override
  double computeMinIntrinsicWidth(double height) => answerWidth ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => answerWidth ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => answerHeight ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => answerHeight ?? 0;
}

/// The feed's scroller, chip, and stick state.
///
/// Stateful for the same reason a text field is: the scroll position
/// and whether the reader left the bottom are the user's, and a
/// rebuild must not take them back. The contract, shared with the
/// browser client: pinned to the bottom while the reader is there
/// (an append keeps the pin, a patch keeps it through streamed
/// growth), released the moment they scroll up, a reset pins
/// unconditionally, and items arriving while unpinned show the way
/// back down instead of yanking the page.
class _GlintyFeed extends StatefulWidget {
  const _GlintyFeed({
    super.key,
    required this.tick,
    required this.lastOp,
    required this.gap,
    required this.items,
  });

  final int tick;
  final String lastOp;
  final double gap;
  final List<Widget> items;

  @override
  State<_GlintyFeed> createState() => _GlintyFeedState();
}

class _GlintyFeedState extends State<_GlintyFeed> {
  final ScrollController _scroll = ScrollController();
  bool _stuck = true;
  bool _fresh = false;
  late int _seen;

  @override
  void initState() {
    super.initState();
    // eagerly: a `late` field initialises on first ACCESS, which
    // happens inside didUpdateWidget -- by then `widget` is the new
    // one, so _seen would equal the incoming tick and swallow it
    // (the same trap _GlintyTextFieldState documents for pushes)
    _seen = widget.tick;
    _scroll.addListener(_onScroll);
    // a state born with items in the window starts at the bottom --
    // the boot-history case: the reset arrived before the first build
    if (widget.items.isNotEmpty) _pin();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // within a hair of the bottom counts as at it: fractional device
    // pixels make exact equality flap (the browser uses the same
    // tolerance)
    final pos = _scroll.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 4;
    if (atBottom == _stuck && !(atBottom && _fresh)) return;
    setState(() {
      _stuck = atBottom;
      if (atBottom) _fresh = false;
    });
  }

  void _pin() {
    _stuck = true;
    _fresh = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(_GlintyFeed old) {
    super.didUpdateWidget(old);
    if (widget.tick == _seen) return;
    _seen = widget.tick;
    if (widget.lastOp == 'reset' || _stuck) {
      _pin();
    } else if (widget.lastOp == 'append') {
      _fresh = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A viewport cannot answer an intrinsics query, and a feed
    // contributes nothing to measurement anyway -- it is a filler.
    // The record decides the mode: bounded height scrolls here,
    // unbounded shrink-wraps and lets the page scroll.
    final bounded = _Bounds.maybeOf(context)?.height ?? false;
    final children = <Widget>[
      for (var i = 0; i < widget.items.length; i++) ...[
        if (i > 0) SizedBox(height: widget.gap),
        widget.items[i],
      ],
    ];
    if (!bounded) {
      return _IntrinsicAnswer(
          child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: children));
    }
    final list = _IntrinsicAnswer(
        child: ListView(controller: _scroll, children: children));
    return Stack(children: [
      list,
      if (_fresh)
        Positioned(
          bottom: widget.gap,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(_pin),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Text('↓ Latest'),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// The renderer is stateless by design -- it turns a tree into
/// widgets and holds nothing. A text field cannot be: it owns a
/// controller and a selection, and rebuilding it from a fresh
/// controller each frame drops the caret to position zero and, with
/// any latency at all, the characters typed since the last frame.
///
/// So the controller lives here, and only follows the incoming value
/// when that value actually differs from what the field holds --
/// which is how a server-driven update_input lands without stomping
/// someone mid-word.
/// Styled runs as one Text.rich.
///
/// Stateful for exactly one reason: a linked run needs a
/// TapGestureRecognizer, and recognizers inside TextSpans are not
/// disposed by the framework -- the widget that made them owes the
/// dispose. Marks combine on a TextStyle; newlines and indent in the
/// run text are content (markdown lists arrive that way), which
/// Text renders as written.
class _GlintyRichText extends StatefulWidget {
  const _GlintyRichText(
      {required this.runs, required this.onLink, required this.monoStack});

  final List<GlintyRun> runs;
  final void Function(String href, {bool external})? onLink;
  final List<String> monoStack;

  @override
  State<_GlintyRichText> createState() => _GlintyRichTextState();
}

class _GlintyRichTextState extends State<_GlintyRichText> {
  final List<TapGestureRecognizer> _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final scheme = Theme.of(context).colorScheme;
    final spans = widget.runs.map((r) {
      var style = TextStyle(
        fontWeight: r.bold ? FontWeight.w600 : null,
        fontStyle: r.italic ? FontStyle.italic : null,
        decoration: r.strike
            ? TextDecoration.lineThrough
            : (r.href != null ? TextDecoration.underline : null),
      );
      if (r.code) {
        style = style.copyWith(
          fontFamily: widget.monoStack.first,
          fontFamilyFallback: widget.monoStack.sublist(1),
          backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
        );
      }
      TapGestureRecognizer? tap;
      final href = r.href;
      final cb = widget.onLink;
      // the schema already refused unlinkable schemes; re-checked
      // here so this client stands alone, same as the browser's
      if (href != null &&
          RegExp(r'^(https?://|mailto:|#|/)').hasMatch(href)) {
        style = style.copyWith(color: scheme.primary);
        // no handler, no tap target -- the link component's rule
        if (cb != null) {
          tap = TapGestureRecognizer()
            ..onTap = () => cb(href, external: true);
          _taps.add(tap);
        }
      }
      return TextSpan(text: r.text, style: style, recognizer: tap);
    }).toList();
    return Text.rich(TextSpan(children: spans));
  }
}

class _GlintyTextField extends StatefulWidget {
  const _GlintyTextField({
    super.key,
    required this.value,
    required this.push,
    this.clear = 0,
    this.focusTick = 0,
    this.seedTick = 0,
    required this.obscure,
    required this.maxLines,
    required this.numeric,
    this.label,
    this.hint,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.onSettle,
    this.onLocal,
    this.onFocusChanged,
  });

  final String value;

  /// How many pushes this input has had. Compared rather than the
  /// value, so a second push of the same text is still a push.
  final int push;

  /// How many clear_on clears this input has had. Applied even while
  /// focused, unlike a push -- see didUpdateWidget.
  final int clear;

  /// How many focus verbs this input has had. Applied on change AND
  /// by a state born with a nonzero count: the tree swap and the
  /// focus aimed at its composer routinely arrive in one drain, so
  /// the field's first build already carries the count.
  final int focusTick;

  /// How many times this input's region has been re-declared by a
  /// slot replacement (#79). Applied like a push -- the declared
  /// value, unless focused -- and spent either way. A reborn state
  /// already read the store at birth; this exists for the state that
  /// survives the swap.
  final int seedTick;

  final bool obscure;
  final int maxLines;
  final bool numeric;
  final String? label;
  final String? hint;
  final String? helper;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  /// Reported when focus leaves and the text has changed since it
  /// arrived. The other half of `settle`: enter is one way to finish
  /// with a field, clicking away is the more common one.
  final void Function(String)? onSettle;

  /// A local edit, not reported. Keeps conditional panels keyed on a
  /// settle field tracking what is typed.
  final void Function(String)? onLocal;

  /// Focus arrived or left. The session tracks which field holds
  /// focus so a tree swap can spare its draft (#79).
  final void Function(bool)? onFocusChanged;

  @override
  State<_GlintyTextField> createState() => _GlintyTextFieldState();
}

class _GlintyTextFieldState extends State<_GlintyTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  /// The push count this field has already answered. A push the user
  /// typed over is spent, not queued -- but a *later* push is a
  /// separate event even when it carries the same text, which is why
  /// this counts rather than remembering the value.
  late int _seen;

  /// The text this field last reported or was pushed. A settle field
  /// reports on blur only when something actually changed; focus
  /// alone is not an edit.
  late String _reported;

  /// The clear count this field has already answered.
  late int _clearSeen;

  /// The focus count this field has already answered.
  late int _focusSeen;

  /// The seed tick this field has already answered.
  late int _seedSeen;

  @override
  void initState() {
    super.initState();
    // eagerly: a `late` field initialises on first *access*, which
    // happens inside didUpdateWidget -- by then `widget` is the new
    // one, so _seen would equal the incoming push and swallow it
    _seen = widget.push;
    _clearSeen = widget.clear;
    _focusSeen = widget.focusTick;
    _seedSeen = widget.seedTick;
    _reported = widget.value;
    _focus.addListener(_onFocusChange);
    // A field born with a focus verb pending answers it: the session
    // drops an input's counter when its tree region is replaced, so a
    // nonzero count at birth is a verb aimed at THIS field (the
    // swap-then-focus drain), never one left over from a predecessor.
    // Post-frame, because the node attaches during the first build.
    if (widget.focusTick > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focus.hasFocus);
    if (_focus.hasFocus) return;
    final text = _controller.text;
    if (text == _reported) return;
    _reported = text;
    widget.onSettle?.call(text);
  }

  @override
  void didUpdateWidget(_GlintyTextField old) {
    super.didUpdateWidget(old);
    // The focus verb first, independent of the value machinery below
    // (whose branches return early). It applies whoever is focused:
    // moving the caret is not the hazard the never-stomp guard
    // refuses, and requestFocus on an already-focused node is free.
    if (widget.focusTick != _focusSeen) {
      _focusSeen = widget.focusTick;
      _focus.requestFocus();
    }
    // A clear_on clear applies even while the field has focus --
    // BECAUSE it has focus: it is causally this client's own emit
    // (enter in the composer), synchronous with it, so there is no
    // typist to race and the text it removes is exactly the text
    // that was just sent. It also spends any concurrent push: the
    // clear is the later action.
    if (widget.clear != _clearSeen) {
      _clearSeen = widget.clear;
      _seen = widget.push;
      _reported = widget.value;
      if (widget.value != _controller.text) {
        _controller.value = TextEditingValue(
          text: widget.value,
          selection:
              TextSelection.collapsed(offset: widget.value.length),
        );
      }
      return;
    }
    // The region was re-declared under a surviving state (#79): the
    // declared value applies -- the store already holds it, so
    // widget.value IS the seed -- unless this field is focused,
    // which is exactly the draft the swap must spare. Spent either
    // way, like a push the user typed over.
    if (widget.seedTick != _seedSeen) {
      _seedSeen = widget.seedTick;
      if (!_focus.hasFocus) {
        _reported = widget.value;
        if (widget.value != _controller.text) {
          _controller.value = TextEditingValue(
            text: widget.value,
            selection:
                TextSelection.collapsed(offset: widget.value.length),
          );
        }
      }
    }
    // Never while the field has focus. A server push landing
    // mid-word replaces what someone is in the middle of typing --
    // the browser client refuses this for the same reason
    // (`el !== document.activeElement`).
    //
    // Refused, not deferred: the push is marked answered so that the
    // next rebuild after focus leaves does not quietly apply it. A
    // push the user typed over is spent. Only a *later* push -- one
    // the server sent after this -- lands, whatever it carries.
    if (widget.push != _seen) {
      _seen = widget.push;
      if (_focus.hasFocus) return;
      _reported = widget.value;
    } else {
      return;
    }
    if (widget.value != _controller.text) {
      // Keep the caret where the user left it when the text is the
      // same length or longer; a server push that shortens the value
      // clamps to the end rather than pointing past it.
      final offset = _controller.selection.baseOffset;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(
            offset: offset < 0 || offset > widget.value.length
                ? widget.value.length
                : offset),
      );
    }
  }

  @override
  void dispose() {
    // A field destroyed while focused reports the loss itself: the
    // node dies without a blur, and a stale focused-id would let a
    // LATER swap preserve a draft nobody is typing. Safe during a
    // swap because the session captures the id before the tree
    // rebuilds, and the reborn field's post-frame focus re-reports.
    if (_focus.hasFocus) widget.onFocusChanged?.call(false);
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    widget.onChanged?.call(v);
    if (widget.onChanged != null) _reported = v;
    widget.onLocal?.call(v);
  }

  void _onSubmitted(String v) {
    _reported = v;
    widget.onSubmitted?.call(v);
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        keyboardType: widget.numeric ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helper,
        ),
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
      );
}

/// The interactive table. Sort, filter and page state live here, in
/// the client, where the click happened -- the server never hears
/// about a sort. Keyed by id, so the state survives value updates and
/// re-renders; a new value clamps the page instead of resetting it,
/// keeping the reader's place unless the place stopped existing.
///
/// Must agree with renderDataTable in glinty.js: case-insensitive
/// contains filter across all columns, numeric sort where the value's
/// align says "num" (a non-number in a numeric column compares equal,
/// as JS Number() -> NaN does), text sort elsewhere by code unit like
/// JS < on strings.
class _GlintyDataTable extends StatefulWidget {
  const _GlintyDataTable({
    super.key,
    required this.value,
    required this.pageLength,
    required this.menu,
    required this.searchable,
    required this.sortable,
  });

  final Map? value;
  final int pageLength;
  final List<num> menu;
  final bool searchable;
  final bool sortable;

  @override
  State<_GlintyDataTable> createState() => _GlintyDataTableState();
}

class _GlintyDataTableState extends State<_GlintyDataTable> {
  final _search = TextEditingController();
  late int _pageLength = widget.pageLength;
  int _page = 0;
  int? _sortCol;
  bool _sortAsc = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _compare(String a, String b, bool numeric) {
    if (numeric) {
      final x = num.tryParse(a);
      final y = num.tryParse(b);
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    }
    return a.compareTo(b);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final header =
        (v?['header'] as List? ?? const []).map((h) => h.toString()).toList();
    // No value yet: an empty shell, like the browser's, and like
    // _table. (Material's DataTable asserts columns.isNotEmpty, so
    // this branch is not merely cosmetic.)
    if (header.isEmpty) return const SizedBox.shrink();
    final align =
        (v?['align'] as List? ?? const []).map((a) => a.toString()).toList();
    bool numAt(int i) => i < align.length && align[i] == 'num';
    final all = (v?['rows'] as List? ?? const [])
        .map((r) => (r as List).map((c) => c.toString()).toList())
        .toList();

    final q = _search.text.toLowerCase();
    var rows = q.isEmpty
        ? all
        : all.where((r) => r.any((c) => c.toLowerCase().contains(q))).toList();
    final sc = _sortCol;
    if (sc != null && sc < header.length) {
      rows = List.of(rows)
        ..sort((a, b) {
          final d = _compare(a[sc], b[sc], numAt(sc));
          return _sortAsc ? d : -d;
        });
    }

    final total = rows.length;
    final pages = (total / _pageLength).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pages - 1);
    final from = page * _pageLength;
    final last = (from + _pageLength).clamp(0, total);
    final pageRows = rows.sublist(from, last);

    final controls = Row(children: [
      DropdownButton<int>(
        value: widget.menu.map((n) => n.toInt()).contains(_pageLength)
            ? _pageLength
            : null,
        items: [
          for (final n in widget.menu)
            DropdownMenuItem(value: n.toInt(), child: Text('$n rows'))
        ],
        onChanged: (n) => setState(() {
          if (n != null) _pageLength = n;
          _page = 0;
        }),
      ),
      if (widget.searchable) ...[
        const SizedBox(width: 12),
        Expanded(
            child: TextField(
          controller: _search,
          decoration: const InputDecoration(
              hintText: 'Search', isDense: true, prefixIcon: Icon(Icons.search)),
          onChanged: (_) => setState(() => _page = 0),
        )),
      ],
    ]);

    final table = DataTable(
      sortColumnIndex: sc != null && sc < header.length ? sc : null,
      sortAscending: _sortAsc,
      columns: [
        for (var i = 0; i < header.length; i++)
          DataColumn(
            label: Text(header[i]),
            numeric: numAt(i),
            onSort: widget.sortable
                ? (i, asc) => setState(() {
                      _sortCol = i;
                      _sortAsc = asc;
                    })
                : null,
          )
      ],
      rows: [
        for (final r in pageRows)
          DataRow(cells: [for (final c in r) DataCell(Text(c))])
      ],
    );

    final info = total == 0
        ? 'No rows'
        : 'Showing ${from + 1}–$last of $total'
            '${q.isNotEmpty && all.length != total ? ' (filtered from ${all.length})' : ''}';
    final footer = Row(children: [
      Expanded(child: Text(info)),
      TextButton(
          onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
          child: const Text('‹ Prev')),
      TextButton(
          onPressed: page < pages - 1
              ? () => setState(() => _page = page + 1)
              : null,
          child: const Text('Next ›')),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      controls,
      SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: table)),
      footer,
    ]);
  }
}

/// A download button that owns the answer to its own request.
///
/// Stateful because the answer belongs to the press, not to the id.
/// A button's id is routing -- several controls may carry the same
/// one -- so a refusal held against the id would appear under every
/// button sharing that name. State stays with the widget that pressed,
/// which is what Flutter's positional matching of unkeyed siblings
/// gives for free.
class _GlintyDownloadButton extends StatefulWidget {
  const _GlintyDownloadButton({
    required this.component,
    required this.build,
    required this.awaitTicket,
    required this.request,
  });

  final GlintyComponent component;

  /// Draws the button, given what a press does, the refusal to show
  /// beneath it, and whether a request of its own is in flight.
  final Widget Function(BuildContext, VoidCallback, String?, bool) build;

  final void Function() Function(
      String, String, void Function(String?))? awaitTicket;
  final GlintyTicketSink request;

  @override
  State<_GlintyDownloadButton> createState() => _GlintyDownloadButtonState();
}

class _GlintyDownloadButtonState extends State<_GlintyDownloadButton> {
  String? _refusal;
  void Function()? _cancel;
  bool _waiting = false;

  @override
  void dispose() {
    // A control that goes away before its answer arrives cancels,
    // which leaves a tombstone: the request is still on the wire and
    // its answer still has to be consumed, or the next control in
    // line is handed it.
    _cancel?.call();
    super.dispose();
  }

  void _press() {
    final id = widget.component.str('id')!;
    final ask = widget.awaitTicket;
    if (ask == null) {
      // Nothing to wait in. An embedder can wire onTicket without
      // awaitTicket -- GlintyRenderer takes them separately -- and
      // then no answer ever reaches this button. Waiting for one it
      // cannot hear would disable it after a single press, for good.
      widget.request(id, 'download');
      return;
    }
    setState(() {
      // Asking again clears the last answer: a refusal belongs to the
      // attempt that earned it.
      _refusal = null;
      _waiting = true;
    });
    // Asks and registers in one step. Asking separately would put the
    // request on the wire in one order and in the ledger in another,
    // and the answers would cross.
    _cancel = ask(id, 'download', (refusal) {
      _cancel = null;
      if (!mounted) return;
      setState(() {
        _refusal = refusal;
        _waiting = false;
      });
    });
  }

  // Unpressable while it waits. Two presses are two requests, and the
  // second cancels the first's waiter to take its place -- so answer
  // one lands on press two. There is one of this control, and it can
  // only be waiting for one thing.
  @override
  Widget build(BuildContext context) =>
      widget.build(context, _press, _refusal, _waiting);
}

/// The file_input control: a button, what it is doing, and why it
/// stopped if it did.
///
/// Stateful for the same reason the download button is: the answer to
/// its own request belongs to it, and holding it against the input id
/// would put one control's refusal under another sharing the name.
class _GlintyFileInput extends StatefulWidget {
  const _GlintyFileInput({
    super.key,
    required this.id,
    required this.label,
    required this.accept,
    required this.multiple,
    required this.handler,
    required this.awaitTicket,
    required this.ticketFor,
    required this.base,
  });

  final String id;
  final String label;
  final List<String> accept;
  final bool multiple;
  final GlintyUploadHandler handler;
  final void Function() Function(String, String, void Function(String?))
      awaitTicket;
  final Map<String, dynamic>? Function(String key) ticketFor;
  final Uri base;

  @override
  State<_GlintyFileInput> createState() => _GlintyFileInputState();
}

class _GlintyFileInputState extends State<_GlintyFileInput> {
  bool _busy = false;
  String? _problem;
  void Function()? _cancel;

  @override
  void dispose() {
    // The request is on the wire and its answer still has to be
    // consumed, or the next control in line is handed it.
    _cancel?.call();
    super.dispose();
  }

  /// Asks for a ticket and turns the grant into a POST target.
  Future<Uri> _target() {
    final answer = Completer<Uri>();
    _cancel = widget.awaitTicket(widget.id, 'upload', (refusal) {
      _cancel = null;
      if (answer.isCompleted) return;
      if (refusal != null) {
        answer.completeError(GlintyTransferRefused(refusal));
        return;
      }
      final token = widget.ticketFor('upload:${widget.id}')?['token'];
      if (token is! String || token.isEmpty) {
        answer.completeError(
            const GlintyTransferRefused('the server answered without a '
                'ticket'));
        return;
      }
      answer.complete(widget.base.replace(
          path: '/upload', queryParameters: {'ticket': token}));
    });
    return answer.future;
  }

  Future<void> _press() async {
    setState(() {
      _problem = null;
      _busy = true;
    });
    String? failure;
    try {
      await widget.handler(
          context,
          GlintyUploadRequest(
            id: widget.id,
            accept: widget.accept,
            multiple: widget.multiple,
            target: _target,
          ));
    } on GlintyTransferRefused catch (e) {
      failure = e.message;
    } catch (e) {
      failure = 'the upload did not complete';
    }
    if (!mounted) return;
    setState(() {
      _problem = failure;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(widget.label),
          ),
        OutlinedButton.icon(
          // Unpressable while it works, like every other control that
          // has a request in flight.
          onPressed: _busy ? null : _press,
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(_busy ? 'Sending…' : 'Choose file'),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_problem!, style: TextStyle(color: scheme.error)),
          ),
      ],
    );
  }
}

/// One key binding, live for as long as it is in the tree.
///
/// Stateful because the handler has to be added and removed with the
/// widget: a shortcut that outlives its tree is exactly the registry
/// drift this component exists to avoid, and Flutter's own dispose is
/// the only thing that knows when the tree changed.
///
/// It occupies no space. Put one anywhere.
class _GlintyShortcut extends StatefulWidget {
  const _GlintyShortcut({
    required this.physical,
    required this.ctrl,
    required this.shift,
    required this.alt,
    required this.typing,
    required this.hold,
    required this.fire,
  });

  final PhysicalKeyboardKey physical;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool typing;
  final bool hold;
  final VoidCallback fire;

  @override
  State<_GlintyShortcut> createState() => _GlintyShortcutState();
}

class _GlintyShortcutState extends State<_GlintyShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handle);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handle);
    super.dispose();
  }

  /// Is focus in something that owns its own keystrokes?
  ///
  /// An editable field types letters, so a bare "d" belongs to it and
  /// not to the shortcut that would delete a clip. Asked of the focus
  /// tree rather than of a widget type, because a client embedding
  /// glinty may put its own text fields on the page too.
  bool get _typingNow {
    final node = FocusManager.instance.primaryFocus;
    if (node == null) return false;
    final ctx = node.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
        ctx.widget is EditableText;
  }

  bool _handle(KeyEvent event) {
    final held = event is KeyRepeatEvent;
    if (event is! KeyDownEvent && !held) return false;
    if (event.physicalKey != widget.physical) return false;
    // Autorepeat only reaches a binding that asked for it: a held
    // "space" must not fire play sixty times.
    if (held && !widget.hold) return false;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    bool down(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        keys.contains(a) || keys.contains(b);
    // Meta is Ctrl's equal here, as it is in the R constructor: an app
    // that means "the platform's command modifier" says it once.
    final ctrl = down(LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.controlRight) ||
        down(LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight);
    final shift =
        down(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight);
    final alt = down(LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight);
    if (ctrl != widget.ctrl) return false;
    if (shift != widget.shift) return false;
    if (alt != widget.alt) return false;
    if (_typingNow && !widget.typing) return false;
    widget.fire();
    // Handled: a declared shortcut takes the keypress, so nothing
    // further up gets a second go at it.
    return true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
