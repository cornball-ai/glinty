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
    GlintySocketOpener? open,
    this.onDownload,
  }) : _open = open ?? _defaultOpener {
    session = GlintySession(client: client, token: token, onSend: _send);
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
  final GlintySocketOpener _open;

  /// Called with a resolved download URL when a `download_button` is
  /// pressed and the server grants a ticket. Saving or opening it is
  /// platform work this package deliberately leaves to the embedder;
  /// without a callback the grant is logged and dropped.
  final void Function(Uri url)? onDownload;

  late final GlintySession session;

  GlintyConnectionState get state => _state;
  GlintyConnectionState _state = GlintyConnectionState.connecting;

  /// Why the connection stopped, when it did.
  String? get stoppedReason => _stoppedReason;
  String? _stoppedReason;

  WebSocket? _socket;
  StreamSubscription<WebSocketEvent>? _events;
  Timer? _retryTimer;
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
      // when it already has a session id.
      session.hello();
      _setState(GlintyConnectionState.live);
    } catch (e) {
      _onClosed();
    }
  }

  void _send(GlintyOutgoing frame) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.sendText(jsonEncode(frame.body));
    } on WebSocketConnectionClosed {
      // The drop will arrive as a close event; the retry path owns
      // it. Losing this frame is correct -- resending it after a
      // resume would replay an interaction the user made once.
    }
  }

  void _onEvent(WebSocketEvent event) {
    switch (event) {
      case TextDataReceived(:final text):
        final decoded = jsonDecode(text);
        if (decoded is! Map) return;
        final msg = decoded.cast<String, dynamic>();
        session.receive(msg);
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
    _events?.cancel();
    unawaited(_socket?.close().catchError((_) {}));
    _socket = null;
    super.dispose();
  }
}
