/// A glinty protocol v3 component, as it arrives on the wire.
///
/// This is the Dart peer of glinty's R-side component representation.
/// It is deliberately dumb: parse, expose fields, and let the renderer
/// decide what to build. Nothing here knows about Flutter widgets, and
/// nothing here knows about the DOM.
library;

class GlintyComponent {
  GlintyComponent(this.type, this.fields);

  final String type;
  final Map<String, dynamic> fields;

  /// Parse one component, recursing into `children` and `panels`.
  ///
  /// Throws [FormatException] on a malformed node rather than
  /// returning something half-built: the R side validates at
  /// construction, so anything malformed here is a protocol bug worth
  /// surfacing loudly.
  factory GlintyComponent.fromJson(dynamic json) {
    if (json is! Map) {
      throw FormatException('component must be an object, got $json');
    }
    final type = json['component'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('component is missing its `component` field');
    }
    final fields = <String, dynamic>{};
    for (final entry in json.entries) {
      if (entry.key == 'component') continue;
      fields[entry.key as String] = entry.value;
    }
    return GlintyComponent(type, fields);
  }

  String? str(String name) {
    final v = fields[name];
    return v?.toString();
  }

  num? number(String name) {
    final v = fields[name];
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  int? integer(String name) => number(name)?.toInt();

  bool boolean(String name, {bool fallback = false}) {
    final v = fields[name];
    if (v is bool) return v;
    return fallback;
  }

  /// Child components, empty when the field is absent.
  List<GlintyComponent> get children {
    final raw = fields['children'];
    if (raw is! List) return const [];
    return raw.map(GlintyComponent.fromJson).toList();
  }

  /// Tabset panels: a title plus its own children.
  List<GlintyPanel> get panels {
    final raw = fields['panels'];
    if (raw is! List) return const [];
    return raw.map((p) {
      if (p is! Map) {
        throw FormatException('panel must be an object, got $p');
      }
      final title = p['title'];
      if (title is! String || title.isEmpty) {
        throw const FormatException('panel is missing its title');
      }
      final kids = p['children'];
      return GlintyPanel(
        title,
        kids is List ? kids.map(GlintyComponent.fromJson).toList() : const [],
      );
    }).toList();
  }

  /// Select and radio choices, normalized on the R side to value/label.
  List<GlintyChoice> get choices {
    final raw = fields['choices'];
    if (raw is! List) return const [];
    return raw.map((c) {
      if (c is! Map || c['value'] == null || c['label'] == null) {
        throw FormatException('choice needs both a value and a label: $c');
      }
      return GlintyChoice(c['value'].toString(), c['label'].toString());
    }).toList();
  }

  @override
  String toString() => 'GlintyComponent($type, ${fields.keys.join(", ")})';
}

class GlintyPanel {
  const GlintyPanel(this.title, this.children);
  final String title;
  final List<GlintyComponent> children;
}

class GlintyChoice {
  const GlintyChoice(this.value, this.label);
  final String value;
  final String label;
}

/// When an input reports its value.
///
/// The protocol says intent, not mechanism: `live` means report while
/// the value is changing, `settle` means report once it has. Flutter
/// spends that on onChanged versus onEditingComplete.
enum GlintyEmit {
  live,
  settle;

  static GlintyEmit parse(String? raw) =>
      raw == 'settle' ? GlintyEmit.settle : GlintyEmit.live;
}
