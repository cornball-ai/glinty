// The interactive table: sort, filter and pagination happen in the
// client, over the same table value a plain table_output receives.
// These tests drive the delivered value the way a running app would
// and assert the state machine matches the browser's renderDataTable:
// contains-filter, align-driven numeric sort, page clamped (never
// reset) when a new value arrives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcomeWith(Object tree) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': 'r1',
      'ui': tree,
    };

Map<String, dynamic> gridTree({int pageLength = 3}) => {
      'component': 'page',
      'title': 'Grid',
      'children': [
        {
          'component': 'data_table',
          'id': 'grid',
          'page_length': pageLength,
          'length_menu': [3, 5, 10],
          'searchable': true,
          'sortable': true,
        },
      ],
    };

/// Ten rows, one numeric column whose numeric order disagrees with
/// its text order (2 < 10 numerically, "10" < "2" as text) -- the
/// case that catches a text sort wearing a numeric label.
Map<String, dynamic> tableValue(int n) => {
      'header': ['name', 'n'],
      'align': ['left', 'num'],
      'rows': [
        for (var i = 1; i <= n; i++) ['row$i', '$i'],
      ],
    };

Future<void> pump(WidgetTester tester, GlintySession s) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: GlintyView(session: s)))));

void main() {
  testWidgets('pages the value and reports its place', (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(gridTree()));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(10),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    expect(find.text('row1'), findsOneWidget);
    expect(find.text('row3'), findsOneWidget);
    expect(find.text('row4'), findsNothing);
    expect(find.text('Showing 1–3 of 10'), findsOneWidget);

    await tester.tap(find.text('Next ›'));
    await tester.pumpAndSettle();
    expect(find.text('row4'), findsOneWidget);
    expect(find.text('row1'), findsNothing);
    expect(find.text('Showing 4–6 of 10'), findsOneWidget);

    await tester.tap(find.text('‹ Prev'));
    await tester.pumpAndSettle();
    expect(find.text('row1'), findsOneWidget);
  });

  testWidgets('filters case-insensitively and counts the cut',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(gridTree()));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(10),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ROW1');
    await tester.pumpAndSettle();

    // row1, row10 match; row2..9 do not
    expect(find.text('row1'), findsOneWidget);
    expect(find.text('row10'), findsOneWidget);
    expect(find.text('row2'), findsNothing);
    expect(find.text('Showing 1–2 of 2 (filtered from 10)'), findsOneWidget);
  });

  testWidgets('sorts the num column numerically, toggling direction',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(gridTree(pageLength: 10)));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(10),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    String cellAt(int i) => (tester
            .widget<Text>(find.descendant(
                of: find.byType(DataTable), matching: find.byType(Text))
            .at(i)))
        .data!;

    await tester.tap(find.text('n'));
    await tester.pumpAndSettle();
    // ascending numeric: row1 (1) first, row10 (10) last -- a text
    // sort would put "10" before "2"
    expect(cellAt(2), 'row1');
    final texts = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(DataTable), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(texts.indexOf('row2'), lessThan(texts.indexOf('row10')));

    await tester.tap(find.text('n'));
    await tester.pumpAndSettle();
    final desc = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(DataTable), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(desc.indexOf('row10'), lessThan(desc.indexOf('row2')));
  });

  testWidgets('a new value clamps the page instead of resetting it',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(gridTree()));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(10),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    // walk to the last page (rows 10 of 10 -> page 4 of 4)
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next ›'));
      await tester.pumpAndSettle();
    }
    expect(find.text('row10'), findsOneWidget);

    // the value shrinks to 5 rows: page 4 stopped existing, so the
    // view clamps to the new last page rather than jumping to the
    // first
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(5),
    });
    // repump: in an app the session-listening ancestor does this
    await pump(tester, s);
    await tester.pumpAndSettle();
    expect(find.text('row4'), findsOneWidget);
    expect(find.text('row5'), findsOneWidget);
    expect(find.text('Showing 4–5 of 5'), findsOneWidget);
  });
}
