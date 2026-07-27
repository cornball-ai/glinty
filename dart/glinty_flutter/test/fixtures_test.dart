// Every fixture from glinty, rendered as Flutter widgets.
//
// This is the check the Flutter column in PROTOCOL.md was standing in
// for. The R lowering and this one read the same file, so there is no
// copy to keep in step: fixtures and both clients live in one
// repository. Adding a fixture obliges both to answer for it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

// The canonical fixture file, read directly. In two repositories this
// needed a copy, a recorded sha256 and a weekly CI job to check the
// two had not drifted. In one repository it needs a relative path.
const fixturePath = "../../inst/fixtures/components.json";

Map<String, dynamic> loadFixtureFile() =>
    jsonDecode(File(fixturePath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> loadFixtures() =>
    (loadFixtureFile()["fixtures"] as List).cast<Map<String, dynamic>>();

Future<void> pumpComponent(WidgetTester tester, GlintyComponent c,
    {GlintyRenderer? renderer}) async {
  final r = renderer ?? GlintyRenderer();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Builder(builder: (context) => r.build(context, c)),
      ),
    ),
  ));
}

void main() {
  final fixtures = loadFixtures();

  test('the fixture file declares the protocol this client speaks', () {
    expect(loadFixtureFile()['protocol'], 3,
        reason: 'this client renders protocol 3; a newer wire format '
            'should be refused rather than half-rendered');
  });

  test('the fixture file is the one glinty generated', () {
    expect(fixtures, isNotEmpty);
    for (final f in fixtures) {
      expect(f['name'], isA<String>());
      expect(f['notes'], isA<String>(),
          reason: 'every fixture explains why it earns its place');
      expect(f['component'], isA<Map>());
    }
  });

  test('every fixture parses', () {
    for (final f in fixtures) {
      final c = GlintyComponent.fromJson(f['component']);
      expect(c.type, isNotEmpty, reason: 'fixture ${f['name']}');
    }
  });

  test('every component in the fixtures is either supported or named', () {
    // Walk the whole tree, not just the roots: a nested component this
    // client has never heard of is exactly what silently vanishes.
    final seen = <String>{};
    void walk(GlintyComponent c) {
      seen.add(c.type);
      for (final k in c.children) {
        walk(k);
      }
      for (final p in c.panels) {
        for (final k in p.children) {
          walk(k);
        }
      }
    }

    for (final f in fixtures) {
      walk(GlintyComponent.fromJson(f['component']));
    }

    final unknown = seen
        .where((t) =>
            !supportedComponents.contains(t) &&
            !unsupportedComponents.contains(t))
        .toList();
    expect(unknown, isEmpty,
        reason: 'glinty grew components this client has not answered for: '
            '$unknown');
  });

  for (final f in fixtures) {
    final name = f['name'] as String;
    testWidgets('renders fixture: $name', (tester) async {
      final c = GlintyComponent.fromJson(f['component']);
      await pumpComponent(tester, c);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unsupported component is visible, not silent',
      (tester) async {
    final c = GlintyComponent.fromJson(
        {'component': 'from_the_future', 'value': 'x'});
    await pumpComponent(tester, c);
    expect(find.textContaining('unsupported component'), findsOneWidget);
    expect(find.textContaining('from_the_future'), findsOneWidget);
  });

  testWidgets('text_input reports through onChanged when emit is live',
      (tester) async {
    String? gotId;
    dynamic gotValue;
    final r = GlintyRenderer(onInput: (id, v) {
      gotId = id;
      gotValue = v;
    });
    final c = GlintyComponent.fromJson({
      'component': 'text_input',
      'id': 'name',
      'label': 'Name',
      'value': '',
      'emit': 'live',
    });
    await pumpComponent(tester, c, renderer: r);
    await tester.enterText(find.byKey(const Key('name')), 'Troy');
    expect(gotId, 'name');
    expect(gotValue, 'Troy');
  });

  testWidgets('emit=settle does not report on every keystroke',
      (tester) async {
    var calls = 0;
    final r = GlintyRenderer(onInput: (id, v) => calls++);
    final c = GlintyComponent.fromJson({
      'component': 'text_input',
      'id': 'q',
      'value': '',
      'emit': 'settle',
    });
    await pumpComponent(tester, c, renderer: r);
    await tester.enterText(find.byKey(const Key('q')), 'abc');
    expect(calls, 0, reason: 'settle reports on submit, not while typing');
  });

  testWidgets('button emits an event, carrying no value', (tester) async {
    String? fired;
    final r = GlintyRenderer(onEvent: (id) => fired = id);
    final c = GlintyComponent.fromJson({
      'component': 'button',
      'id': 'go',
      'label': 'Run',
      'variant': 'primary',
    });
    await pumpComponent(tester, c, renderer: r);
    await tester.tap(find.byKey(const Key('go')));
    expect(fired, 'go');
  });

  testWidgets('password_input obscures, and carries no value to obscure',
      (tester) async {
    final c = GlintyComponent.fromJson({
      'component': 'password_input',
      'id': 'key',
      'label': 'API Key',
      'emit': 'live',
    });
    // The schema has no value field at all, so there is nothing here
    // that could have come from Sys.getenv().
    expect(c.fields.containsKey('value'), isFalse);
    await pumpComponent(tester, c);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });

  testWidgets('slider derives divisions from step', (tester) async {
    final c = GlintyComponent.fromJson({
      'component': 'slider_input',
      'id': 'speed',
      'min': 0.5,
      'max': 2,
      'value': 1,
      'step': 0.1,
    });
    await pumpComponent(tester, c);
    final slider = tester.widget<Slider>(find.byType(Slider));
    // (2 - 0.5) / 0.1 = 15. Only derivable because step is a number
    // rather than a CSS length string.
    expect(slider.divisions, 15);
  });

  testWidgets('an output slot renders the value delivered for its id',
      (tester) async {
    final r = GlintyRenderer(values: {'greeting': 'hello there'});
    final c = GlintyComponent.fromJson(
        {'component': 'text_output', 'id': 'greeting', 'variant': 'normal'});
    await pumpComponent(tester, c, renderer: r);
    expect(find.text('hello there'), findsOneWidget);
  });

  testWidgets('an output slot with no value yet is empty, not broken',
      (tester) async {
    final c = GlintyComponent.fromJson(
        {'component': 'text_output', 'id': 'nothing', 'variant': 'normal'});
    await pumpComponent(tester, c);
    expect(tester.takeException(), isNull);
  });

  test('a malformed component is refused, not half-built', () {
    expect(() => GlintyComponent.fromJson('nope'), throwsFormatException);
    expect(() => GlintyComponent.fromJson({'value': 'x'}),
        throwsFormatException);
    expect(
        () => GlintyComponent.fromJson({
              'component': 'tabset',
              'id': 't',
              'panels': [
                {'children': []}
              ]
            }).panels,
        throwsFormatException);
  });
}
