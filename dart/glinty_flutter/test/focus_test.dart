// update_text_input(focus = TRUE): the one-shot focus verb (#71).
//
// The session counts the verbs; the field answers each count once --
// on change, and at birth, because the tree swap and the focus aimed
// at its composer routinely arrive in one drain. The counter dies
// with its input when a slot is replaced, so a reborn control never
// steals focus from an event that predates it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcome(List<Map<String, dynamic>> children) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 4,
      'ui_revision': 'r1',
      'ui': {'component': 'page', 'title': 'Focus', 'children': children},
    };

Map<String, dynamic> textInput(String id) => {
      'component': 'text_input',
      'id': id,
      'label': id,
      'value': '',
    };

Map<String, dynamic> focusUpdate(String id) =>
    {'type': 'input_update', 'id': id, 'focus': true};

Future<void> pump(WidgetTester tester, GlintySession s) async {
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GlintyView(session: s))));
  await tester.pumpAndSettle();
}

// By build order: 0 = draft, 1 = other. (Scoping by label finds the
// page's own Column first and reads the wrong field.)
bool fieldHasFocus(WidgetTester tester, int index) {
  final field =
      tester.widget<TextField>(find.byType(TextField).at(index));
  return field.focusNode?.hasFocus ?? false;
}

void main() {
  test('the session counts focus verbs and drops them with the input', () {
    final s = GlintySession()
      ..receive(welcome([textInput('draft'), textInput('other')]));
    expect(s.focuses['draft'], isNull);
    s.receive(focusUpdate('draft'));
    expect(s.focuses['draft'], 1);
    s.receive(focusUpdate('draft'));
    expect(s.focuses['draft'], 2);
    // the verb alone writes no value
    expect(s.inputs['draft'], '');
    // a fresh welcome (new revision) takes the counters with the page
    s.receive({...welcome([textInput('draft')]), 'ui_revision': 'r2'});
    expect(s.focuses, isEmpty);
  });

  testWidgets('a focus verb moves focus to the field, whoever had it',
      (tester) async {
    final s = GlintySession()
      ..receive(welcome([textInput('draft'), textInput('other')]));
    await pump(tester, s);

    // the user is in the OTHER field: a value push there would be
    // refused, but the focus verb applies -- different hazard
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(fieldHasFocus(tester, 1), isTrue);

    s.receive(focusUpdate('draft'));
    await pump(tester, s);
    expect(fieldHasFocus(tester, 0), isTrue);
    expect(fieldHasFocus(tester, 1), isFalse);
  });

  testWidgets('a field born with a pending focus verb answers it',
      (tester) async {
    // the metate shape: the slot swap and the focus arrive in one
    // drain, so the field's FIRST build already carries the count
    final s = GlintySession()..receive(welcome([textInput('draft')]));
    s.receive(focusUpdate('draft'));
    await pump(tester, s);
    expect(fieldHasFocus(tester, 0), isTrue);
  });

  testWidgets('a spent verb is not re-applied by later rebuilds',
      (tester) async {
    final s = GlintySession()
      ..receive(welcome([textInput('draft'), textInput('other')]));
    await pump(tester, s);
    s.receive(focusUpdate('draft'));
    await pump(tester, s);
    expect(fieldHasFocus(tester, 0), isTrue);

    // the user moves on; an unrelated rebuild must not steal focus back
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(fieldHasFocus(tester, 1), isTrue);
    s.receive({'type': 'output', 'id': 'x', 'kind': 'text', 'value': 'hi'});
    await pump(tester, s);
    expect(fieldHasFocus(tester, 1), isTrue);
    expect(fieldHasFocus(tester, 0), isFalse);
  });
}
