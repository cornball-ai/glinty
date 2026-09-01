// clear_on: the composer declaration (#60).
//
// A field that names an event empties itself and reports "" when this
// client emits that event -- AFTER the event frame, so the server
// handler reads the full draft. What is this client's to test: the
// frame order out of sendEvent, the store settling at '', the mounted
// controller adopting the clear, unrelated events leaving the draft
// be, and the walk finding composers in dynamic slots and modals.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcome() => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 4,
      'ui_revision': 'r1',
      'ui': {
        'component': 'page',
        'title': 'Composer',
        'children': [
          {
            'component': 'textarea_input', 'id': 'draft',
            'label': 'Message', 'rows': 2, 'emit': 'live',
            'clear_on': 'send',
          },
          {'component': 'button', 'id': 'send', 'label': 'Send'},
          {'component': 'button', 'id': 'other', 'label': 'Other'},
        ],
      },
    };

Future<void> pump(WidgetTester tester, GlintySession s) async {
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GlintyView(session: s))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('send clears the composer: event first, then the emptied report',
      (tester) async {
    final s = GlintySession()..receive(welcome());
    await pump(tester, s);

    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pumpAndSettle();
    expect(s.inputs['draft'], 'hello world',
        reason: 'live emit already reported the draft');

    final before = s.sent.length;
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final out = s.sent.sublist(before);
    expect(out.length, 2);
    expect(out[0].body, {'type': 'event', 'id': 'send'},
        reason: 'the event goes first, so the handler reads the draft');
    expect(out[1].body, {'type': 'input', 'id': 'draft', 'value': ''},
        reason: 'the cleared report follows the event');
    expect(s.inputs['draft'], '');

    // the mounted controller adopted the clear (the push counter)
    await pump(tester, s);
    expect(find.text('hello world'), findsNothing);
  });

  testWidgets('an unrelated event leaves the draft be', (tester) async {
    final s = GlintySession()..receive(welcome());
    await pump(tester, s);

    await tester.enterText(find.byType(TextField), 'kept');
    await tester.pumpAndSettle();

    final before = s.sent.length;
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    final out = s.sent.sublist(before);
    expect(out.length, 1);
    expect(out[0].body, {'type': 'event', 'id': 'other'});
    expect(s.inputs['draft'], 'kept');
  });

  test('a composer inside a dynamic slot clears too', () {
    final s = GlintySession()
      ..receive({
        'type': 'welcome',
        'session': 's2',
        'protocol': 4,
        'ui_revision': 'r1',
        'ui': {
          'component': 'page',
          'title': 'Slots',
          'children': [
            {'component': 'ui_output', 'id': 'panel'},
          ],
        },
      })
      ..receive({
        'type': 'output',
        'id': 'panel',
        'kind': 'ui',
        'value': {
          'component': 'text_input', 'id': 'quick',
          'emit': 'live', 'clear_on': 'go',
        },
      });
    s.inputs['quick'] = 'typed';
    s.sendEvent('go');
    expect(s.inputs['quick'], '');
    expect(s.sent.last.body, {'type': 'input', 'id': 'quick', 'value': ''});
  });

  test('a composer inside a modal clears too', () {
    final s = GlintySession()
      ..receive({
        'type': 'welcome',
        'session': 's3',
        'protocol': 4,
        'ui_revision': 'r1',
        'ui': {
          'component': 'page',
          'title': 'Modal',
          'children': [
            {'component': 'text', 'value': 'page', 'variant': 'normal'},
          ],
        },
      })
      ..receive({
        'type': 'modal',
        'title': 'Quick switcher',
        'body': [
          {
            'component': 'text_input', 'id': 'jump',
            'emit': 'live', 'clear_on': 'go',
          },
        ],
      });
    s.inputs['jump'] = 'roo';
    s.sendEvent('go');
    expect(s.inputs['jump'], '');

    // closing the modal takes the composer with it: the walk holds
    // only what is on screen
    s.receive({'type': 'modal', 'action': 'hide'});
    s.inputs['jump'] = 'again';
    s.sendEvent('go');
    expect(s.inputs['jump'], 'again',
        reason: 'a dismissed modal no longer clears anything');
  });
}
