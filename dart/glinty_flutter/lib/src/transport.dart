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
import 'dart:math' as math;

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
  })  : assert(retryBase <= retryCap,
            'retryBase is where the backoff starts and retryCap is where it stops; '
            'a start past the stop is a configuration nobody meant'),
        _open = open ?? _defaultOpener {
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

  /// Which connection attempt is current. Bumped on every start and
  /// on every close, so a callback belonging to an attempt that has
  /// since been abandoned -- a deadline that fires late, a connect
  /// that finally returns -- can tell that it is stale and stand
  /// down instead of tearing down its successor.
  int _attempt = 0;

  bool _disposed = false;

  /// Open the socket and keep it open. Safe to call once.
  Future<void> start() async {
    if (_disposed) return;
    final attempt = ++_attempt;
    _setState(_retries == 0
        ? GlintyConnectionState.connecting
        : GlintyConnectionState.reconnecting);
    // Armed before the open, not after it. The deadline covers the
    // whole attempt: connecting and being welcomed. Arming it after
    // the await bounded only the half that needs a socket to exist,
    // so a connect that never completes -- a black-holed route, a
    // proxy that accepts and stalls -- never reached the line that
    // arms it. No timer, no close event, no retry, and a retry
    // budget nobody spends is the same infinite spinner this
    // promise exists to rule out.
    _welcomeTimer?.cancel();
    _welcomeTimer = Timer(welcomeTimeout, () {
      if (_disposed || attempt != _attempt) return;
      if (_state == GlintyConnectionState.live) return;
      // silence is a failure, and treating it as one is what
      // makes the retry bound mean anything
      final socket = _socket;
      if (socket != null) unawaited(socket.close().catchError((_) {}));
      _onClosed();
    });
    try {
      final socket = await _open(url);
      // A socket for an attempt that has already failed is trash,
      // not a connection: adopting it would run a second wire under
      // the one the retry path has since made.
      if (_disposed || attempt != _attempt) {
        unawaited(socket.close().catchError((_) {}));
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
    } catch (e) {
      if (_disposed || attempt != _attempt) return;
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

  /// Returns whether this connection took the frame on: sent now, or
  /// queued for the next socket. False means it was dropped, which
  /// the session has to know -- a request recorded against a frame
  /// nobody sent waits forever on an answer the server was never
  /// asked for.
  bool _send(GlintyOutgoing frame) {
    final socket = _socket;
    // hello is the exception: it belongs to the socket being opened,
    // never to the queue, or a reconnect would replay the previous
    // hello ahead of its own.
    if (frame.type == 'hello') {
      if (socket == null) return false;
      try {
        socket.sendText(jsonEncode(frame.body));
      } on WebSocketConnectionClosed {
        // the drop arrives as a close event; the retry path owns it
      }
      return true;
    }
    // Everything else queues until this socket is live. An open
    // socket that has not been welcomed yet is mid-handshake:
    // writing past it would let a new frame overtake the ones
    // already waiting from the last disconnect.
    if (socket == null || _state != GlintyConnectionState.live) {
      return _queue(frame);
    }
    try {
      socket.sendText(jsonEncode(frame.body));
    } on WebSocketConnectionClosed {
      return _queue(frame);
    }
    return true;
  }

  bool _queue(GlintyOutgoing frame) {
    // An input carries state, not an occurrence: the newest value for
    // an id is the whole truth about it, so an older one still
    // waiting is nothing to keep. A slider dragged through a
    // reconnect would otherwise fill this queue with values nobody
    // will ever see, and push out the presses behind them. A measure
    // is the same -- one box reported twice is one box.
    //
    // An event is not. Two presses are two presses, and coalescing
    // them would lose one.
    final id = frame.body['id'];
    if (id != null && (frame.type == 'input' || frame.type == 'measure')) {
      final at = _pending.indexWhere(
          (f) => f.type == frame.type && f.body['id'] == id);
      if (at >= 0) {
        _pending[at] = frame;
        return true;
      }
    }
    if (_pending.length >= _pendingCap) {
      // An input or an event is something the user did. Throwing one
      // away is the failure this queue exists to prevent, so when it
      // has to happen anyway it is counted and said out loud rather
      // than disappearing.
      if (frame.type == 'input' || frame.type == 'event') {
        _dropped += 1;
        if (!_disposed) notifyListeners();
      }
      return false;
    }
    _pending.add(frame);
    return true;
  }

  /// How many of the user's interactions this connection threw away.
  ///
  /// Frames made while the socket was down, after the queue was
  /// already full. Sticky on purpose: a report of lost work must not
  /// vanish the moment the connection returns, because that is
  /// exactly when the user can read it and redo what was lost.
  int get droppedInteractions => _dropped;
  int _dropped = 0;

  /// Acknowledge the report, once it has been shown.
  void clearDroppedInteractions() {
    if (_dropped == 0) return;
    _dropped = 0;
    if (!_disposed) notifyListeners();
  }

  /// Forget the transfer requests still waiting to go out.
  ///
  /// Called wherever the session's ledger is cleared, and for the
  /// same reason: replayed on the next socket these would be answered
  /// with nothing left to answer, and each reply would then be handed
  /// to whoever asked *after* the reconnect. Inputs stay queued --
  /// an interaction the user made once is still theirs -- but a
  /// transfer request whose control has already been told the
  /// connection dropped is not one anybody is still waiting for.
  void _dropQueuedTickets() {
    _pending.removeWhere((frame) => frame.type == 'ticket');
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
          _deliverDownload();
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

  /// Where this app's own assets live: the socket URL as http(s),
  /// with no path.
  ///
  /// A component tree carries relative srcs -- `/static/logo.png` is
  /// served by the same glinty app -- and a renderer has no idea what
  /// they are relative to. The connection does, because it is the
  /// thing holding the address.
  Uri get assetBase => url.replace(
        scheme: url.scheme == 'wss' ? 'https' : 'http',
        path: '',
        query: null,
        fragment: null,
      );

  void _deliverDownload() {
    // The session classified the frame; this reads the verdict rather
    // than the frame. Reading it again here is how a malformed answer
    // carrying both an error and a token became a refusal under the
    // button and a download at the same time.
    //
    // Null covers all three ways of not being a grant to act on: a
    // refusal, an answer with no usable credential, and a grant
    // claimed by nobody -- either a control that has gone away or no
    // request at all.
    final token = session.lastTicketGrant;
    if (token == null) {
      debugPrint('glinty: a download ticket arrived that no control is '
          'waiting for - ignoring it');
      return;
    }
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
    //
    // The attempt is bumped for the same reason the timer is
    // cancelled: this attempt is over, and anything of its still in
    // flight is answering for a connection that no longer exists.
    _attempt += 1;
    _welcomeTimer?.cancel();
    _welcomeTimer = null;
    _events?.cancel();
    _events = null;
    _socket = null;
    // Every transfer request this socket carried died with it. A
    // control still waiting would wait forever, disabled, with no
    // sign of why -- so it is told, and can be pressed again once
    // the retry lands.
    session.failPendingTickets('the connection dropped');
    _dropQueuedTickets();
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
    // min(), not clamp(): the backoff starts at base and doubles up
    // to the cap, and a cap below the base is still a cap. clamp()
    // reads its bounds as low-then-high and threw an ArgumentError
    // when they crossed -- at the first disconnect, from inside the
    // retry path, on a connection that was configured wrong an hour
    // earlier.
    final delay = Duration(
        milliseconds: math.min(retryBase.inMilliseconds * (1 << _retries),
            retryCap.inMilliseconds));
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
    _attempt += 1;
    _welcomeTimer?.cancel();
    _welcomeTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    // And the wire itself. Terminal means done, not "done deciding":
    // a refusal arrives on an open socket, and leaving it open
    // leaves its subscription live, so frames keep landing in a
    // session that has been refused and the app cannot let go of a
    // connection it has already given up on.
    _events?.cancel();
    _events = null;
    unawaited(_socket?.close().catchError((_) {}));
    _socket = null;
    _pending.clear();
    // A refusal arrives on a socket that is still open, so this is
    // not always reached through _onClosed. Terminal means no answer
    // is coming, for transfers as much as for anything else.
    session.failPendingTickets(reason ?? 'the connection ended');
    _dropQueuedTickets();
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
    // Nothing here will ever answer again. A control that outlives
    // this connection -- one being torn down in some other order --
    // gets told rather than left waiting on a dead wire.
    session.failPendingTickets('the connection ended');
    _dropQueuedTickets();
    _retryTimer?.cancel();
    _welcomeTimer?.cancel();
    _events?.cancel();
    unawaited(_socket?.close().catchError((_) {}));
    _socket = null;
    super.dispose();
  }
}
