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
  'tabset', 'conditional_panel',
};

/// Components the protocol defines that this client cannot render.
///
/// Named rather than omitted, so the gap is visible in a running app.
const unsupportedComponents = <String>{
  'date_input', // showDatePicker is a dialog, not an inline control
  'file_input', // needs the file_picker package, outside the SDK
  // The protocol side of these exists (measure messages, image and
  // ui output kinds); this renderer has not grown the client half:
  // LayoutBuilder-driven measurement for plots, and building a
  // ui-kind value into its slot.
  'plot_output',
  'image_output',
  'ui_output',
  'audio_output', // needs an audio package, outside the SDK
  'raw_html', // arbitrary markup has no Flutter equivalent, by design
};

/// Reports an input change back to the server.
typedef GlintySink = void Function(String id, dynamic value);

/// Reports a discrete event back to the server.
typedef GlintyEventSink = void Function(String id);

/// Asks the server for a transfer ticket.
typedef GlintyTicketSink = void Function(String id, String purpose);

class GlintyRenderer {
  GlintyRenderer(
      {this.onInput,
      this.onLink,
      this.onEvent,
      this.onTicket,
      this.values = const {},
      this.inputs = const {},
      this.overrides = const {},
      this.condition,
      this.spacing = 4,
      this.monoStack = const ['monospace', 'Menlo', 'Courier New']});

  final GlintySink? onInput;
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

  /// Latest value per output id, as delivered by `output` messages.
  final Map<String, dynamic> values;

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
      case 'page':
      case 'column':
        return _column(context, c);
      case 'row':
        return _row(context, c);
      case 'panel':
        return _panel(context, c);
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
        return _radios(c);
      case 'slider_input':
        return _slider(c);
      case 'button':
      case 'download_button':
        return _button(context, c);
      case 'text_output':
        return Text(_outputText(c), style: _textStyleFor(context, c));
      case 'verbatim_output':
        return _verbatim(context, c);
      case 'table_output':
        return _table(c);
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
    final label = Text(
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

  List<Widget> _spaced(
      BuildContext context, List<GlintyComponent> kids, double gap, bool row) {
    final out = <Widget>[];
    for (var i = 0; i < kids.length; i++) {
      if (i > 0 && gap > 0) {
        out.add(row ? SizedBox(width: gap) : SizedBox(height: gap));
      }
      out.add(build(context, kids[i]));
    }
    return out;
  }

  Widget _column(BuildContext context, GlintyComponent c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children:
            _spaced(context, c.children, c.number('gap')?.toDouble() ?? 0, false),
      );

  Widget _row(BuildContext context, GlintyComponent c) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (c.str('align')) {
          'center' => CrossAxisAlignment.center,
          'end' => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children:
            _spaced(context, c.children, c.number('gap')?.toDouble() ?? 0, true),
      );

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
    return _GlintyTextField(
      key: Key(id),
      value: _value(id, c.str('value') ?? '')?.toString() ?? '',
      obscure: obscure,
      maxLines: maxLines,
      numeric: numeric,
      label: _label(c),
      hint: c.str('placeholder'),
      // This is where `emit` is spent, and the only place that knows
      // Flutter calls these onChanged and onSubmitted.
      onChanged: emit == GlintyEmit.live ? report : null,
      onSubmitted: emit == GlintyEmit.settle ? report : null,
    );
  }

  Widget _select(BuildContext context, GlintyComponent c) {
    final id = c.str('id')!;
    final choices = _choices(c);
    final current = _value(id, c.str('selected'))?.toString() ??
        (choices.isNotEmpty ? choices.first.value : null);
    return DropdownButton<String>(
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
    );
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

  Widget _radios(GlintyComponent c) {
    final id = c.str('id')!;
    // RadioGroup replaced per-tile groupValue/onChanged in 3.32.
    return RadioGroup<String>(
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
      ));
  }

  Widget _slider(GlintyComponent c) {
    final id = c.str('id')!;
    final min = _numField(c, "min") ?? 0;
    final max = _numField(c, "max") ?? 1;
    final step = _numField(c, "step");
    final raw = _value(id, c.number('value'));
    final current = raw is num ? raw.toDouble() : min;
    return Slider(
      key: Key(id),
      min: min,
      max: max,
      // Flutter wants a division count where the protocol says step
      // size. Derivable because step is a number.
      divisions: step != null && step > 0 ? ((max - min) / step).round() : null,
      value: current.clamp(min, max),
      onChanged: (v) => onInput?.call(id, v),
    );
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
    void fire() {
      if (isDownload) {
        onTicket?.call(id, 'download');
      } else {
        onEvent?.call(id);
      }
    }

    final scheme = Theme.of(context).colorScheme;
    return switch (_variant(c.type, c.str('variant'))) {
      'primary' => FilledButton(key: Key(id), onPressed: fire, child: child),
      'secondary' =>
        OutlinedButton(key: Key(id), onPressed: fire, child: child),
      // danger comes from the theme's danger token, which
      // glintyThemeData maps onto the scheme's error slot
      'danger' => FilledButton(
          key: Key(id),
          onPressed: fire,
          style: FilledButton.styleFrom(
              backgroundColor: scheme.error, foregroundColor: scheme.onError),
          child: child),
      'ghost' => TextButton(key: Key(id), onPressed: fire, child: child),
      _ => ElevatedButton(key: Key(id), onPressed: fire, child: child),
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
    required this.obscure,
    required this.maxLines,
    required this.numeric,
    this.label,
    this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  final String value;
  final bool obscure;
  final int maxLines;
  final bool numeric;
  final String? label;
  final String? hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  @override
  State<_GlintyTextField> createState() => _GlintyTextFieldState();
}

class _GlintyTextFieldState extends State<_GlintyTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(_GlintyTextField old) {
    super.didUpdateWidget(old);
    // Never while the field has focus. A server push landing
    // mid-word replaces what someone is in the middle of typing --
    // the browser client refuses this for the same reason
    // (`el !== document.activeElement`).
    if (_focus.hasFocus) return;
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
    _controller.dispose();
    super.dispose();
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
        ),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      );
}
