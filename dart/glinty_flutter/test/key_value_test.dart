// key_value: pairs in a two-column table, the value styled by its
// text variant through the same switch txt() uses. The fixture suite
// proves the component renders; this file pins the shape and where a
// marked value's style comes from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

GlintyComponent kv(List<Map<String, dynamic>> items) =>
    GlintyComponent.fromJson({'component': 'key_value', 'items': items});

Future<void> pumpKv(WidgetTester tester, GlintyComponent c) async {
  await tester.pumpWidget(MaterialApp(
      theme: glintyThemeData(glintyStockTheme),
      home: Scaffold(
          body: Builder(
              builder: (context) => GlintyRenderer().build(context, c)))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('keys and values are drawn, a marked value in its variant',
      (tester) async {
    await pumpKv(
        tester,
        kv([
          {'key': 'Model', 'value': 'whisper-large'},
          {'key': 'Path', 'value': '/mnt/x', 'variant': 'mono'},
          {'key': 'State', 'value': 'failed', 'variant': 'danger'},
        ]));
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('whisper-large'), findsOneWidget);
    // danger is the wire danger token, read back off ColorScheme.error,
    // exactly as txt("failed", "danger") is
    expect(tester.widget<Text>(find.text('failed')).style?.color,
        const Color(0xffb3261e));
    expect(tester.widget<Text>(find.text('/mnt/x')).style?.fontFamily,
        glintyMonoStack(glintyStockTheme).first);
    // an unmarked value carries no style of its own
    expect(tester.widget<Text>(find.text('whisper-large')).style, isNull);
  });

  testWidgets('empty items draw nothing and throw nothing', (tester) async {
    await pumpKv(tester, kv(const []));
    expect(find.byType(Table), findsNothing);
  });
}
