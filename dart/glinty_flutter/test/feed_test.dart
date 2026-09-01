// The feed: delta messages against a held window, and the scroller
// that owns the stick-to-bottom contract.
//
// What is this client's to test: the session's window arithmetic
// (append, patch-newest, reset, trim to the keep the MESSAGE
// carries), the widget showing what the window holds, the pin
// surviving appends, release on scroll-up with the way back down,
// and the unbounded spot degrading to shrink-wrap instead of a
// viewport crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcome({int keep = 200}) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 4,
      'ui_revision': 'r1',
      'ui': {
        'component': 'page',
        'title': 'Room',
        'width': 'full',
        'children': [
          {
            'component': 'row',
            'align': 'stretch',
            'children': [
              {
                'component': 'panel',
                'fill': true,
                'grow': 1,
                'children': [
                  {'component': 'feed', 'id': 'log', 'keep': keep,
                    'grow': 1},
                ],
              },
            ],
          },
        ],
      },
    };

Map<String, dynamic> item(String text) =>
    {'component': 'text', 'value': text, 'variant': 'normal'};

Map<String, dynamic> append(String text, {int keep = 200}) =>
    {'type': 'feed', 'id': 'log', 'op': 'append', 'keep': keep,
      'item': item(text)};

Future<void> pump(WidgetTester tester, GlintySession s) async {
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GlintyView(session: s))));
  await tester.pumpAndSettle();
}

void main() {
  test('the session window: append, patch-newest, reset, trim', () {
    final s = GlintySession()..receive(welcome());
    s.receive(append('a'));
    s.receive(append('b'));
    expect(s.feeds['log']!.items.map((c) => c.str('value')), ['a', 'b']);
    expect(s.feeds['log']!.tick, 2);

    s.receive({'type': 'feed', 'id': 'log', 'op': 'patch', 'keep': 200,
      'item': item('b, streamed')});
    expect(s.feeds['log']!.items.map((c) => c.str('value')),
        ['a', 'b, streamed']);

    // trim to the keep the message carries -- oldest fall off the top
    for (final t in ['c', 'd', 'e']) {
      s.receive(append(t, keep: 3));
    }
    expect(s.feeds['log']!.items.map((c) => c.str('value')),
        ['c', 'd', 'e']);

    s.receive({'type': 'feed', 'id': 'log', 'op': 'reset', 'keep': 200,
      'items': [item('fresh')]});
    expect(s.feeds['log']!.items.map((c) => c.str('value')), ['fresh']);

    s.receive({'type': 'feed', 'id': 'log', 'op': 'reset', 'keep': 200,
      'items': []});
    expect(s.feeds['log']!.items, isEmpty);

    // a fresh welcome (new tree, new revision) takes the feeds with
    // the page they lived on; an ADOPTED welcome keeps them, since
    // the server replays each window as a reset right behind it
    s.receive(append('stale'));
    s.receive({...welcome(), 'ui_revision': 'r2'});
    expect(s.feeds, isEmpty);
  });

  test('a patch against an empty feed appends rather than vanishing', () {
    final s = GlintySession()..receive(welcome());
    s.receive({'type': 'feed', 'id': 'log', 'op': 'patch', 'keep': 200,
      'item': item('only')});
    expect(s.feeds['log']!.items.map((c) => c.str('value')), ['only']);
  });

  // The scroll tests bound the feed directly: a grown feed inside a
  // column inside Scaffold's (bounded) body carries a real height
  // record, so the feed scrolls. Inside a page it sits in the page's
  // own scroll view instead, where it shrink-wraps by design -- the
  // last test pins that path. Re-pumping after receives stands in
  // for the notification GlintyView would get.
  Future<void> pumpBounded(WidgetTester tester, GlintySession s) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => GlintyRenderer(feeds: s.feeds)
                    .build(context, GlintyComponent.fromJson({
                      'component': 'column',
                      'children': [
                        {'component': 'feed', 'id': 'log', 'keep': 200,
                          'grow': 1},
                      ],
                    }))))));
    await tester.pumpAndSettle();
  }

  testWidgets('items appear as they arrive, pinned to the bottom',
      (tester) async {
    final s = GlintySession()..receive(welcome());
    await pumpBounded(tester, s);

    for (var i = 0; i < 30; i++) {
      s.receive(append('message $i'));
    }
    await pumpBounded(tester, s);

    // pinned: the newest is on screen, the chip is not
    expect(find.text('message 29'), findsOneWidget);
    expect(find.text('↓ Latest'), findsNothing);
  });

  testWidgets('scrolling up releases the pin; the chip leads back down',
      (tester) async {
    final s = GlintySession()..receive(welcome());
    await pumpBounded(tester, s);
    for (var i = 0; i < 30; i++) {
      s.receive(append('message $i'));
    }
    await pumpBounded(tester, s);

    // the reader scrolls up and away from the bottom
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();

    // a new message must not yank them down -- it offers the way back
    s.receive(append('while reading'));
    await pumpBounded(tester, s);
    expect(find.text('↓ Latest'), findsOneWidget);

    await tester.tap(find.text('↓ Latest'));
    await tester.pumpAndSettle();
    expect(find.text('↓ Latest'), findsNothing);
    expect(find.text('while reading'), findsOneWidget);
  });

  testWidgets('a feed on a plain page shrink-wraps instead of crashing',
      (tester) async {
    // No stretch shell, no bound: the height record says unbounded,
    // so the feed lets the page scroll -- a viewport there would be
    // the unbounded-height crash.
    final s = GlintySession()
      ..receive({
        'type': 'welcome',
        'session': 's2',
        'protocol': 4,
        'ui_revision': 'r1',
        'ui': {
          'component': 'page',
          'title': 'Plain',
          'children': [
            {'component': 'feed', 'id': 'log', 'keep': 200},
            {'component': 'text', 'value': 'after', 'variant': 'normal'},
          ],
        },
      });
    await pump(tester, s);
    s.receive(append('present'));
    await pump(tester, s);
    expect(find.text('present'), findsOneWidget);
    expect(find.text('after'), findsOneWidget);
  });
}
