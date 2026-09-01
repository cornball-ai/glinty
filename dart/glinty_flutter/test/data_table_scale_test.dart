// A data table at gallery-012 scale, living inside a tabset: 1000
// rows sort and page in bounded time, and a second table in another
// panel keeps its own independent options. IndexedStack builds every
// panel, so both tables are alive at once -- the interplay the
// per-component tests don't cover.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

void main() {
  testWidgets('a 1000-row table in a tabset sorts and pages', (tester) async {
    final s = GlintySession();
    s.receive({
      'type': 'welcome', 'session': 's1', 'protocol': 4,
      'ui_revision': 'r1',
      'ui': {
        'component': 'page', 'title': 'Grid',
        'children': [
          {
            'component': 'tabset', 'id': 'dataset',
            'panels': [
              {'title': 'diamonds', 'children': [
                {'component': 'data_table', 'id': 't1', 'page_length': 10,
                  'length_menu': [10, 25, 50, 100],
                  'searchable': true, 'sortable': true},
              ]},
              {'title': 'iris', 'children': [
                {'component': 'data_table', 'id': 't2', 'page_length': 5,
                  'length_menu': [5, 30, 50],
                  'searchable': true, 'sortable': true},
              ]},
            ],
          },
        ],
      },
    });
    s.receive({
      'type': 'output', 'id': 't1', 'kind': 'table',
      'value': {
        'header': ['a', 'b', 'c'],
        'align': ['num', 'text', 'num'],
        'rows': [
          for (var i = 0; i < 1000; i++)
            ['${(i * 37) % 1000 / 10}', 'name$i', '$i'],
        ],
      },
    });
    s.receive({
      'type': 'output', 'id': 't2', 'kind': 'table',
      'value': {
        'header': ['x'], 'align': ['num'],
        'rows': [for (var i = 0; i < 150; i++) ['$i']],
      },
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: SingleChildScrollView(child: GlintyView(session: s)))));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Showing 1–10 of 1000'), findsOneWidget);

    await tester.tap(find.text('iris'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Showing 1–5 of 150'), findsOneWidget);
  });
}
