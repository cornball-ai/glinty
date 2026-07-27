// The app driven the way a user drives it: tap, and expect the
// screen to change.
//
// The earlier stateful-input tests called pumpSession() again after
// each interaction, which repaints on the app's behalf and hides
// whether it would ever repaint itself. These do not: every
// expectation here follows a `tester.pump()` and nothing else, so a
// control that updates the store without telling anyone fails.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';
import 'package:web_socket/web_socket.dart';

/// A socket the test feeds.
class FakeSocket implements WebSocket {
  final List<Map<String, dynamic>> sent = [];
  final _events = StreamController<WebSocketEvent>();
  bool closed = false;

  void deliver(Map<String, dynamic> msg) =>
      _events.add(TextDataReceived(jsonEncode(msg)));

  void drop() {
    if (closed) return;
    closed = true;
    _events.add(CloseReceived(1006, 'gone'));
    _events.close();
  }

  @override
  void sendText(String s) {
    if (closed) throw WebSocketConnectionClosed();
    sent.add(jsonDecode(s) as Map<String, dynamic>);
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!closed) {
      closed = true;
      unawaited(_events.close());
    }
  }

  @override
  void sendBytes(_) => throw UnimplementedError();

  @override
  String get protocol => '';
}

final tree = {
  'component': 'page',
  'title': 'Live',
  'children': [
    {'component': 'checkbox_input', 'id': 'more', 'label': 'More',
      'value': false, 'emit': 'settle'},
    {'component': 'text_input', 'id': 'name', 'label': 'Name:',
      'value': '', 'emit': 'live'},
    {'component': 'select_input', 'id': 'engine', 'label': 'Engine:',
      'multiple': false, 'emit': 'settle', 'choices': [
        {'value': 'fast', 'label': 'Fast'}
      ]},
    {'component': 'conditional_panel',
      'condition': {'op': 'is', 'id': 'more', 'values': [true]},
      'children': [
        {'component': 'text', 'value': 'extra bit', 'variant': 'normal'}
      ]},
  ],
};

Map<String, dynamic> welcome({bool? resumed, String revision = 'r1'}) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': revision,
      'ui': tree,
      'resumed': ?resumed,
    };

void main() {
  testWidgets('a tap redraws the app without a server frame',
      (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcome());
    await tester.pumpAndSettle();

    // the panel is hidden and the box unchecked
    expect(find.text('extra bit'), findsNothing);

    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();

    // no server frame arrived; the app has to have redrawn itself
    expect(find.text('extra bit'), findsOneWidget,
        reason: 'a local edit that does not notify leaves the UI '
            'showing yesterday until some later frame lands');
    final box =
        tester.widget<CheckboxListTile>(find.byKey(const Key('more')));
    expect(box.value, isTrue);
    expect(socket.sent.where((m) => m['type'] == 'input').length, 1);
  });

  testWidgets('typing redraws and reports, without a repump',
      (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcome());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('name')), 'Troy');
    await tester.pumpAndSettle();

    expect(find.text('Troy'), findsOneWidget);
    final inputs =
        socket.sent.where((m) => m['type'] == 'input').toList();
    expect(inputs.single['value'], 'Troy');
  });

  testWidgets('a focused field is not overwritten by a server push',
      (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcome());
    await tester.pumpAndSettle();

    // focus it and type, the way a user mid-word has it
    await tester.tap(find.byKey(const Key('name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Tro');
    await tester.pumpAndSettle();

    socket.deliver({'type': 'input_update', 'id': 'name',
      'value': 'SERVER SAYS'});
    await tester.pumpAndSettle();

    expect(find.text('Tro'), findsOneWidget,
        reason: 'the browser refuses this too: never stomp the '
            'element that has focus');
    expect(find.text('SERVER SAYS'), findsNothing);
  });

  testWidgets('input_update repopulates a select', (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcome());
    await tester.pumpAndSettle();

    socket.deliver({
      'type': 'input_update',
      'id': 'engine',
      'selected': 'slow',
      'choices': [
        {'value': 'fast', 'label': 'Fast'},
        {'value': 'slow', 'label': 'Slow'},
      ],
    });
    await tester.pumpAndSettle();

    final dd = tester
        .widget<DropdownButton<String>>(find.byKey(const Key('engine')));
    expect(dd.value, 'slow');
    expect(dd.items!.length, 2,
        reason: 'the tree still lists one choice; the update carries '
            'the rest and the control must show them');
  });

  testWidgets('a hidden conditional panel keeps its subtree alive',
      (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcome());
    await tester.pumpAndSettle();

    // hidden: not painted, but still in the tree -- the documented
    // difference between conditional_panel and render_ui
    expect(find.text('extra bit'), findsNothing);
    expect(find.text('extra bit', skipOffstage: false), findsOneWidget,
        reason: 'hiding is display, not destruction (?conditional_panel)');
  });

  testWidgets('an interaction during a reconnect is not lost',
      (tester) async {
    final sockets = <FakeSocket>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async {
            final s = FakeSocket();
            sockets.add(s);
            return s;
          },
        ),
      ),
    ));
    await tester.pump();
    sockets.last.deliver(welcome());
    await tester.pumpAndSettle();

    sockets.last.drop();
    await tester.pump();

    // the user taps while the socket is down
    await tester.tap(find.byKey(const Key('more')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    expect(sockets, hasLength(2));
    sockets.last.deliver(welcome());
    await tester.pumpAndSettle();

    final inputs =
        sockets.last.sent.where((m) => m['type'] == 'input').toList();
    expect(inputs, hasLength(1),
        reason: 'an interaction the user made once is not the '
            "client's to discard");
    expect(inputs.single['id'], 'more');
    // and it did not overtake hello
    expect(sockets.last.sent.first['type'], 'hello');
  });

  testWidgets('a refused resume does not replay the old session',
      (tester) async {
    final sockets = <FakeSocket>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async {
            final s = FakeSocket();
            sockets.add(s);
            return s;
          },
        ),
      ),
    ));
    await tester.pump();
    sockets.last.deliver(welcome());
    await tester.pumpAndSettle();

    sockets.last.drop();
    await tester.pump();
    await tester.tap(find.byKey(const Key('more')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // the server refuses the resume: that session is gone
    sockets.last.deliver(welcome(resumed: false, revision: 'r2'));
    await tester.pumpAndSettle();

    final inputs =
        sockets.last.sent.where((m) => m['type'] == 'input').toList();
    expect(inputs, isEmpty,
        reason: "one user's interactions must not be applied to "
            "another session's state");
  });

  testWidgets('a silent server stops instead of spinning forever',
      (tester) async {
    // the socket opens and the server never answers hello
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // past the welcome timeout and every retry
    await tester.pump(const Duration(seconds: 20));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(seconds: 20));
    }
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'a bounded retry promise means nothing if silence '
            'never counts as failure');
    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('rewiring onDownload reconnects, changing the closure does not',
      (tester) async {
    final sockets = <FakeSocket>[];
    Widget app({void Function(Uri)? onDownload}) => MaterialApp(
          home: Scaffold(
            body: GlintyApp(
              url: Uri.parse('ws://x/ws'),
              onDownload: onDownload,
              open: (_) async {
                final s = FakeSocket();
                sockets.add(s);
                return s;
              },
            ),
          ),
        );

    await tester.pumpWidget(app());
    await tester.pump();
    expect(sockets.single.sent.single['features'], isEmpty);

    // a fresh closure, same capability: no reconnect
    await tester.pumpWidget(app(onDownload: (u) {}));
    await tester.pump();
    expect(sockets, hasLength(2),
        reason: 'wiring a capability changes what hello declares');
    expect(sockets.last.sent.single['features'], contains('download'));

    await tester.pumpWidget(app(onDownload: (u) {}));
    await tester.pump();
    expect(sockets, hasLength(2),
        reason: 'a closure rebuilt each frame is the same capability');

    await tester.pumpWidget(app());
    await tester.pump();
    expect(sockets, hasLength(3));
    expect(sockets.last.sent.single['features'], isEmpty);
  });
}
