// The searchable select: Material's DropdownMenu wearing glinty's
// contract. What is ours to test: the flag picks the widget, the
// initial selection shows its label, and picking an entry reports
// the entry's VALUE -- the label is display, the value is the wire.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcome() => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': 'r1',
      'ui': {
        'component': 'page',
        'title': 'Selects',
        'children': [
          {
            'component': 'select_input', 'id': 'state', 'label': 'State:',
            'search': true, 'selected': 'AK', 'emit': 'settle',
            'choices': [
              {'value': 'AL', 'label': 'Alabama'},
              {'value': 'AK', 'label': 'Alaska'},
              {'value': 'AZ', 'label': 'Arizona'},
            ],
          },
          {
            'component': 'select_input', 'id': 'plain', 'label': 'Plain:',
            'emit': 'settle',
            'choices': [
              {'value': 'a', 'label': 'A'},
            ],
          },
        ],
      },
    };

void main() {
  testWidgets('search picks DropdownMenu, plain keeps DropdownButton',
      (tester) async {
    final s = GlintySession()..receive(welcome());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GlintyView(session: s))));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownMenu<String>), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    // the selection surfaces as its label
    expect(find.text('Alaska'), findsWidgets);
  });

  testWidgets('picking an entry reports the value, not the label',
      (tester) async {
    final s = GlintySession()..receive(welcome());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GlintyView(session: s))));
    await tester.pumpAndSettle();

    // seeded like a plain select
    expect(s.inputs['state'], 'AK');

    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arizona').last);
    await tester.pumpAndSettle();

    expect(s.inputs['state'], 'AZ');
  });
}
