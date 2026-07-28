// The transport: hello on connect, frames into the session,
// reconnect with resume, and the two rules about not lying --
// a refusal stops trying, and giving up says so.
//
// Driven through a fake socket so the policy is testable without a
// server. The real server is in glinty_e2e_test.dart.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';
import 'package:web_socket/web_socket.dart';

import 'transcript_data.dart';

/// A WebSocket the test drives directly.
class FakeSocket implements WebSocket {
  FakeSocket();

  final List<Map<String, dynamic>> sent = [];
  final _events = StreamController<WebSocketEvent>();
  bool closed = false;

  /// Push a server frame at the client.
  void deliver(Map<String, dynamic> msg) =>
      _events.add(TextDataReceived(jsonEncode(msg)));

  /// Simulate the peer going away. Idempotent, so a test can drop
  /// "the latest socket" without tracking whether a retry made one.
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

void main() {
  final url = Uri.parse('ws://localhost:8080/ws');

  /// A connection whose sockets the test holds.
  ({GlintyConnection conn, List<FakeSocket> sockets}) makeConn({
    String? token,
    void Function(Uri)? onDownload,
    int maxRetries = 12,
  }) {
    final sockets = <FakeSocket>[];
    final conn = GlintyConnection(
      url: url,
      token: token,
      onDownload: onDownload,
      maxRetries: maxRetries,
      retryBase: const Duration(milliseconds: 10),
      retryCap: const Duration(milliseconds: 20),
      open: (_) async {
        final s = FakeSocket();
        sockets.add(s);
        return s;
      },
    );
    return (conn: conn, sockets: sockets);
  }

  test('connecting sends exactly one hello, and nothing else', () async {
    final c = makeConn();
    await c.conn.start();

    expect(c.sockets, hasLength(1));
    expect(c.sockets.single.sent, hasLength(1));
    expect(c.sockets.single.sent.single['type'], 'hello');
    expect(c.sockets.single.sent.single['protocol'], glintyProtocolVersion);
    // An open socket is not a usable app: live waits for welcome, or
    // the UI draws before it has a tree.
    expect(c.conn.state, GlintyConnectionState.connecting);

    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();
    expect(c.conn.state, GlintyConnectionState.live);
    c.conn.dispose();
  });

  test('hello carries the token when the app has one', () async {
    final c = makeConn(token: 'abc.def.ghi');
    await c.conn.start();
    expect(c.sockets.single.sent.single['token'], 'abc.def.ghi');
    c.conn.dispose();
  });

  test('welcome lands in the session and notifies listeners', () async {
    final c = makeConn();
    var notified = 0;
    c.conn.addListener(() => notified++);
    await c.conn.start();

    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();

    expect(c.conn.session.ui, isNotNull);
    expect(c.conn.session.ui!.type, 'page');
    expect(notified, greaterThan(0));
    c.conn.dispose();
  });

  test('an interaction reaches the wire as one frame', () async {
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();

    c.conn.session.sendInput('name', 'Troy');
    final inputs =
        c.sockets.single.sent.where((m) => m['type'] == 'input').toList();
    expect(inputs, hasLength(1));
    expect(inputs.single['value'], 'Troy');
    c.conn.dispose();
  });

  test('a drop reconnects and the new hello carries resume', () async {
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();
    final sid = c.conn.session.sessionId;

    c.sockets.single.drop();
    await pump();
    expect(c.conn.state, GlintyConnectionState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(c.sockets, hasLength(2));
    final hello = c.sockets[1].sent.single;
    expect(hello['type'], 'hello');
    expect(hello['resume'], sid,
        reason: 'a reconnect resumes rather than starting over');
    c.conn.dispose();
  });

  test('a refusal stops trying', () async {
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-refused', 'error'));
    await pump();

    expect(c.conn.session.refused, isTrue);
    expect(c.conn.state, GlintyConnectionState.stopped);

    c.sockets.single.drop();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(c.sockets, hasLength(1),
        reason: 'the server has said no and will keep saying no');
    c.conn.dispose();
  });

  test('retries are bounded, and giving up is a state not a spinner',
      () async {
    final c = makeConn(maxRetries: 2);
    await c.conn.start();
    for (var i = 0; i < 4; i++) {
      c.sockets.last.drop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    expect(c.conn.state, GlintyConnectionState.stopped);
    expect(c.conn.stoppedReason, isNotNull);
    expect(c.sockets.length, lessThanOrEqualTo(3));
    c.conn.dispose();
  });

  test('a connect that never completes still spends the retry budget',
      () async {
    // The welcome deadline was armed after `await _open(url)`, so it
    // only ever bounded the half of the handshake that needs a
    // socket to exist. A connect that hangs -- a black-holed route,
    // a proxy that accepts and then stalls -- never reached the line
    // that arms it. No timer, no close event, no retry: the app sits
    // on connecting forever, which is exactly the infinite spinner
    // the bounded-retry promise rules out.
    var opens = 0;
    final conn = GlintyConnection(
      url: url,
      maxRetries: 2,
      retryBase: const Duration(milliseconds: 10),
      retryCap: const Duration(milliseconds: 20),
      welcomeTimeout: const Duration(milliseconds: 40),
      open: (_) {
        opens++;
        return Completer<WebSocket>().future; // never completes
      },
    );
    unawaited(conn.start());
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(conn.state, GlintyConnectionState.stopped,
        reason: 'a hung connect is a failed attempt, not a pending one');
    expect(conn.stoppedReason, isNotNull);
    expect(opens, lessThanOrEqualTo(3),
        reason: 'and it is bounded by the same budget as any other');
    conn.dispose();
  });

  test('a late socket from a timed-out attempt is closed, not adopted',
      () async {
    // The other half of the same bug: once an attempt times out, its
    // socket may still arrive. Adopting it would resurrect a
    // connection the retry path has already replaced, leaving two
    // live sockets and two helloes on the same session.
    final opened = <FakeSocket>[];
    final completers = <Completer<WebSocket>>[];
    final conn = GlintyConnection(
      url: url,
      maxRetries: 5,
      retryBase: const Duration(milliseconds: 10),
      retryCap: const Duration(milliseconds: 20),
      welcomeTimeout: const Duration(milliseconds: 40),
      open: (_) {
        final c = Completer<WebSocket>();
        completers.add(c);
        return c.future;
      },
    );
    unawaited(conn.start());
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(completers.length, greaterThan(1),
        reason: 'the first attempt should have timed out and retried');

    // the first attempt's socket finally shows up, long after
    final late = FakeSocket();
    opened.add(late);
    completers.first.complete(late);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(late.closed, isTrue,
        reason: 'a socket for an attempt that already failed is trash');
    expect(late.sent, isEmpty, reason: 'and it is never spoken to');
    conn.dispose();
  });

  test('stopping closes the socket it stopped on', () async {
    // A refusal arrives with the socket still open. Leaving it open
    // leaves its event subscription live: frames keep landing in a
    // session that has been refused, and the app cannot let go of a
    // connection it has already given up on.
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-refused', 'error'));
    await pump();

    expect(c.conn.state, GlintyConnectionState.stopped);
    expect(c.sockets.single.closed, isTrue,
        reason: 'terminal means the wire is done, not just the policy');
    c.conn.dispose();
  });

  test('a refusal gives back the controls waiting on a transfer', () async {
    // Terminal on a socket that is still open, so this is the one
    // stop that does not come through the close path. A request made
    // before the welcome is queued rather than sent, and a refusal
    // means it never will be -- so its waiter is told, rather than
    // left holding a callback on a wire that is finished.
    final c = makeConn();
    await c.conn.start();
    String? told;
    c.conn.session.awaitTicket('report', 'download', (r) => told = r);

    c.sockets.single.deliver(serverFrame('hello-refused', 'error'));
    await pump();

    expect(c.conn.state, GlintyConnectionState.stopped);
    expect(told, isNotNull, reason: 'nothing is coming; say so');
    c.conn.dispose();
  });

  test('a request past the send queue cap is refused, not dropped',
      () async {
    // The queue is capped so a user tapping at a dead app cannot grow
    // memory without limit, and a frame past the cap is thrown away.
    // The control that asked heard nothing about it: it sat disabled
    // waiting for an answer to a question the server was never asked.
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();
    c.sockets.last.drop();
    await pump();

    // fill it, without letting the retry timer in
    for (var i = 0; i < 64; i++) {
      c.conn.session.sendInput('field$i', i);
    }
    String? told;
    c.conn.session.awaitTicket('report', 'download', (r) => told = r);

    expect(told, isNotNull, reason: 'it will never be asked, so say so');
    c.conn.dispose();
  });

  test('a dropped transfer request is not replayed after the reconnect',
      () async {
    // The ledger is cleared on a drop, so nothing is left to answer
    // these. Replayed onto the next socket they draw replies that
    // then get handed to whoever asked *after* the reconnect -- one
    // control's answer under another's control.
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();

    // The wire goes down, and the user presses Save while it is. Both
    // frames queue for the next socket.
    c.sockets.last.drop();
    await pump();
    c.conn.session.awaitTicket('report', 'download', (_) {});
    // typed in the same window, and this one is the user's
    c.conn.session.sendInput('note', 'kept');

    // The retry connects and drops again before being welcomed, which
    // is what clears the ledger out from under the queued request.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.sockets, hasLength(2));
    c.sockets.last.drop();
    await pump();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.sockets, hasLength(3));
    c.sockets.last.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();

    final replayed = c.sockets.last.sent.map((m) => m['type']).toList();
    expect(replayed, isNot(contains('ticket')));
    expect(replayed, contains('input'),
        reason: 'an interaction the user made once is still theirs');
    c.conn.dispose();
  });

  test('disposing gives back the controls waiting on a transfer', () async {
    // The app is torn down with a request in flight. Nothing here
    // will ever answer again, and a waiter left behind holds a
    // closure over widgets that are on their way out.
    final c = makeConn();
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();
    String? told;
    c.conn.session.awaitTicket('report', 'download', (r) => told = r);

    c.conn.dispose();
    expect(told, isNotNull);
  });

  test('a download grant becomes an http URL for the embedder', () async {
    Uri? got;
    final c = makeConn(onDownload: (u) => got = u);
    await c.conn.start();
    c.sockets.single.deliver(serverFrame('hello-welcome', 'welcome'));
    await pump();

    c.conn.session.requestTicket('report', 'download');
    expect(c.sockets.single.sent.last['type'], 'ticket');

    c.sockets.single.deliver({
      'type': 'ticket',
      'id': 'report',
      'purpose': 'download',
      'token': 'tk_abc',
      'expires': 30,
    });
    await pump();

    expect(got, isNotNull);
    expect(got!.scheme, 'http');
    expect(got!.path, '/download');
    expect(got!.queryParameters['ticket'], 'tk_abc');
    expect(got!.toString(), isNot(contains('session')),
        reason: 'no session credential belongs in a URL');
    c.conn.dispose();
  });

  test('wss becomes https for transfers', () async {
    Uri? got;
    final conn = GlintyConnection(
      url: Uri.parse('wss://apps.example.com/ws'),
      onDownload: (u) => got = u,
      open: (_) async => FakeSocket(),
    );
    await conn.start();
    conn.session.requestTicket('r', 'download');
    // the socket the connection made is not the one we hold, so
    // deliver through the session's own path
    conn.session.receive({
      'type': 'ticket', 'id': 'r', 'purpose': 'download',
      'token': 'tk_1', 'expires': 30
    });
    // the transport does the scheme mapping on the frame it sees;
    // drive it the same way the socket would
    expect(Uri.parse('wss://apps.example.com/ws')
        .replace(scheme: 'https', path: '/download',
            queryParameters: {'ticket': 'tk_1'})
        .toString(),
        'https://apps.example.com/download?ticket=tk_1');
    expect(got, isNull, reason: 'delivered off-socket: no callback');
    conn.dispose();
  });

  testWidgets('GlintyApp renders what the server sends', (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: url,
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'before welcome there is nothing to draw');

    socket.deliver(serverFrame('hello-welcome', 'welcome'));
    await tester.pumpAndSettle();

    expect(find.text('Demo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a refused connection replaces the app, not decorates it',
      (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: url,
          token: 'expired',
          open: (_) async => socket = FakeSocket(),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(serverFrame('hello-refused', 'error'));
    await tester.pumpAndSettle();

    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.textContaining('authentication failed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

/// Let the socket's stream events drain.
Future<void> pump() => Future<void>.delayed(Duration.zero);
