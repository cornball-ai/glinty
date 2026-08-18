// rich_text: flat styled runs (#70). The fixture suite proves it
// renders; this file pins the semantics -- marks combine on one
// span's style, a linked run taps through onLink, and a run is a tap
// target exactly when there is a handler and the scheme is one the
// wire allows.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

GlintyComponent richText(List<Map<String, dynamic>> runs) =>
    GlintyComponent.fromJson({'component': 'rich_text', 'runs': runs});

Future<List<InlineSpan>> pumpRuns(WidgetTester tester,
    List<Map<String, dynamic>> runs,
    {void Function(String href, {bool external})? onLink}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => GlintyRenderer(onLink: onLink)
                  .build(context, richText(runs))))));
  await tester.pumpAndSettle();
  final rich = tester.widget<Text>(find.byType(Text));
  return (rich.textSpan! as TextSpan).children!;
}

void main() {
  testWidgets('marks combine on one span', (tester) async {
    final spans = await pumpRuns(tester, [
      {'text': 'plain '},
      {'text': 'both', 'bold': true, 'italic': true},
      {'text': 'code', 'code': true},
      {'text': 'gone', 'strike': true},
    ]);
    expect(spans, hasLength(4));
    final both = spans[1] as TextSpan;
    expect(both.style!.fontWeight, FontWeight.w600);
    expect(both.style!.fontStyle, FontStyle.italic);
    final code = spans[2] as TextSpan;
    expect(code.style!.fontFamily, isNotNull);
    expect(code.style!.backgroundColor, isNotNull);
    final gone = spans[3] as TextSpan;
    expect(gone.style!.decoration, TextDecoration.lineThrough);
    expect((spans[0] as TextSpan).style!.fontWeight, isNull);
  });

  testWidgets('a linked run taps through onLink', (tester) async {
    String? opened;
    final spans = await pumpRuns(tester, [
      {'text': 'see '},
      {'text': 'the site', 'href': 'https://cornball.ai'},
    ], onLink: (href, {external = false}) => opened = href);
    final link = spans[1] as TextSpan;
    expect(link.style!.decoration, TextDecoration.underline);
    expect(link.recognizer, isA<TapGestureRecognizer>());
    (link.recognizer! as TapGestureRecognizer).onTap!();
    expect(opened, 'https://cornball.ai');
    expect((spans[0] as TextSpan).recognizer, isNull);
  });

  testWidgets('no handler, no tap target -- the link component rule',
      (tester) async {
    final spans = await pumpRuns(tester, [
      {'text': 'x', 'href': 'https://a.b'},
    ]);
    expect((spans[0] as TextSpan).recognizer, isNull);
  });

  testWidgets('a scheme the wire refuses is never a tap target',
      (tester) async {
    // the R schema refuses these at construction; this client stands
    // alone anyway, in case the frame came from somewhere else
    var opened = false;
    final spans = await pumpRuns(tester, [
      {'text': 'x', 'href': 'javascript:alert(1)'},
    ], onLink: (href, {external = false}) => opened = true);
    expect((spans[0] as TextSpan).recognizer, isNull);
    expect(opened, isFalse);
  });
}
