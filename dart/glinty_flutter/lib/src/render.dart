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

import 'package:flutter/material.dart';

import 'component.dart';

/// What a client can do, declared in `hello`.
///
/// The server never negotiates: a component this renderer does not
/// know draws a visible placeholder naming it.
const supportedComponents = <String>{
  'text', 'heading', 'link', 'icon', 'divider', 'spacer',
  'page', 'row', 'column', 'panel',
  'text_input', 'password_input', 'textarea_input', 'number_input',
  'select_input', 'checkbox_input', 'radio_buttons', 'slider_input',
  'button', 'download_button',
  'text_output', 'verbatim_output', 'table_output',
  'plot_output', 'image_output', 'image',
  'tabset', 'conditional_panel', 'collapse',
};

/// Components the protocol defines that this client cannot render.
///
/// Named rather than omitted, so the gap is visible in a running app.
const unsupportedComponents = <String>{
  'date_input', // showDatePicker is a dialog, not an inline control
  'file_input', // needs the file_picker package, outside the SDK
  // The protocol side of this exists (the `ui` output kind); this
  // renderer has not grown the client half -- building a component
  // tree that arrived as a value into its slot.
  'ui_output',
  'audio_output', // needs an audio package, outside the SDK
  // Both carry markup, which has no Flutter equivalent by design.
  // raw_html is markup in the tree; html_output is markup arriving
  // as a value. Same refusal for the same reason.
  'raw_html',
  'html_output',
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

class GlintyRenderer {
  GlintyRenderer(
      {this.onInput,
      this.onLocalInput,
      this.onLink,
      this.onEvent,
      this.onTicket,
      this.onModalClose,
      this.onMeasure,
      this.assetBase,
      this.values = const {},
      this.kinds = const {},
      this.errors = const {},
      this.inputs = const {},
      this.pushes = const {},
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

  /// Where a responsive plot reports its box. Null in a fixture
  /// render, where there is no server to tell -- the plot then draws
  /// whatever value it was given and measures nothing.
  final GlintyMeasureSink? onMeasure;

  /// The theme's base spacing unit in logical pixels. spacer() sizes
  /// are multiples of it -- the same rule the browser applies through
  /// --g-space, and the same default when no theme was set.
  final double spacing;

  /// The family stack for verbatim output -- the same role
  /// --g-font-mono plays in the browser, resolved to families the
  /// platform can know (see glintyMonoStack). Leads with the theme's
  /// choice and degrades within the mono role.
  final List<String> monoStack;

  /// The spec's fallback rule: unknown variants take the first
  /// listed, with a warning rather than an error, because a
  /// same-protocol server one release newer may know variants this
  /// client does not.
  static const _knownVariants = <String, List<String>>{
    'text': ['normal', 'muted', 'strong', 'heading'],
    'text_output': ['normal', 'muted', 'strong'],
    'button': ['default', 'primary', 'secondary', 'danger', 'ghost'],
    'download_button': ['default', 'primary', 'secondary', 'danger', 'ghost'],
    'panel': ['plain', 'card', 'sidebar'],
    'divider': ['line', 'labelled'],
  };

  String _variant(String component, String? variant) {
    final known = _knownVariants[component];
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

  /// Latest value per output id, as delivered by `output` messages.
  final Map<String, dynamic> values;

  /// What each value IS, from the `kind` field of the same message.
  /// A slot whose value arrives as a kind it cannot draw says so by
  /// name; without this it would stringify the payload instead, and
  /// an image would render as `{src: data:image/png;base64,iVBOR...`.
  final Map<String, String> kinds;

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
        return _collapse(context, c);
      // page is never a flex child -- it is the root -- so it skips
      // the sizing wrapper the other three take.
      case 'page':
        return _column(context, c);
      case 'column':
        return _sized(c, _column(context, c));
      case 'row':
        return _sized(c, _row(context, c));
      case 'panel':
        return _sized(c, _panel(context, c));
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
      case 'slider_input':
        return _slider(context, c);
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
      case 'plot_output':
        return _slot(context, c, 'image', () => _plot(context, c));
      case 'image_output':
        return _slot(context, c, 'image', () => _image(c));
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
      default:
        return _unsupported(c.type);
    }
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
      final child = build(context, kids[i]);
      out.add(canGrow && grow > 0 ? Expanded(flex: grow, child: child) : child);
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
  Widget _flex(BuildContext context, GlintyComponent c, bool row) {
    final gap = c.number('gap')?.toDouble() ?? 0;
    final wants = c.children.any((k) => (k.integer('grow') ?? 0) > 0);
    Widget make(bool canGrow) {
      final kids = _spaced(context, c.children, gap, row, canGrow: canGrow);
      return row
          ? Row(
              mainAxisSize: canGrow ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: switch (c.str('align')) {
                'center' => CrossAxisAlignment.center,
                'end' => CrossAxisAlignment.end,
                _ => CrossAxisAlignment.start,
              },
              children: kids)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: canGrow ? MainAxisSize.max : MainAxisSize.min,
              children: kids);
    }

    // No grown child means no constraint to check, and no reason to
    // pay for a LayoutBuilder on every container in the tree.
    if (!wants) return make(false);
    return LayoutBuilder(builder: (context, box) {
      final bounded = row ? box.maxWidth.isFinite : box.maxHeight.isFinite;
      return make(bounded);
    });
  }

  Widget _column(BuildContext context, GlintyComponent c) =>
      _flex(context, c, false);

  Widget _row(BuildContext context, GlintyComponent c) =>
      _flex(context, c, true);

  Widget _panel(BuildContext context, GlintyComponent c) {
    final title = c.str('title');
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
        ...c.children.map((k) => build(context, k)),
      ],
    );
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
    return CheckboxListTile(
      key: Key(id),
      value: _value(id, c.boolean('value')) == true,
      title: Text(_label(c) ?? ""),
      onChanged: (v) => onInput?.call(id, v ?? false),
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

  Widget _slider(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final min = _numField(c, "min") ?? 0;
    final max = _numField(c, "max") ?? 1;
    final step = _numField(c, "step");
    final raw = _value(id, c.number('value'));
    final current = raw is num ? raw.toDouble() : min;
    final settle = GlintyEmit.parse(c.str('emit')) == GlintyEmit.settle;
    return _labelled(
        context,
        c,
        Slider(
          key: Key(id),
          min: min,
          max: max,
          // Flutter wants a division count where the protocol says
          // step size. Derivable because step is a number.
          divisions:
              step != null && step > 0 ? ((max - min) / step).round() : null,
          value: current.clamp(min, max),
          // Where `emit` is spent for a slider. A drag is one
          // gesture producing hundreds of onChanged calls; under
          // `settle` the server wants the number the user landed on,
          // not the sweep. Local edits keep the thumb (and any panel
          // keyed on it) tracking the finger in the meantime.
          onChanged: settle
              ? (v) => (onLocalInput ?? onInput)?.call(id, v)
              : (v) => onInput?.call(id, v),
          onChangeEnd: settle ? (v) => onInput?.call(id, v) : null,
        ));
  }

  Widget _button(BuildContext context, GlintyComponent c) {
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
    final dead = (isDownload && onTicket == null) ||
        (closes && onModalClose == null);
    void fire() {
      if (closes) {
        onModalClose?.call();
      } else if (isDownload) {
        onTicket?.call(id, 'download');
      } else {
        onEvent?.call(id, value: c.str('value'));
      }
    }

    // The id says which handler hears this, not which widget it is.
    // A list of rows shares one handler -- that is what `value` is
    // for -- and duplicate keys among siblings are an error in
    // Flutter, so a valued button keys on the pair.
    final v = c.str('value');
    final key = Key(v == null ? id : '$id:$v');

    final scheme = Theme.of(context).colorScheme;
    return switch (_variant(c.type, c.str('variant'))) {
      'primary' =>
        FilledButton(key: key, onPressed: dead ? null : fire, child: child),
      'secondary' =>
        OutlinedButton(key: key, onPressed: dead ? null : fire, child: child),
      // danger comes from the theme's danger token, which
      // glintyThemeData maps onto the scheme's error slot
      'danger' => FilledButton(
          key: key,
          onPressed: dead ? null : fire,
          style: FilledButton.styleFrom(
              backgroundColor: scheme.error, foregroundColor: scheme.onError),
          child: child),
      'ghost' =>
        TextButton(key: key, onPressed: dead ? null : fire, child: child),
      _ =>
        ElevatedButton(key: key, onPressed: dead ? null : fire, child: child),
    };
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
        child: Text(_outputText(c),
            style: TextStyle(
                fontFamily: monoStack.first,
                fontFamilyFallback: monoStack.sublist(1))),
      );

  Widget _table(GlintyComponent c) {
    final v = values[c.str('id')];
    if (v is! Map || v['header'] is! List) return const SizedBox.shrink();
    final header = (v['header'] as List).map((h) => h.toString()).toList();
    final rows = (v['rows'] as List? ?? const []).map((r) {
      final cells = (r as List).map((cell) => cell.toString()).toList();
      return DataRow(cells: cells.map((s) => DataCell(Text(s))).toList());
    }).toList();
    return DataTable(
      columns: header.map((h) => DataColumn(label: Text(h))).toList(),
      rows: rows,
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
          SizedBox(
            height: 200,
            child: TabBarView(
              children: panels
                  .map((p) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children:
                            p.children.map((k) => build(context, k)).toList(),
                      ))
                  .toList(),
            ),
          ),
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
    return SizedBox(width: width.toDouble(), child: child);
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
    if (src.startsWith('data:')) {
      try {
        return wrap(Image.memory(UriData.parse(src).contentAsBytes(),
            width: w, height: h, fit: BoxFit.contain));
      } on FormatException {
        return _problem(const Color(0xFFF8D7DA), '[this image did not decode]');
      }
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
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

  /// A section the user can fold away.
  Widget _collapse(BuildContext context, GlintyComponent c) => ExpansionTile(
        key: Key(c.str('id') ?? 'g-collapse-${c.str('title')}'),
        title: Text(c.str('title') ?? ''),
        initiallyExpanded: c.boolean('open'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(bottom: spacing * 2),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: c.children.map((k) => build(context, k)).toList(),
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
    return LayoutBuilder(builder: (context, box) {
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
    });
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

/// A text field that keeps its controller across rebuilds.
///
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
class _GlintyTextField extends StatefulWidget {
  const _GlintyTextField({
    super.key,
    required this.value,
    required this.push,
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
  });

  final String value;

  /// How many pushes this input has had. Compared rather than the
  /// value, so a second push of the same text is still a push.
  final int push;

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

  @override
  void initState() {
    super.initState();
    // eagerly: a `late` field initialises on first *access*, which
    // happens inside didUpdateWidget -- by then `widget` is the new
    // one, so _seen would equal the incoming push and swallow it
    _seen = widget.push;
    _reported = widget.value;
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    final text = _controller.text;
    if (text == _reported) return;
    _reported = text;
    widget.onSettle?.call(text);
  }

  @override
  void didUpdateWidget(_GlintyTextField old) {
    super.didUpdateWidget(old);
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
