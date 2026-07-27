// Inputs as state, not as tree fields.
//
// A renderer that reads a control's value out of the component draws
// the initial value forever: the tree is the shape of the UI, the
// session holds its state. These are the tests that say so -- every
// one of them failed before the input store existed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'transcript_data.dart';

/// A tree with one of everything stateful.
final formTree = {
  'component': 'page',
  'title': 'Form',
  'children': [
    {'component': 'text_input', 'id': 'name', 'label': 'Name:',
      'value': 'seeded', 'emit': 'live'},
    {'component': 'checkbox_input', 'id': 'save', 'label': 'Save',
      'value': false, 'emit': 'settle'},
    {'component': 'select_input', 'id': 'engine', 'label': 'Engine:',
      'multiple': false, 'emit': 'settle', 'choices': [
        {'value': 'fast', 'label': 'Fast'},
        {'value': 'slow', 'label': 'Slow'},
      ]},
    {'component': 'slider_input', 'id': 'n', 'label': 'N:',
      'min': 0, 'max': 100, 'value': 25, 'emit': 'live'},
    {'component': 'radio_buttons', 'id': 'mode', 'label': 'Mode:',
      'selected': 'a', 'emit': 'settle', 'choices': [
        {'value': 'a', 'label': 'A'},
        {'value': 'b', 'label': 'B'},
      ]},
  ],
};

Map<String, dynamic> welcomeWith(Object tree, {String revision = 'r1'}) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': revision,
      'ui': tree,
    };

Future<void> pumpSession(WidgetTester tester, GlintySession s) =>
    tester.pumpWidget(
        MaterialApp(home: Scaffold(body: GlintyView(session: s))));

void main() {
  group('the session seeds its inputs from the tree', () {
    test('the way the server seeds its own', () {
      final s = GlintySession();
      s.receive(welcomeWith(formTree));

      // mirrors R/seed.R: text value or "", checkbox false, single
      // select's first choice, slider position, radio selection
      expect(s.inputs['name'], 'seeded');
      expect(s.inputs['save'], false);
      expect(s.inputs['engine'], 'fast');
      expect(s.inputs['n'], 25);
      expect(s.inputs['mode'], 'a');
    });

    test('an input with nothing to seed simply has no entry', () {
      final s = GlintySession();
      s.receive(welcomeWith({
        'component': 'page',
        'children': [
          {'component': 'number_input', 'id': 'empty', 'emit': 'live'},
          {'component': 'select_input', 'id': 'multi', 'multiple': true,
            'emit': 'settle', 'choices': [
              {'value': 'a', 'label': 'A'}
            ]},
          {'component': 'button', 'id': 'go', 'label': 'Go',
            'variant': 'default'},
        ],
      }));
      expect(s.inputs.containsKey('empty'), isFalse);
      expect(s.inputs.containsKey('multi'), isFalse);
      expect(s.inputs.containsKey('go'), isFalse);
    });
  });

  group('controls hold their value across rebuilds', () {
    testWidgets('typed text survives a rebuild', (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);

      await tester.enterText(find.byKey(const Key('name')), 'Troy');
      await tester.pump();
      expect(s.inputs['name'], 'Troy');

      // an unrelated output arrives and the whole tree rebuilds
      s.receive({'type': 'output', 'id': 'other', 'kind': 'text',
        'value': 'x'});
      await pumpSession(tester, s);

      expect(find.text('Troy'), findsOneWidget,
          reason: 'a fresh controller every frame would drop this');
    });

    testWidgets('a checkbox stays checked', (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);

      await tester.tap(find.byKey(const Key('save')));
      await tester.pump();
      expect(s.inputs['save'], true);

      await pumpSession(tester, s);
      final box = tester.widget<CheckboxListTile>(
          find.byKey(const Key('save')));
      expect(box.value, isTrue,
          reason: 'reading value from the component would reset it');
    });

    testWidgets('a slider stays where it was dragged', (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);

      s.sendInput('n', 80.0);
      await pumpSession(tester, s);

      final slider = tester.widget<Slider>(find.byKey(const Key('n')));
      expect(slider.value, 80.0);
    });

    testWidgets('a select keeps its selection', (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);

      s.sendInput('engine', 'slow');
      await pumpSession(tester, s);

      final dd = tester.widget<DropdownButton<String>>(
          find.byKey(const Key('engine')));
      expect(dd.value, 'slow');
    });

    testWidgets('radios keep their selection', (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);

      s.sendInput('mode', 'b');
      await pumpSession(tester, s);

      final group =
          tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
      expect(group.groupValue, 'b');
    });
  });

  group('input_update', () {
    testWidgets('a server push reaches the control', (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);

      s.receive({'type': 'input_update', 'id': 'name', 'value': 'Jorge'});
      await pumpSession(tester, s);

      expect(s.inputs['name'], 'Jorge');
      expect(find.text('Jorge'), findsOneWidget);
    });

    test('a selection push lands, and nothing is echoed back', () {
      final s = GlintySession()..receive(welcomeWith(formTree));
      s.sent.clear();

      s.receive({'type': 'input_update', 'id': 'engine',
        'selected': 'slow'});

      expect(s.inputs['engine'], 'slow');
      expect(s.sent, isEmpty,
          reason: 'the server already synced its copy; answering '
              'would be a second write');
    });
  });

  group('conditional panels', () {
    final condTree = {
      'component': 'page',
      'children': [
        {'component': 'checkbox_input', 'id': 'more', 'label': 'More',
          'value': false, 'emit': 'settle'},
        {'component': 'conditional_panel',
          'condition': {'op': 'is', 'id': 'more', 'values': [true]},
          'children': [
            {'component': 'text', 'value': 'the hidden bit',
              'variant': 'normal'}
          ]},
      ],
    };

    testWidgets('hide and show as the input they watch changes',
        (tester) async {
      final s = GlintySession()..receive(welcomeWith(condTree));
      await pumpSession(tester, s);
      expect(find.text('the hidden bit'), findsNothing);

      await tester.tap(find.byKey(const Key('more')));
      await tester.pump();
      await pumpSession(tester, s);
      expect(find.text('the hidden bit'), findsOneWidget);
    });

    test('the matching rule is the one the protocol shares', () {
      // logicals by truthiness, everything else by string, an unset
      // input matches nothing -- same as R and the browser
      final inputs = {'b': true, 's': 'fast', 'n': 3};
      expect(evalCondition({'op': 'is', 'id': 'b', 'values': [true]},
          inputs), isTrue);
      expect(evalCondition({'op': 'is', 'id': 's', 'values': ['fast']},
          inputs), isTrue);
      expect(evalCondition({'op': 'is', 'id': 'n', 'values': ['3']},
          inputs), isTrue);
      expect(evalCondition({'op': 'is', 'id': 'gone', 'values': ['x']},
          inputs), isFalse);
      expect(
          evalCondition({
            'op': 'and',
            'args': [
              {'op': 'is', 'id': 'b', 'values': [true]},
              {'op': 'is', 'id': 's', 'values': ['slow']},
            ]
          }, inputs),
          isFalse);
      expect(
          evalCondition({
            'op': 'not',
            'arg': {'op': 'is', 'id': 's', 'values': ['slow']}
          }, inputs),
          isTrue);
      // an operator from a newer server hides rather than throws
      expect(evalCondition({'op': 'xor', 'args': []}, inputs), isFalse);
    });
  });

  group('a refused resume drops the session it described', () {
    test('values, inputs and tickets all go', () {
      final s = GlintySession()..receive(welcomeWith(formTree));
      s.sendInput('name', 'Troy');
      s.receive({'type': 'output', 'id': 'greeting', 'kind': 'text',
        'value': 'Hello, Troy'});
      s.receive({'type': 'ticket', 'id': 'f', 'purpose': 'upload',
        'token': 'tk_1', 'expires': 30});
      final before = s.generation;

      // the server refuses the resume: that session is gone
      s.receive({
        'type': 'welcome', 'session': 's2', 'protocol': 3,
        'resumed': false, 'ui_revision': 'r2', 'ui': formTree,
      });

      expect(s.values, isEmpty,
          reason: "another session's outputs must not stay on screen");
      expect(s.tickets, isEmpty);
      expect(s.inputs['name'], 'seeded',
          reason: 'reseeded from the new tree, not carried over');
      expect(s.sessionId, 's2');
      expect(s.generation, greaterThan(before),
          reason: 'widgets key off this to drop stale controllers');
    });

    testWidgets('and the widgets holding them are discarded',
        (tester) async {
      final s = GlintySession()..receive(welcomeWith(formTree));
      await pumpSession(tester, s);
      await tester.enterText(find.byKey(const Key('name')), 'Troy');
      await tester.pump();
      expect(find.text('Troy'), findsOneWidget);

      s.receive({
        'type': 'welcome', 'session': 's2', 'protocol': 3,
        'resumed': false, 'ui_revision': 'r2', 'ui': formTree,
      });
      await pumpSession(tester, s);

      expect(find.text('Troy'), findsNothing,
          reason: 'a controller belonging to a dead session must go '
              'with it');
      expect(find.text('seeded'), findsOneWidget);
    });
  });

  group('what hello declares', () {
    test('features are declared only when wired', () {
      expect(GlintySession().hello().body['features'], isEmpty);
      expect(
          GlintySession(features: const ['download'])
              .hello()
              .body['features'],
          contains('download'));
    });

    testWidgets('a link with no handler is not tappable', (tester) async {
      final link = GlintyComponent.fromJson({
        'component': 'link', 'value': 'docs',
        'href': 'https://example.com', 'external': true,
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
              builder: (c) => GlintyRenderer().build(c, link)),
        ),
      ));
      expect(find.byType(InkWell), findsNothing,
          reason: 'an InkWell with an empty onTap looks tappable and '
              'does nothing');

      String? tapped;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
              builder: (c) => GlintyRenderer(
                    onLink: (href, {bool external = false}) =>
                        tapped = href,
                  ).build(c, link)),
        ),
      ));
      await tester.tap(find.byType(InkWell));
      expect(tapped, 'https://example.com');
    });
  });

  test('the seeded values match what the real server sends', () {
    // the transcript's tree, seeded here, must agree with what
    // R/seed.R put in the server's own store for the same tree
    final s = GlintySession()
      ..receive(serverFrame('hello-welcome', 'welcome'));
    expect(s.inputs['name'], '',
        reason: 'an empty text field is "", both sides');
  });
}
