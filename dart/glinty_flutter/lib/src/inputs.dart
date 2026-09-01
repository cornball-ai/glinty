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
      // R's slider_default(): the midpoint, which is where an HTML
      // range input sits with no value. Seeding to min would put the
      // thumb somewhere the server does not think it is.
      final v = c.number('value');
      if (v != null) return v;
      final min = c.number('min') ?? 0;
      final max = c.number('max') ?? 1;
      return min + (max - min) / 2;
    case 'select_input':
      // A multiple select with nothing chosen has an empty selection,
      // not an absent one -- the browser harvests `[]` from
      // selectedOptions, and seeding null here would make this client
      // disagree with the other two before anyone had touched it.
      if (c.boolean('multiple')) return c.strings('selected');
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
    case 'data_table':
      // A selectable table starts with nothing selected: an empty
      // list, not an absence -- the multiple-select rule again. With
      // no selection mode the table is not an input and seeds
      // nothing, as R/seed.R says.
      final mode = c.str('selection') ?? 'none';
      return mode == 'none' ? null : <String>[];
    default:
      return null;
  }
}

/// Field ids whose `clear_on` names [eventId], across every held tree.
///
/// The mirror of the browser's `[data-g-clear-on]` query. Walked at
/// emit time rather than kept as a registry, because the trees it
/// reads (page, dynamic slots, modal) each replace wholesale and a
/// registry would have three invalidation points to get wrong;
/// events happen at human speed, so the walk costs nothing.
Set<String> clearOnTargets(Iterable<GlintyComponent> trees, String eventId) {
  final out = <String>{};
  void walk(GlintyComponent c) {
    if ((c.type == 'text_input' || c.type == 'textarea_input') &&
        c.str('clear_on') == eventId) {
      final id = c.str('id');
      if (id != null) out.add(id);
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

  for (final t in trees) {
    walk(t);
  }
  return out;
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
