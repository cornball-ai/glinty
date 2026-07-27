/// The socket, and the reconnect policy around it.
///
/// [GlintySession] knows the conversation; this knows how to hold a
/// wire open under one. It sends hello, routes frames into the
/// session, notifies listeners so widgets rebuild, and reconnects
/// with backoff -- carrying `resume` so a dropped connection picks up
/// the session it left rather than starting a new one.
///
/// Two rules it exists to keep, both about not lying to the user:
/// a refused connection stops trying (the server has said no and will
/// keep saying no), and a connection that has given up says so rather
/// than sitting on a spinner forever.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket/web_socket.dart';

import 'session.dart';

/// Opens a socket to [url]. Injectable so tests drive the client
/// without a server, and so an embedder can wrap the socket.
typedef GlintySocketOpener = Future<WebSocket> Function(Uri url);

Future<WebSocket> _defaultOpener(Uri url) => WebSocket.connect(url);

/// Where a connection is in its lifecycle, for widgets to draw.
enum GlintyConnectionState {
  /// Opening a socket, or waiting to retry.
  connecting,

  /// Socket open, welcome received, app usable.
  live,

  /// Socket dropped; a retry is scheduled.
  reconnecting,

  /// The server refused us, or retries ran out. Terminal.
  stopped,
}

/// A live glinty connection: session state plus the wire under it.
///
/// A [ChangeNotifier], so `ListenableBuilder` (or [GlintyApp])
/// rebuilds when a frame lands.
class GlintyConnection extends ChangeNotifier {
  GlintyConnection({
    required this.url,
    this.token,
    this.client = 'glinty_flutter/0.0.1',
    this.maxRetries = 12,
    this.retryBase = const Duration(milliseconds: 500),
    this.retryCap = const Duration(seconds: 5),
    this.welcomeTimeout = const Duration(seconds: 15),
    GlintySocketOpener? open,
    this.onDownload,
    this.onLink,
  }) : _open = open ?? _defaultOpener {
    session = GlintySession(
      client: client,
      token: token,
      onSend: _send,
      // Declared only when wired: a feature named in hello that the
      // embedder never supplied is a claim the server would believe.
      features: [if (onDownload != null) 'download'],
      // A local edit changes what the controls draw; without this
      // the store updates and the UI never hears until some later
      // server frame happens to arrive.
      onChanged: notifyListeners,
    );
  }

  /// The ws:// or wss:// endpoint. Apple's ATS makes wss the only
  /// option for a shipped iOS app; see PROTOCOL.md on terminating
  /// TLS at a reverse proxy.
  final Uri url;

  /// Opaque auth token for hello, or null.
  final String? token;

  final String client;
  final int maxRetries;
  final Duration retryBase;
  final Duration retryCap;

  /// How long a socket may stay open without answering hello. A
  /// server that accepts the connection and then says nothing is
  /// indistinguishable from a working one, so the bounded-retry
  /// promise needs this to be true: without it the app sits on a
  /// spinner forever and no retry budget is ever spent.
  final Duration welcomeTimeout;
  final GlintySocketOpener _open;

  /// Called with a resolved download URL when a `download_button` is
  /// pressed and the server grants a ticket. Saving or opening it is
  /// platform work this package deliberately leaves to the embedder;
  /// without a callback the grant is logged and dropped.
  void Function(Uri url)? onDownload;

  /// Called when a link is tapped. Opening a URL needs a platform
  /// plugin, so the embedder decides; without one, links render as
  /// styled text and are not tappable.
  void Function(String href, {bool external})? onLink;

  late final GlintySession session;

  GlintyConnectionState get state => _state;
  GlintyConnectionState _state = GlintyConnectionState.connecting;

  /// Why the connection stopped, when it did.
  String? get stoppedReason => _stoppedReason;
  String? _stoppedReason;

  WebSocket? _socket;
  StreamSubscription<WebSocketEvent>? _events;
  Timer? _retryTimer;
  Timer? _welcomeTimer;
  int _retries = 0;
  bool _disposed = false;

  /// Open the socket and keep it open. Safe to call once.
  Future<void> start() async {
    if (_disposed) return;
    _setState(_retries == 0
        ? GlintyConnectionState.connecting
        : GlintyConnectionState.reconnecting);
    try {
      final socket = await _open(url);
      if (_disposed) {
        unawaited(socket.close());
        return;
      }
      _socket = socket;
      _events = socket.events.listen(_onEvent, onDone: _onClosed);
      // hello goes out on this socket; the session stamps `resume`
      // when it already has a session id. The state stays
      // connecting until welcome answers -- an open socket is not a
      // usable app, and saying otherwise would let the UI draw
      // before it has a tree.
      session.hello();
      _welcomeTimer?.cancel();
      _welcomeTimer = Timer(welcomeTimeout, () {
        if (_disposed || _state == GlintyConnectionState.live) return;
        // silence is a failure, and treating it as one is what
        // makes the retry bound mean anything
        unawaited(socket.close().catchError((_) {}));
        _onClosed();
      });
    } catch (e) {
      _onClosed();
    }
  }

  /// Frames written while no socket is up, flushed on welcome.
  ///
  /// An interaction made during a reconnect is a real interaction:
  /// dropping it silently is the failure this queue exists to stop.
  /// Capped, because a user tapping at a dead app should not grow
  /// memory without limit.
  final List<GlintyOutgoing> _pending = [];
  static const _pendingCap = 64;

  void _send(GlintyOutgoing frame) {
    final socket = _socket;
    // hello is the exception: it belongs to the socket being opened,
    // never to the queue, or a reconnect would replay the previous
    // hello ahead of its own.
    if (frame.type == 'hello') {
      if (socket == null) return;
      try {
        socket.sendText(jsonEncode(frame.body));
      } on WebSocketConnectionClosed {
        // the drop arrives as a close event; the retry path owns it
      }
      return;
    }
    // Everything else queues until this socket is live. An open
    // socket that has not been welcomed yet is mid-handshake:
    // writing past it would let a new frame overtake the ones
    // already waiting from the last disconnect.
    if (socket == null || _state != GlintyConnectionState.live) {
      _queue(frame);
      return;
    }
    try {
      socket.sendText(jsonEncode(frame.body));
    } on WebSocketConnectionClosed {
      _queue(frame);
    }
  }

  void _queue(GlintyOutgoing frame) {
    if (_pending.length < _pendingCap) _pending.add(frame);
  }

  void _flushPending() {
    final socket = _socket;
    if (socket == null || _pending.isEmpty) return;
    final queued = List<GlintyOutgoing>.from(_pending);
    _pending.clear();
    for (final frame in queued) {
      try {
        socket.sendText(jsonEncode(frame.body));
      } on WebSocketConnectionClosed {
        _pending.add(frame);
      }
    }
  }

  void _onEvent(WebSocketEvent event) {
    switch (event) {
      case TextDataReceived(:final text):
        final decoded = jsonDecode(text);
        if (decoded is! Map) return;
        final msg = decoded.cast<String, dynamic>();
        final refusedResume = msg['type'] == 'welcome' &&
            msg['resumed'] == false;
        session.receive(msg);
        if (msg['type'] == 'welcome' && !session.refused) {
          _welcomeTimer?.cancel();
          _welcomeTimer = null;
          if (refusedResume) {
            // The session those frames belonged to is gone. Replaying
            // them into a fresh session would apply one user's
            // interactions to another's state -- the same reason the
            // session clears its values here.
            _pending.clear();
          }
          // The app is usable now, not when the socket opened. A
          // welcome is also proof this endpoint works, so the retry
          // budget resets -- otherwise a long-lived app that drops
          // once a day exhausts it and stops for good.
          _retries = 0;
          _setState(GlintyConnectionState.live);
          _flushPending();
        }
        if (msg['type'] == 'ticket' && msg['purpose'] == 'download') {
          _deliverDownload(msg);
        }
        if (session.refused) {
          _stop(session.refusalMessage ?? session.error?.message);
        }
        notifyListeners();
      case BinaryDataReceived():
        // v3 is a text protocol; a binary frame is not ours.
        break;
      case CloseReceived():
        _onClosed();
    }
  }

  void _deliverDownload(Map<String, dynamic> msg) {
    final token = msg['token'];
    if (token is! String) return;
    final target = url.replace(
      scheme: url.scheme == 'wss' ? 'https' : 'http',
      path: '/download',
      queryParameters: {'ticket': token},
    );
    final cb = onDownload;
    if (cb == null) {
      debugPrint('glinty: download ready at $target, but no onDownload '
          'callback was given');
      return;
    }
    cb(target);
  }

  void _onClosed() {
    // This socket's welcome is never coming. Leaving its timer armed
    // lets it fire during the *replacement* handshake and tear that
    // one down instead -- a disconnect before welcome would keep
    // killing every socket after it.
    _welcomeTimer?.cancel();
    _welcomeTimer = null;
    _events?.cancel();
    _events = null;
    _socket = null;
    if (_disposed || _state == GlintyConnectionState.stopped) return;
    if (session.refused) {
      // The server said no. It will say no again; retrying would
      // hide a refusal the user needs to see.
      _stop(session.refusalMessage ?? session.error?.message);
      return;
    }
    if (_retries >= maxRetries) {
      _stop('lost connection to the server');
      return;
    }
    final delay = Duration(
        milliseconds:
            (retryBase.inMilliseconds * (1 << _retries)).clamp(
                retryBase.inMilliseconds, retryCap.inMilliseconds));
    _retries += 1;
    _setState(GlintyConnectionState.reconnecting);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, start);
  }

  void _stop(String? reason) {
    // Nothing is coming, so nothing is still owed a timeout: a
    // refusal arrives with the socket still open, and leaving the
    // welcome timer armed would fire a retry into a connection that
    // has already been told no.
    _welcomeTimer?.cancel();
    _welcomeTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pending.clear();
    _stoppedReason = reason;
    _setState(GlintyConnectionState.stopped);
  }

  void _setState(GlintyConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _welcomeTimer?.cancel();
    _events?.cancel();
    unawaited(_socket?.close().catchError((_) {}));
    _socket = null;
    super.dispose();
  }
}
