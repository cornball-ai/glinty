/// The client's view of its own inputs.
///
/// A renderer that reads a control's value out of the component tree
/// draws the *initial* value forever: the tree is the shape of the
/// UI, not its state. So the session keeps the state, seeded from
/// the tree the way the server seeds its own (see R/seed.R -- the
/// rules match on purpose), updated by user edits and by
/// `input_update` frames.
///
/// Conditional panels read the same store, which is why the rule
/// for "what counts as a match" lives here too and mirrors R's
/// condition_matches() and the browser's condMatches().
library;

import 'component.dart';

/// Walk a tree, collecting the value each input starts at.
///
/// The mirror of R's collect_input_seeds(): text-like inputs start
/// at their value or "", checkboxes at false, a single select at its
/// first choice, a slider at its position, a tabset at the shown
/// panel. An input the tree gives nothing to (an empty number field,
/// a multi-select, a file input, a button) simply has no entry.
Map<String, dynamic> seedInputs(GlintyComponent? tree) {
  final out = <String, dynamic>{};
  void walk(GlintyComponent c) {
    final id = c.str('id');
    if (id != null) {
      final seed = _seedFor(c);
      if (seed != null) out.putIfAbsent(id, () => seed);
    }
    for (final child in c.children) {
      walk(child);
    }
    for (final panel in c.panels) {
      for (final child in panel.children) {
        walk(child);
      }
    }
  }

  if (tree != null) walk(tree);
  return out;
}

dynamic _seedFor(GlintyComponent c) {
  switch (c.type) {
    case 'text_input':
    case 'password_input':
    case 'textarea_input':
    case 'date_input':
      return c.str('value') ?? '';
    case 'number_input':
      return c.number('value');
    case 'checkbox_input':
      return c.boolean('value');
    case 'radio_buttons':
      return c.str('selected');
    case 'slider_input':
      return c.number('value') ?? c.number('min');
    case 'select_input':
      if (c.boolean('multiple')) return null;
      final selected = c.str('selected');
      if (selected != null) return selected;
      final choices = c.choices;
      return choices.isEmpty ? null : choices.first.value;
    case 'tabset':
      final panels = c.panels;
      if (panels.isEmpty) return null;
      final selected = c.str('selected');
      if (selected != null && panels.any((p) => p.title == selected)) {
        return selected;
      }
      return panels.first.title;
    default:
      return null;
  }
}

/// Does one input value match any of a condition's candidates?
///
/// The rule the whole protocol shares: logicals compare by
/// truthiness, everything else by string, and an input that was
/// never set matches nothing.
bool conditionMatches(dynamic actual, List<dynamic> wanted) {
  for (final w in wanted) {
    if (w is bool || actual is bool) {
      if (_truthy(actual) == _truthy(w)) return true;
    } else {
      if (actual == null) continue;
      if (actual.toString() == w.toString()) return true;
    }
  }
  return false;
}

bool _truthy(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == 'TRUE';
  return v != null;
}

/// Evaluate a conditional_panel's condition against current inputs.
///
/// The twin of R's eval_condition() and the browser's
/// evalCondition(). An unknown operator is false rather than an
/// error: a server one release newer may know operators this client
/// does not, and hiding a panel is the safe reading.
bool evalCondition(dynamic cond, Map<String, dynamic> inputs) {
  if (cond is! Map) return false;
  switch (cond['op']) {
    case 'is':
      final id = cond['id'];
      if (id is! String || !inputs.containsKey(id)) return false;
      final values = cond['values'];
      return conditionMatches(
          inputs[id], values is List ? values : [values]);
    case 'and':
      final args = cond['args'];
      if (args is! List) return false;
      return args.every((a) => evalCondition(a, inputs));
    case 'or':
      final args = cond['args'];
      if (args is! List) return false;
      return args.any((a) => evalCondition(a, inputs));
    case 'not':
      return !evalCondition(cond['arg'], inputs);
    default:
      return false;
  }
}
