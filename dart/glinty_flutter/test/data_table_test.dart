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
      'protocol': 4,
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

/// A selectable table: the same shell with a selection mode.
Map<String, dynamic> selectTree(String selection) => {
      'component': 'page',
      'title': 'Grid',
      'children': [
        {
          'component': 'data_table',
          'id': 'grid',
          'page_length': 10,
          'length_menu': [10],
          'searchable': true,
          'sortable': true,
          'selection': selection,
        },
      ],
    };

/// Three keyed rows; the first carries a marked cell. The numeric
/// column disagrees with text order (10 sorts after 2 as a number,
/// before it as text), so a sort moves the marked row.
Map<String, dynamic> keyedValue({List<String> keys = const ['a', 'b', 'c']}) =>
    {
      'header': ['state', 'n'],
      'align': ['text', 'num'],
      'keys': keys,
      'rows': [
        [
          {'text': 'failed', 'variant': 'danger'},
          '10'
        ],
        ['ok', '2'],
        ['fine', '3'],
      ],
    };

Map<String, dynamic>? lastInput(GlintySession s) {
  final inputs = s.sent.where((m) => m.type == 'input').toList();
  return inputs.isEmpty ? null : inputs.last.body;
}

void main() {
  testWidgets('multiple selection toggles rows and reports keys in data order',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(selectTree('multiple')));
    // seeded from the tree: nothing selected is an empty list, not null
    expect(s.inputs['grid'], <String>[]);
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(lastInput(s), {'type': 'input', 'id': 'grid', 'value': ['b']});

    // clicked after b, reported before it: data order, never click order
    await tester.tap(find.text('failed'));
    await tester.pumpAndSettle();
    expect(lastInput(s), {'type': 'input', 'id': 'grid', 'value': ['a', 'b']});

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(lastInput(s), {'type': 'input', 'id': 'grid', 'value': ['a']});
  });

  testWidgets('single selection replaces, and a second tap clears',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(selectTree('single')));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(lastInput(s)!['value'], ['b']);
    await tester.tap(find.text('fine'));
    await tester.pumpAndSettle();
    expect(lastInput(s)!['value'], ['c']);
    await tester.tap(find.text('fine'));
    await tester.pumpAndSettle();
    expect(lastInput(s)!['value'], <String>[]);
  });

  testWidgets('a selection survives a re-sort and is pruned by a new value',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(selectTree('multiple')));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    await tester.tap(find.text('failed'));
    await tester.pumpAndSettle();
    expect(lastInput(s)!['value'], ['a']);
    final sentBefore = s.sent.length;

    // sorting is local: the row moves, stays selected, nothing is sent
    await tester.tap(find.text('n'));
    await tester.pumpAndSettle();
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.where((r) => r.selected).length, 1);
    expect(s.sent.length, sentBefore);

    // a value without row a: the selection drops it and says so, once
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(keys: ['x', 'b', 'c']),
    });
    // repump: in an app the session-listening ancestor does this
    await pump(tester, s);
    await tester.pumpAndSettle();
    expect(lastInput(s)!['value'], <String>[]);
    expect(s.sent.length, sentBefore + 1);

    // a value that keeps every selected row sends nothing
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(keys: ['x', 'b', 'c']),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();
    expect(s.sent.length, sentBefore + 1);
  });

  testWidgets('a marked cell shows its text in the variant style, and '
      'filters and sorts by that text', (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(selectTree('none')));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    final failed = tester.widget<Text>(find.text('failed'));
    final scheme = Theme.of(tester.element(find.text('failed'))).colorScheme;
    expect(failed.style?.color, scheme.error);
    expect(find.textContaining('{'), findsNothing);

    await tester.enterText(find.byType(TextField), 'FAIL');
    await tester.pumpAndSettle();
    expect(find.text('failed'), findsOneWidget);
    expect(find.text('ok'), findsNothing);
  });

  testWidgets('a table with no selection mode reports nothing on tap',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(selectTree('none')));
    expect(s.inputs.containsKey('grid'), isFalse);
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': keyedValue(),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();
    final before = s.sent.length;
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(s.sent.length, before);
    expect(find.byType(Checkbox), findsNothing);
  });

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

  testWidgets('a small value drops the chrome, a big one brings it back',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(gridTree()));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(3),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    // 3 rows fit the 3-row page and the smallest menu option: no
    // dropdown, no count, no nav -- the table is just a table
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.textContaining('Showing'), findsNothing);
    expect(find.text('Next ›'), findsNothing);
    // the search box answers `searchable` alone
    expect(find.byType(TextField), findsOneWidget);

    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': tableValue(10),
    });
    await pump(tester, s);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.text('Showing 1–3 of 10'), findsOneWidget);
    expect(find.text('Next ›'), findsOneWidget);
  });

  testWidgets('align right: right-aligned column, still a text sort',
      (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith(gridTree(pageLength: 10)));
    s.receive({
      'type': 'output', 'id': 'grid', 'kind': 'table',
      'value': {
        'header': ['size', 'n'],
        'align': ['right', 'num'],
        'rows': [
          ['2.0 GiB', '1'],
          ['10.0 GiB', '2'],
          ['9.0 GiB', '3'],
        ],
      },
    });
    await pump(tester, s);
    await tester.pumpAndSettle();

    // DataColumn(numeric:) is Material's right-alignment: on for
    // "right" as for "num"
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns[0].numeric, isTrue);
    expect(table.columns[1].numeric, isTrue);

    await tester.tap(find.text('size'));
    await tester.pumpAndSettle();
    final texts = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(DataTable), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    // ascending text order: "10.0 GiB" < "2.0 GiB" < "9.0 GiB"; a
    // numeric sort would read 2 < 9 < 10
    expect(texts.indexOf('10.0 GiB'), lessThan(texts.indexOf('2.0 GiB')));
    expect(texts.indexOf('2.0 GiB'), lessThan(texts.indexOf('9.0 GiB')));
  });

  testWidgets('table_output honours align right too', (tester) async {
    final s = GlintySession();
    s.receive(welcomeWith({
      'component': 'page',
      'title': 'P',
      'children': [
        {'component': 'table_output', 'id': 't'},
      ],
    }));
    s.receive({
      'type': 'output', 'id': 't', 'kind': 'table',
      'value': {
        'header': ['size'],
        'align': ['right'],
        'rows': [
          ['2.0 GiB'],
        ],
      },
    });
    await pump(tester, s);
    await tester.pumpAndSettle();
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns[0].numeric, isTrue);
  });
}
