// The never-stomp contract extends to tree swaps (#79).
//
// A ui frame replacing a slot must not rewrite the draft in the field
// the user is typing in: the session spares the focused input's value
// when it re-seeds the region, and re-hands focus through the
// focus-verb machinery so a rebuilt widget picks both up at birth.
// Everything unfocused takes its declared value, which is what a
// re-render means for a field nobody is typing in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcome(List<Map<String, dynamic>> children) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': 'r1',
      'ui': {'component': 'page', 'title': 'Swap', 'children': children},
    };

Map<String, dynamic> slotUi(Object tree) =>
    {'type': 'output', 'id': 'zone', 'kind': 'ui', 'value': tree};

Map<String, dynamic> composer({String value = ''}) => {
      'component': 'text_input',
      'id': 'draft',
      'label': 'draft',
      'value': value,
      'emit': 'live',
    };

Map<String, dynamic> caption(String v) =>
    {'component': 'text', 'value': v};

Future<void> pump(WidgetTester tester, GlintySession s) async {
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GlintyView(session: s))));
  await tester.pumpAndSettle();
}

void main() {
  test('adopt spares the focused field, reseeds the rest, drops the gone',
      () {
    final s = GlintySession()
      ..receive(welcome([
        {'component': 'ui_output', 'id': 'zone'}
      ]));
    s.receive(slotUi({
      'component': 'column',
      'children': [
        composer(),
        {'component': 'text_input', 'id': 'other', 'label': 'o',
          'value': 'a', 'emit': 'live'},
      ]
    }));
    s.sendInput('draft', 'half a thought');
    s.sendInput('other', 'edited');
    s.focusChanged('draft', true);

    s.receive(slotUi({
      'component': 'column',
      'children': [
        composer(),
        {'component': 'text_input', 'id': 'other', 'label': 'o',
          'value': 'a', 'emit': 'live'},
      ]
    }));
    // the focused draft survives; the unfocused edit is re-seeded
    expect(s.inputs['draft'], 'half a thought');
    expect(s.inputs['other'], 'a');
    // and focus is re-handed as a verb for the (possibly) reborn field
    expect(s.focuses['draft'], 1);
    // the re-declared sibling ticks again (the first delivery was
    // tick 1, spent at the widget's birth); the spared field stays
    // at its birth tick -- its declared value was deliberately not
    // applied this time
    expect(s.seedTicks['other'], 2);
    expect(s.seedTicks['draft'], 1);

    // a swap that drops the field takes the draft with it
    s.receive(slotUi({
      'component': 'column',
      'children': [caption('composer gone')]
    }));
    expect(s.inputs.containsKey('draft'), isFalse);
  });

  testWidgets('a same-shape swap keeps the draft and the focus on screen',
      (tester) async {
    final s = GlintySession()
      ..receive(welcome([
        {'component': 'ui_output', 'id': 'zone'}
      ]));
    s.receive(slotUi({
      'component': 'column',
      'children': [caption('tick 1'), composer()]
    }));
    await pump(tester, s);

    await tester.enterText(find.byType(TextField), 'half a thought');
    await tester.pumpAndSettle();
    expect(s.focusedInput, 'draft');

    // the freshness tick: same shape, new caption
    s.receive(slotUi({
      'component': 'column',
      'children': [caption('tick 2'), composer()]
    }));
    await pump(tester, s);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'half a thought');
    expect(field.focusNode?.hasFocus, isTrue);
    expect(find.text('tick 2'), findsOneWidget);
  });

  testWidgets('a reshaping swap reberths the field with draft and focus',
      (tester) async {
    // the widget cannot survive this one (its position and parent
    // change), so the reborn state must pick the draft up from the
    // store and answer the re-handed focus verb at birth
    final s = GlintySession()
      ..receive(welcome([
        {'component': 'ui_output', 'id': 'zone'}
      ]));
    s.receive(slotUi({
      'component': 'column',
      'children': [composer()]
    }));
    await pump(tester, s);
    await tester.enterText(find.byType(TextField), 'mid-sentence');
    await tester.pumpAndSettle();

    s.receive(slotUi({
      'component': 'column',
      'children': [
        caption('now wrapped'),
        {
          'component': 'panel',
          'variant': 'plain',
          'children': [composer()]
        },
      ]
    }));
    await pump(tester, s);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'mid-sentence');
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('an unfocused field takes the declared value, as ever',
      (tester) async {
    final s = GlintySession()
      ..receive(welcome([
        {'component': 'ui_output', 'id': 'zone'}
      ]));
    s.receive(slotUi({
      'component': 'column',
      'children': [composer(value: 'v1')]
    }));
    await pump(tester, s);
    await tester.enterText(find.byType(TextField), 'abandoned');
    await tester.pumpAndSettle();

    // focus leaves (the user moved on) before the tick
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(s.focusedInput, isNull);

    s.receive(slotUi({
      'component': 'column',
      'children': [composer(value: 'v2')]
    }));
    await pump(tester, s);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'v2');
  });
}
