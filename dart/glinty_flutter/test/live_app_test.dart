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
      'protocol': 4,
      'ui_revision': revision,
      'ui': tree,
      'resumed': ?resumed,
    };

void main() {
  _round3();
  _round4();
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
    final box = tester.widget<Checkbox>(find.descendant(
        of: find.byKey(const Key('more')),
        matching: find.byType(Checkbox)));
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
    // measure, modal and progress are this client's own and always
    // hold; download is the embedder's and holds only when wired.
    expect(sockets.single.sent.single['features'],
        isNot(contains('download')));

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
    expect(sockets.last.sent.single['features'],
        isNot(contains('download')));
  });
}

// --- Codex round 3: the five that were still wrong ---

void _round3() {
  testWidgets('a push the user typed over is spent, not deferred',
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

    await tester.tap(find.byKey(const Key('name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Tro');
    await tester.pumpAndSettle();

    // arrives while focused: refused
    socket.deliver({'type': 'input_update', 'id': 'name',
      'value': 'STALE'});
    await tester.pumpAndSettle();
    expect(find.text('Tro'), findsOneWidget);

    // focus leaves, and any later rebuild must NOT resurrect it
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    socket.deliver({'type': 'output', 'id': 'unrelated', 'kind': 'text',
      'value': 'x'});
    await tester.pumpAndSettle();

    expect(find.text('Tro'), findsOneWidget,
        reason: 'deferring instead of dropping just moves the '
            'overwrite to the next rebuild');
    expect(find.text('STALE'), findsNothing);

    // but a NEWER push, after focus left, does land
    socket.deliver({'type': 'input_update', 'id': 'name',
      'value': 'FRESH'});
    await tester.pumpAndSettle();
    expect(find.text('FRESH'), findsOneWidget);
  });

  testWidgets('input_update relabels and rebounds a slider',
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
    socket.deliver(welcomeSlider());
    await tester.pumpAndSettle();

    expect(find.text('Points:'), findsOneWidget);
    var slider = tester.widget<Slider>(find.byKey(const Key('n')));
    expect(slider.max, 100);

    socket.deliver({'type': 'input_update', 'id': 'n', 'value': 200,
      'label': 'Many points:', 'min': 0, 'max': 500, 'step': 50});
    await tester.pumpAndSettle();

    expect(find.text('Many points:'), findsOneWidget);
    slider = tester.widget<Slider>(find.byKey(const Key('n')));
    expect(slider.max, 500);
    expect(slider.value, 200);
    expect(slider.divisions, 10, reason: '(500 - 0) / 50');
  });

  testWidgets('a select and a radio group show their labels',
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
    expect(find.text('Engine:'), findsOneWidget);

    socket.deliver({'type': 'input_update', 'id': 'engine',
      'label': 'Backend:'});
    await tester.pumpAndSettle();
    expect(find.text('Backend:'), findsOneWidget);
    expect(find.text('Engine:'), findsNothing);
  });

  testWidgets('a download button with nowhere to go is disabled',
      (tester) async {
    final dl = GlintyComponent.fromJson({
      'component': 'download_button', 'id': 'report',
      'label': 'Save', 'variant': 'default',
    });
    // no onTicket: the press could only request a ticket and throw
    // the grant away
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => GlintyRenderer().build(c, dl)),
      ),
    ));
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);

    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (c) => GlintyRenderer(
                  onTicket: (id, purpose) => asked++,
                ).build(c, dl)),
      ),
    ));
    await tester.tap(find.byType(ElevatedButton));
    expect(asked, 1);

    // And it can ask again. onTicket and awaitTicket are separate
    // arguments, so an embedder may wire the request without wiring
    // the queue that answers it -- and a button that goes on waiting
    // for an answer nobody can deliver is disabled from its first
    // press onwards.
    await tester.pump();
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
        reason: 'nothing is coming, so there is nothing to wait for');
    await tester.tap(find.byType(ElevatedButton));
    expect(asked, 2);
  });

  test('a disconnect before welcome does not kill the replacement',
      () async {
    // Driven through GlintyConnection so the timeout is ours to set:
    // an earlier version of this test advanced past the REPLACEMENT
    // socket's own deadline too, so it passed by welcoming whatever
    // third socket the retry had made. The assertion has to be about
    // one identified socket surviving, not about "the last one".
    // The retry delay deliberately dominates the timeout, so the two
    // deadlines cannot overlap: the dead socket's timer would fire
    // at t=100, well before the replacement is even created at
    // t=300, and its own deadline at t=400.
    final sockets = <FakeSocket>[];
    final conn = GlintyConnection(
      url: Uri.parse('ws://x/ws'),
      welcomeTimeout: const Duration(milliseconds: 100),
      retryBase: const Duration(milliseconds: 300),
      retryCap: const Duration(milliseconds: 300),
      open: (_) async {
        final s = FakeSocket();
        sockets.add(s);
        return s;
      },
    );
    await conn.start();
    expect(sockets, hasLength(1));

    // dropped before it ever answered hello
    sockets.first.drop();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(sockets, hasLength(2), reason: 'one retry, one socket');
    final replacement = sockets[1];

    // t=350: the stale timer's moment (t=100) has passed. If it were
    // still armed it would have run _onClosed a second time, spent
    // another retry and opened another socket.
    expect(sockets, hasLength(2),
        reason: "the dead socket's timer would have forced an extra "
            'retry');
    expect(replacement.closed, isFalse);

    replacement.deliver(welcome());
    await Future<void>.delayed(Duration.zero);
    expect(conn.state, GlintyConnectionState.live);
    expect(conn.session.ui, isNotNull);
    conn.dispose();
  });

  test('adopting a cached tree still seeds its inputs', () {
    final cached = GlintyComponent.fromJson(tree);
    final s = GlintySession(cachedUi: cached, cachedRevision: 'r1');
    s.receive(welcome());

    expect(s.source, GlintyTreeSource.adopted);
    expect(s.inputs['more'], false,
        reason: 'an adopted tree with no seeded state leaves every '
            'conditional reading "unset", so panels start wrong');
    expect(s.conditionHolds(
        {'op': 'is', 'id': 'more', 'values': [true]}), isFalse);
  });
}

final sliderTree = {
  'component': 'page',
  'children': [
    {'component': 'slider_input', 'id': 'n', 'label': 'Points:',
      'min': 0, 'max': 100, 'value': 25, 'emit': 'live'},
  ],
};

Map<String, dynamic> welcomeSlider() => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 4,
      'ui_revision': 'rs',
      'ui': sliderTree,
    };

// --- Codex round 4: tested through the app, not around it ---

void _round4() {
  testWidgets('a download button in a real app with no onDownload is dead',
      (tester) async {
    late FakeSocket socket;
    Widget app({void Function(Uri)? onDownload}) => MaterialApp(
          home: Scaffold(
            body: GlintyApp(
              url: Uri.parse('ws://x/ws'),
              onDownload: onDownload,
              open: (_) async => socket = FakeSocket(),
            ),
          ),
        );

    // The previous test built a GlintyRenderer by hand, which never
    // exercised the wiring GlintyView does -- and GlintyView handed
    // it a ticket sink unconditionally.
    await tester.pumpWidget(app());
    await tester.pump();
    socket.deliver(welcomeDownload());
    await tester.pumpAndSettle();

    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'a grant with nowhere to go must not be requestable');
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(socket.sent.where((m) => m['type'] == 'ticket'), isEmpty);

    await tester.pumpWidget(app(onDownload: (u) {}));
    await tester.pump();
    socket.deliver(welcomeDownload());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(socket.sent.where((m) => m['type'] == 'ticket'), hasLength(1));
  });

  testWidgets('a radio group shows its label, and relabels', (tester) async {
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
    socket.deliver(welcomeRadio());
    await tester.pumpAndSettle();

    expect(find.text('Mode:'), findsOneWidget);

    socket.deliver({'type': 'input_update', 'id': 'mode',
      'label': 'Strategy:', 'selected': 'b'});
    await tester.pumpAndSettle();

    expect(find.text('Strategy:'), findsOneWidget);
    expect(find.text('Mode:'), findsNothing);
    final group =
        tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(group.groupValue, 'b');
  });

  testWidgets('a number field shows the bounds the server pushed',
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
    socket.deliver(welcomeNumber());
    await tester.pumpAndSettle();

    expect(find.text('1.0 to 10.0'), findsOneWidget);

    socket.deliver({'type': 'input_update', 'id': 'k',
      'min': 1, 'max': 100, 'step': 5});
    await tester.pumpAndSettle();

    expect(find.text('1.0 to 100.0, step 5.0'), findsOneWidget,
        reason: 'bounds stored and never shown are bounds the user '
            'is not told about');
  });
}

final downloadTree = {
  'component': 'page',
  'children': [
    {'component': 'download_button', 'id': 'report', 'label': 'Save',
      'variant': 'default'},
  ],
};
final radioTree = {
  'component': 'page',
  'children': [
    {'component': 'radio_buttons', 'id': 'mode', 'label': 'Mode:',
      'selected': 'a', 'emit': 'settle', 'choices': [
        {'value': 'a', 'label': 'A'},
        {'value': 'b', 'label': 'B'},
      ]},
  ],
};
final numberTree = {
  'component': 'page',
  'children': [
    {'component': 'number_input', 'id': 'k', 'label': 'K:',
      'value': 3, 'min': 1, 'max': 10, 'emit': 'live'},
  ],
};

Map<String, dynamic> _welcomeOf(Object tree, String rev) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 4,
      'ui_revision': rev,
      'ui': tree,
    };

Map<String, dynamic> welcomeDownload() => _welcomeOf(downloadTree, 'rd');
Map<String, dynamic> welcomeRadio() => _welcomeOf(radioTree, 'rr');
Map<String, dynamic> welcomeNumber() => _welcomeOf(numberTree, 'rn');
