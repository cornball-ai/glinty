// The status trio (#78): success/warning/danger text colored from
// the theme's semantic tokens. danger reads ColorScheme.error (where
// glintyThemeData puts the danger token); success and warning ride
// the GlintyStatusColors ThemeExtension because Material has no seat
// for them. The fixture suite proves the variants render; this file
// pins where each color comes from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

GlintyComponent statusText(String variant) => GlintyComponent.fromJson(
    {'component': 'text', 'value': variant, 'variant': variant});

Future<Color?> pumpStatus(WidgetTester tester, ThemeData theme,
    String variant) async {
  await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
          body: Builder(
              builder: (context) =>
                  GlintyRenderer().build(context, statusText(variant))))));
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.text(variant)).style?.color;
}

void main() {
  testWidgets('stock light theme colors the trio from the stock palette',
      (tester) async {
    final theme = glintyThemeData(glintyStockTheme);
    expect(await pumpStatus(tester, theme, 'success'),
        const Color(0xff1a7f37));
    expect(await pumpStatus(tester, theme, 'warning'),
        const Color(0xff9a6700));
    // danger is the wire danger token, read back off ColorScheme.error
    expect(await pumpStatus(tester, theme, 'danger'),
        const Color(0xffb3261e));
  });

  testWidgets('a themed success token reaches the text', (tester) async {
    final themed = Map<String, dynamic>.from(glintyStockTheme);
    themed['colors'] = {
      ...(glintyStockTheme['colors'] as Map).cast<String, dynamic>(),
      'success': '#00aa00',
    };
    expect(await pumpStatus(tester, glintyThemeData(themed), 'success'),
        const Color(0xff00aa00));
    // an untouched sibling keeps its stock value
    expect(await pumpStatus(tester, glintyThemeData(themed), 'warning'),
        const Color(0xff9a6700));
  });

  testWidgets('the dark palette swaps the status tokens with it',
      (tester) async {
    final dark = glintyThemeDataFor(glintyStockTheme, Brightness.dark);
    expect(await pumpStatus(tester, dark, 'success'),
        const Color(0xff3fb950));
    expect(await pumpStatus(tester, dark, 'warning'),
        const Color(0xffd29922));
  });

  testWidgets('a bare Material theme degrades to the default color',
      (tester) async {
    // no GlintyStatusColors extension: the variant must not throw,
    // and the text keeps whatever a normal text gets under the same
    // theme -- degrade means indistinguishable, not styled from air
    final bare = ThemeData.light();
    final status = await pumpStatus(tester, bare, 'success');
    final normal = await pumpStatus(tester, bare, 'normal');
    expect(status, normal);
  });
}
