/// The conversation, as distinct from the tree.
///
/// [GlintyRenderer] turns a component into widgets. This turns a
/// stream of protocol frames into the state the renderer draws from:
/// which tree is current, which outputs have values, and whether the
/// server is speaking a protocol this client understands at all.
///
/// It owns the hydration rules from PROTOCOL.md, which exist because
/// every one of their failure modes is silent:
///
///  1. one interaction produces one frame, across rebuilds
///  2. adopting a tree emits nothing -- the server built it and
///     already knows every default
///  3. a revision mismatch replaces the cached tree instead of
///     patching it
///  4. a protocol mismatch refuses visibly
library;

import 'component.dart';
import 'render.dart' show supportedComponents;

/// The protocol version this client speaks.
const glintyProtocolVersion = 3;

/// A frame the client sends. Named rather than a bare map so tests can
/// count what left, which is the only way to assert invariant 2.
class GlintyOutgoing {
  const GlintyOutgoing(this.type, this.body);
  final String type;
  final Map<String, dynamic> body;

  @override
  String toString() => 'GlintyOutgoing($type, $body)';
}

/// Why the client refused to render.
///
/// Carried rather than thrown: a refusal the user cannot see is the
/// failure mode this exists to prevent.
class GlintyProtocolError {
  const GlintyProtocolError(this.expected, this.received);
  final int expected;
  final int received;

  String get message =>
      received > expected
          ? 'This app speaks glinty protocol $expected, but the server '
              'sent protocol $received. Update the app.'
          : 'This app speaks glinty protocol $expected, but the server '
              'sent protocol $received. Update the server.';
}

/// How the current tree arrived.
enum GlintyTreeSource {
  /// Nothing rendered yet.
  none,

  /// The cached tree matched `ui_revision` and was kept.
  adopted,

  /// The tree came from `welcome`, replacing anything cached.
  rebuilt,
}

class GlintySession {
  GlintySession({
    this.client = 'glinty_flutter/0.0.1',
    this.token,
    GlintyComponent? cachedUi,
    String? cachedRevision,
    void Function(GlintyOutgoing)? onSend,
  })  : _ui = cachedUi,
        _cachedRevision = cachedRevision,
        _onSend = onSend;

  final String client;

  /// Opaque auth token for hello, or null. glinty never parses it:
  /// the server's run_app(auth = ) verifier does, and a refused token
  /// gets one error frame and a closed socket.
  final String? token;

  final void Function(GlintyOutgoing)? _onSend;

  GlintyComponent? _ui;
  String? _cachedRevision;

  String? sessionId;
  String? uiRevision;

  /// Theme tokens from welcome, or null when the app set none (each
  /// frontend's defaults apply then).
  Map<String, dynamic>? theme;

  GlintyProtocolError? error;

  /// The server's reason for refusing this connection (an id-less
  /// error before any welcome -- authentication, most likely), or
  /// null. A refusal nobody sees is the failure mode the
  /// visible-refusal rule exists to prevent, so [GlintyView] draws
  /// it the way it draws a protocol mismatch.
  String? refusalMessage;

  GlintyTreeSource source = GlintyTreeSource.none;

  /// True from the moment hello goes out until that socket's welcome
  /// arrives. An id-less error inside that window refuses this
  /// connection -- including on a reconnect, where a token that
  /// worked before has since expired. Keyed to the exchange, not to
  /// "have we ever connected", or a reconnect refusal reads as an
  /// ordinary error and the client retries forever.
  bool _awaitingWelcome = false;

  /// Every frame this client has sent, in order. The record is the
  /// point: invariant 2 is "this list did not grow", and invariant 1
  /// is "it grew by exactly one".
  final List<GlintyOutgoing> sent = <GlintyOutgoing>[];

  /// Latest value per output id, for the renderer to draw.
  final Map<String, dynamic> values = <String, dynamic>{};

  /// Latest ticket grant per "purpose:id", from `ticket` frames. A
  /// transport layer consumes these to build transfer URLs; the
  /// session only holds them.
  final Map<String, Map<String, dynamic>> tickets =
      <String, Map<String, dynamic>>{};

  /// The tree to render, or null when there is nothing to draw yet.
  GlintyComponent? get ui => refused ? null : _ui;

  /// True once the server has spoken a protocol we cannot read.
  bool get refused => error != null || refusalMessage != null;

  /// The opening frame: what this client can draw.
  ///
  /// A declaration, not a negotiation. The server sends the whole tree
  /// regardless; this only lets it log what will come out as a
  /// placeholder.
  GlintyOutgoing hello() {
    final frame = GlintyOutgoing('hello', {
      'type': 'hello',
      'protocol': glintyProtocolVersion,
      'client': client,
      'components': supportedComponentsList,
      // The output kinds this client can draw. `image`, `audio` and
      // `ui` are absent because the components that carry them are,
      // and a kind declared without a slot to put it in is a lie.
      'kinds': const ['text', 'table'],
      'features': const <String>[],
      if (token != null) 'token': token,
      // resume and prerendered are alternatives, not companions: a
      // reconnect asks for its session back, a fresh connect says
      // what markup it already holds. Sending both would ask the
      // server to answer two different questions at once.
      if (sessionId != null)
        'resume': sessionId
      else if (_cachedRevision != null)
        'prerendered': _cachedRevision,
    });
    _awaitingWelcome = true;
    _emit(frame);
    return frame;
  }

  /// Handle one server frame.
  void receive(Map<String, dynamic> msg) {
    if (refused) return; // nothing after a refusal is meaningful
    switch (msg['type']) {
      case 'welcome':
        _welcome(msg);
      case 'output':
        final id = msg['id'];
        if (id is String) values[id] = msg['value'];
      case 'ticket':
        final id = msg['id'];
        final purpose = msg['purpose'];
        if (id is String && purpose is String) {
          tickets['$purpose:$id'] = msg;
        }
      case 'error':
        final id = msg['id'];
        if (id is String) {
          values[id] = null;
        } else if (_awaitingWelcome) {
          // a refused connection: the server says why once and
          // closes; nothing after it is meaningful
          refusalMessage =
              msg['message']?.toString() ?? 'connection refused';
        }
      default:
        // Unknown message types are ignored on purpose: the protocol
        // grows by adding them, and a client that throws here cannot
        // talk to a server one release newer within the same version.
        break;
    }
  }

  void _welcome(Map<String, dynamic> msg) {
    _awaitingWelcome = false;
    final protocol = msg['protocol'];
    if (protocol is! int || protocol != glintyProtocolVersion) {
      // Invariant 4. Refuse before touching `ui`, so a mismatched
      // server cannot get a half-rendered tree on screen.
      error = GlintyProtocolError(
        glintyProtocolVersion,
        protocol is int ? protocol : -1,
      );
      return;
    }

    sessionId = msg['session']?.toString();
    theme = msg['theme'] is Map
        ? (msg['theme'] as Map).cast<String, dynamic>()
        : null;
    final revision = msg['ui_revision']?.toString();
    uiRevision = revision;

    if (_ui != null && revision != null && revision == _cachedRevision) {
      // Invariant 3, the matching half: the cached tree is the tree
      // being sent, so keep it and hold on to any widget state.
      source = GlintyTreeSource.adopted;
    } else {
      // Invariant 3, the mismatching half: whatever we cached
      // describes a different tree. Replace it. Patching a stale tree
      // is how a hydration bug becomes a data bug.
      _ui = msg['ui'] == null ? null : GlintyComponent.fromJson(msg['ui']);
      _cachedRevision = revision;
      source = GlintyTreeSource.rebuilt;
    }
    // Invariant 2: nothing is emitted here. Adoption is not user
    // interaction, and the server built this tree, so it already knows
    // every default. Protocol 2 harvested inputs at init; sending them
    // back would write the whole form on every reconnect.
  }

  /// Report an input's new value. Called by the renderer, never by
  /// [receive].
  void sendInput(String id, dynamic value) {
    _emit(GlintyOutgoing('input', {'type': 'input', 'id': id, 'value': value}));
  }

  /// Report a discrete event, such as a button press.
  void sendEvent(String id) {
    _emit(GlintyOutgoing('event', {'type': 'event', 'id': id}));
  }

  /// Ask for a transfer ticket. The grant arrives as a `ticket`
  /// frame and lands in [tickets] under "purpose:id".
  void requestTicket(String id, String purpose) {
    _emit(GlintyOutgoing(
        'ticket', {'type': 'ticket', 'id': id, 'purpose': purpose}));
  }

  /// Report an output's box so the server can render at that size.
  ///
  /// Width and height are logical pixels -- Flutter's native unit, so
  /// no conversion happens here, which is the point of the protocol
  /// choosing it. [dpr] is `MediaQuery.devicePixelRatio`: the server
  /// rasterizes at width x dpr by height x dpr and the image comes
  /// back sized in logical pixels.
  ///
  /// Callers deduplicate per id: send only when (width, height, dpr)
  /// changed, and never for a box that cannot be seen -- the server
  /// keeps the last real measurement across rebuilds.
  void sendMeasure(String id, int width, int height, {num dpr = 1}) {
    _emit(GlintyOutgoing('measure', {
      'type': 'measure',
      'id': id,
      'width': width,
      'height': height,
      'dpr': dpr,
    }));
  }

  void _emit(GlintyOutgoing frame) {
    sent.add(frame);
    _onSend?.call(frame);
  }
}

/// The components this client draws, as a sorted list for `hello`.
///
/// Sorted so the frame is stable across runs; a set's iteration order
/// is not something to make a wire format depend on.
final List<String> supportedComponentsList =
    (supportedComponents.toList()..sort());
