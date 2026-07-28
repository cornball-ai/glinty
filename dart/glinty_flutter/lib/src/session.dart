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

import 'dart:async';
import 'component.dart';
import 'inputs.dart';
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
    this.features = const <String>[],
    GlintyComponent? cachedUi,
    String? cachedRevision,
    bool Function(GlintyOutgoing)? onSend,
    void Function()? onChanged,
  })  : _ui = cachedUi,
        _cachedRevision = cachedRevision,
        _onSend = onSend,
        _onChanged = onChanged;

  final String client;

  /// Optional protocol features this client actually supports,
  /// declared in hello. Empty unless an embedder wired them: a
  /// feature named here that nothing implements is a claim the
  /// server would believe.
  final List<String> features;

  /// Opaque auth token for hello, or null. glinty never parses it:
  /// the server's run_app(auth = ) verifier does, and a refused token
  /// gets one error frame and a closed socket.
  final String? token;

  /// Hands a frame to the wire. Returns whether the transport took
  /// responsibility for it -- sent now, or queued to send on the next
  /// connection. False means it was dropped and will never go out,
  /// which a request that recorded itself before emitting has to hear
  /// about: an entry in the ledger for a frame nobody sent waits on an
  /// answer the server was never asked for.
  final bool Function(GlintyOutgoing)? _onSend;

  /// Fires whenever session state changes, including from a local
  /// edit. Without it a checkbox updates the store and the UI never
  /// hears -- the control would only redraw when some later server
  /// frame happened to arrive.
  final void Function()? _onChanged;

  void _changed() => _onChanged?.call();

  /// Announce a state change made from outside receive(): dismissing
  /// a dialog locally, for one. Without it the store updates and
  /// nothing redraws until some later server frame happens to land.
  void notifyChanged() => _changed();

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

  /// The kind of each output value, from the `output` frame. What
  /// a value IS, so a renderer can refuse one it cannot draw by
  /// name instead of stringifying it.
  final Map<String, String> kinds = <String, String>{};

  /// Render errors per output id: the server said why, so the slot
  /// shows that rather than going blank.
  final Map<String, String> errors = <String, String>{};

  /// Current value per input id: the state a control draws from.
  /// Seeded from the tree on welcome, then owned by user edits and
  /// `input_update` frames. The component tree is the shape of the
  /// UI; this is its state.
  final Map<String, dynamic> inputs = <String, dynamic>{};

  /// Server-pushed field changes per input id (label, choices,
  /// min, max, step). The tree still describes the control as the
  /// server first built it; these are what changed since.
  final Map<String, Map<String, dynamic>> overrides =
      <String, Map<String, dynamic>>{};

  /// How many value pushes each input has received.
  ///
  /// A push is an event, not a state, and a stateful control needs to
  /// tell one from the next. Counting them is the only way: a control
  /// that instead remembers "the last value I was pushed" cannot see
  /// a second push of the same value, so a push refused because the
  /// field had focus makes an identical later push a no-op -- the
  /// server said it twice and the user saw it never.
  final Map<String, int> pushes = <String, int>{};

  /// Bumped whenever the tree is replaced or the state is cleared.
  /// Widgets key off it so Flutter discards controllers and element
  /// state belonging to a tree that no longer exists.
  int generation = 0;

  /// Latest ticket grant per "purpose:id", from `ticket` frames. A
  /// transport layer consumes these to build transfer URLs; the
  /// session only holds them.
  final Map<String, Map<String, dynamic>> tickets =
      <String, Map<String, dynamic>>{};

  /// Requests sent and not yet answered, in the order they went out,
  /// per "purpose:id".
  ///
  /// One ledger, not a queue of waiters beside a count of requests.
  /// Two orderings cannot be kept in step: a direct [requestTicket]
  /// followed by a button's would put the direct one first on the
  /// wire and the button first in the queue, so the button was handed
  /// an answer to a question it never asked. Every way of asking
  /// appends here, and the front of the list is whose answer this is.
  ///
  /// A list rather than one slot per id, because several controls may
  /// carry the same id -- that is the whole reason a button's id is
  /// routing rather than identity. Keyed against the *request*, not
  /// the id, or a refusal earned by one download button would appear
  /// under every button sharing its name.
  final Map<String, List<_TicketRequest>> _ticketRequests =
      <String, List<_TicketRequest>>{};

  /// True when the last ticket frame answered nobody.
  ///
  /// A grant belonging to a button that no longer exists, or to no
  /// request at all, is not a grant for anybody: the transport reads
  /// this so it does not hand an embedder a download URL that arrives
  /// out of nowhere with nothing on screen to explain it.
  bool lastTicketUnclaimed = false;

  /// The credential from the last ticket frame, when that frame was a
  /// grant and a live request claimed it. Null for anything else.
  ///
  /// The frame is classified once, here, and the transport reads the
  /// verdict rather than looking at the frame again. Two readings of
  /// one frame can disagree: a malformed answer carrying both an
  /// error and a token was a refusal to the control that asked and a
  /// download to the transport, so one press did both.
  String? lastTicketGrant;

  /// Ask for a ticket and register a control's interest in the
  /// answer. Returns a function that cancels it, for a control that
  /// goes away before the answer arrives.
  ///
  /// Asking and registering are one step on purpose. Split apart they
  /// are two orderings that have to be kept in step, and a caller who
  /// did one without the other put the ledger out of line with the
  /// wire.
  ///
  /// Cancelling leaves a tombstone rather than removing the entry.
  /// The ledger's positions correspond to requests already on the
  /// wire, and the server will answer every one of them; dropping an
  /// entry shortens the ledger but not the stream, so the next control
  /// in line would be handed the departed one's answer. A tombstone
  /// consumes its own reply and throws it away.
  void Function() awaitTicket(
      String id, String purpose, void Function(String? refusal) answer) {
    final request = _askForTicket(id, purpose, answer);
    return () => request.answer = null;
  }

  _TicketRequest _askForTicket(
      String id, String purpose, void Function(String? refusal) answer) {
    final key = '$purpose:$id';
    final request = _TicketRequest(answer);
    final queue = _ticketRequests[key] ??= <_TicketRequest>[];
    queue.add(request);
    // Recorded first, because a frame the transport sends now can be
    // answered before this returns. If the wire would not take it,
    // the entry comes straight back out -- nothing is behind it yet,
    // so removing it shifts nobody, and a request that never went out
    // will never be answered.
    if (!_emit(GlintyOutgoing(
        'ticket', {'type': 'ticket', 'id': id, 'purpose': purpose}))) {
      queue.remove(request);
      final tell = request.answer;
      request.answer = null;
      tell?.call('the app is too far behind to ask for that right now');
    }
    return request;
  }

  void _answerTicket(String purpose, String id, String? refusal) {
    final queue = _ticketRequests['$purpose:$id'];
    if (queue == null || queue.isEmpty) {
      // Nothing asked for this. The server is volunteering a transfer
      // nobody requested, which is nobody's to act on -- and which
      // the browser drops on the floor for the same reason.
      lastTicketUnclaimed = true;
      return;
    }
    // Popped whether or not anyone is still listening: this answer
    // belongs to that request, and leaving it would shift every
    // later answer onto the wrong control.
    final answer = queue.removeAt(0).answer;
    lastTicketUnclaimed = answer == null;
    answer?.call(refusal);
  }

  /// Hand every waiting control a refusal.
  ///
  /// The socket that was going to answer is gone. A request left in
  /// the ledger keeps its control disabled forever, and the next
  /// socket's first reply would go to it rather than to whoever asked
  /// after the reconnect.
  void failPendingTickets(String reason) {
    final queues = _ticketRequests.values.toList();
    _ticketRequests.clear();
    var told = false;
    for (final q in queues) {
      for (final request in List.of(q)) {
        // A tombstone has nobody to tell: its control is gone, and
        // the request it stood for is gone with the socket.
        final answer = request.answer;
        if (answer == null) continue;
        request.answer = null;
        told = true;
        answer(reason);
      }
    }
    if (told) _changed();
  }

  /// The open dialog's frame, or null. One at a time, because
  /// show_modal() replaces rather than stacks.
  Map<String, dynamic>? modal;

  /// Active progress reports by id, in the order they were opened.
  /// A `hide` removes one; the rest keep going, which is what makes
  /// nested with_progress() calls readable.
  final Map<String, Map<String, dynamic>> progress =
      <String, Map<String, dynamic>>{};

  /// Handlers for `custom` frames, by name. The embedder registers
  /// these -- glinty has no idea what an app's custom message means,
  /// which is the whole point of the channel.
  final Map<String, void Function(dynamic value)> customHandlers =
      <String, void Function(dynamic value)>{};

  /// Custom handler names the server sent that nothing was listening
  /// for. Recorded rather than dropped: a message with nowhere to go
  /// is a gap in the app, and the rule this client keeps is that a
  /// gap is visible.
  final Set<String> unhandledCustom = <String>{};

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
      // The output kinds this client can draw. `audio`, `ui` and
      // `html` are absent because the components that carry them are,
      // and a kind declared without a slot to put it in is a lie.
      'kinds': const ['text', 'table', 'image'],
      // measure, modal and progress are this client's own: it reports
      // output boxes, draws dialogs and draws progress reports. The
      // rest come from the embedder, because they need one -- there
      // is no way to save a downloaded file from inside this package.
      'features': ['measure', 'modal', 'progress', ...features],
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
        if (id is String) {
          values[id] = msg['value'];
          // The kind says what the value IS. Dropping it left a slot
          // stringifying whatever arrived: an image value rendered
          // as "{src: data:image/png;base64,iVBOR..." rather than as
          // a visible "this client cannot draw images".
          final kind = msg['kind'];
          if (kind is String) {
            kinds[id] = kind;
          } else {
            kinds.remove(id);
          }
          errors.remove(id);
        }
      case 'ticket':
        final id = msg['id'];
        final purpose = msg['purpose'];
        // Cleared for every ticket frame, including one too malformed
        // to route: a verdict left over from the last frame would let
        // an unroutable one open the previous grant all over again.
        lastTicketGrant = null;
        lastTicketUnclaimed = true;
        if (id is String && purpose is String) {
          // A refusal answers the request that asked, so it goes to
          // the waiter that asked. Sent as an `error` frame it was
          // invisible here entirely: this client stores those against
          // output ids, and a download_button is not an output.
          //
          // An answer with neither a credential nor a reason is
          // malformed, and is a refusal rather than a grant: the
          // request is over either way and the control has to come
          // back. Passed on as a grant it reached the transport,
          // which found no token and dropped it silently.
          final refusal = msg['error'];
          final token = msg['token'];
          if (refusal != null || token is! String || token.isEmpty) {
            tickets.remove('$purpose:$id');
            _answerTicket(
                purpose,
                id,
                refusal?.toString() ??
                    'the server answered without a ticket');
          } else {
            tickets['$purpose:$id'] = msg;
            _answerTicket(purpose, id, null);
            // A grant, but only the claimed one is anybody's to use.
            if (!lastTicketUnclaimed) lastTicketGrant = token;
          }
        }
      case 'input_update':
        // A server-driven change is a value change like any other,
        // so the store (and any conditional panel keyed on it) must
        // see it. Deliberately no echo back: the server already
        // synced its own copy, and answering would be a second write.
        final id = msg['id'];
        if (id is String) {
          if (msg.containsKey('selected')) {
            inputs[id] = msg['selected'];
            pushes[id] = (pushes[id] ?? 0) + 1;
          } else if (msg.containsKey('value')) {
            inputs[id] = msg['value'];
            pushes[id] = (pushes[id] ?? 0) + 1;
          }
          // The rest of the update -- label, choices, bounds, step --
          // is not in the tree either: update_select_input() changes
          // the choices of a control the tree still describes with
          // the old ones. Held as overrides the renderer prefers, or
          // a repopulated dropdown shows yesterday's options until
          // the next welcome.
          for (final field in const ['label', 'choices', 'min', 'max',
            'step']) {
            if (msg.containsKey(field)) {
              (overrides[id] ??= <String, dynamic>{})[field] = msg[field];
            }
          }
        }
      case 'error':
        final id = msg['id'];
        if (id is String) {
          // A render error is something to show, not a blank slot:
          // the server said why, and an app that goes quiet instead
          // is the silent failure this protocol keeps refusing.
          values[id] = null;
          kinds.remove(id);
          errors[id] = msg['message']?.toString() ?? 'error';
        } else if (_awaitingWelcome) {
          // a refused connection: the server says why once and
          // closes; nothing after it is meaningful
          refusalMessage =
              msg['message']?.toString() ?? 'connection refused';
        }
      case 'modal':
        // A dialog is a component tree with a title and a footer, so
        // this client can draw it with the renderer it already has --
        // which is the point of the tree being components rather than
        // markup. Ignoring the frame left show_modal() a no-op here:
        // an app asking a question and getting no answer, forever.
        if (msg['action'] == 'hide') {
          modal = null;
        } else {
          modal = msg;
        }
      case 'progress':
        final id = msg['id'];
        if (id is String) {
          if (msg['action'] == 'hide') {
            progress.remove(id);
          } else {
            progress[id] = msg;
          }
        }
      case 'custom':
        // The one frame whose meaning lives outside glinty: the
        // payload is the app's, and only the embedder knows what it
        // means. Held so a view can say a handler was never wired,
        // rather than dropping the message where nobody can see it.
        final handler = msg['handler'];
        if (handler is String) {
          final fn = customHandlers[handler];
          if (fn != null) {
            fn(msg['value']);
          } else {
            unhandledCustom.add(handler);
          }
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

    if (msg['resumed'] == false) {
      // We asked to resume and the server said no: the session we
      // held is gone. Every value in this client describes it, so
      // every value goes. Keeping them would draw one session's
      // state over another's -- the browser reloads the page for
      // exactly this reason.
      values.clear();
      inputs.clear();
      tickets.clear();
      overrides.clear();
      kinds.clear();
      errors.clear();
      pushes.clear();
      modal = null;
      progress.clear();
      unhandledCustom.clear();
      failPendingTickets("that session is gone");
      // The new session has never been told a box. Keeping the old
      // dedup keys would leave every plot unmeasured until something
      // happened to resize it.
      _measured.clear();
      _ui = null;
      _cachedRevision = null;
      generation++;
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
      // Adopting a tree still needs its state. A client handed a
      // cached tree it never seeded has empty inputs, so every
      // conditional panel reads "unset matches nothing" and starts
      // hidden -- the one case where adoption would disagree with
      // the server about what is on screen. Only fills what is
      // missing: an edit already made is not undone by adopting.
      seedInputs(_ui).forEach((id, v) => inputs.putIfAbsent(id, () => v));
    } else {
      // Invariant 3, the mismatching half: whatever we cached
      // describes a different tree. Replace it. Patching a stale tree
      // is how a hydration bug becomes a data bug.
      _ui = msg['ui'] == null ? null : GlintyComponent.fromJson(msg['ui']);
      _cachedRevision = revision;
      source = GlintyTreeSource.rebuilt;
      generation++;
      // Seed the input store from the tree, the way the server seeds
      // its own from the same tree (R/seed.R). Without this a
      // control reads its value out of the component every rebuild
      // and can never change.
      inputs
        ..clear()
        ..addAll(seedInputs(_ui));
    }
    // Invariant 2: nothing is emitted here. Adoption is not user
    // interaction, and the server built this tree, so it already knows
    // every default. Protocol 2 harvested inputs at init; sending them
    // back would write the whole form on every reconnect.
  }

  /// Is a conditional_panel's condition currently true?
  bool conditionHolds(dynamic condition) =>
      evalCondition(condition, inputs);

  /// Report an input's new value. Called by the renderer, never by
  /// [receive].
  void sendInput(String id, dynamic value) {
    // local state first: the control draws from here, and a
    // conditional panel keyed on it settles without waiting for a
    // round trip
    inputs[id] = value;
    _changed();
    _emit(GlintyOutgoing('input', {'type': 'input', 'id': id, 'value': value}));
  }

  /// Update local state without reporting it.
  ///
  /// What an `emit: settle` control does while it is being changed:
  /// the slider thumb tracks the drag and any conditional panel keyed
  /// on it follows, but the server hears once, when the gesture ends.
  /// Reporting each intermediate value is what `live` means, and a
  /// control that does it in both modes has made `settle` decorative.
  void setInputLocal(String id, dynamic value) {
    inputs[id] = value;
    _changed();
  }

  /// Report a discrete event, such as a button press.
  void sendEvent(String id, {String? value}) {
    _emit(GlintyOutgoing('event', {
      'type': 'event',
      'id': id,
      // Omitted rather than sent as null when absent: an ordinary
      // button's press is the whole message, and a null value field
      // would have the server decide what null means.
      'value': ?value,
    }));
  }

  /// Ask for a transfer ticket. The grant arrives as a `ticket`
  /// frame and lands in [tickets] under "purpose:id"; a refusal
  /// arrives on the same frame carrying `error` instead.
  /// Ask for a ticket with no control behind it.
  ///
  /// Recorded in the same ledger as [awaitTicket]'s, in wire order.
  /// Its grant belongs to whoever asked, which is what separates it
  /// from a frame the server volunteered.
  ///
  /// The future completes with null when the ticket was granted (read
  /// the credential from [tickets], or let the transport turn it into
  /// a URL), and with the reason when it was refused, dropped, or
  /// lost with the connection. It never completes with an error, so
  /// ignoring it is safe -- but a refusal a caller cannot see is a
  /// failure that looks like nothing happening, which is the whole
  /// thing this queue exists to stop.
  Future<String?> requestTicket(String id, String purpose) {
    final answer = Completer<String?>();
    _askForTicket(id, purpose, answer.complete);
    return answer.future;
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

  /// Last box reported per output id, so a rebuild at the same size
  /// says nothing.
  final Map<String, String> _measured = <String, String>{};

  /// Report a box, once per distinct size.
  ///
  /// The deduplication the protocol asks callers for. Flutter runs
  /// layout on every frame, so an undeduplicated report would put a
  /// measure frame on the wire for each one, and a plot the server
  /// re-rendered would arrive back as a new value, relayout, and
  /// measure again -- a loop that never settles.
  ///
  /// A zero box is never reported: an Offstage conditional panel and
  /// a hidden tab both lay out at nothing, and telling the server to
  /// draw a 0x0 plot would throw away the size it already had.
  void measure(String id, double width, double height, double dpr) {
    final w = width.round();
    final h = height.round();
    if (w <= 0 || h <= 0) return;
    final key = '$w:$h:$dpr';
    if (_measured[id] == key) return;
    _measured[id] = key;
    sendMeasure(id, w, h, dpr: dpr);
  }

  /// Returns whether the wire took the frame. With no transport
  /// wired -- a session driven straight, as the fixture and protocol
  /// tests do -- there is nothing to drop it, so it counts as taken.
  bool _emit(GlintyOutgoing frame) {
    sent.add(frame);
    return _onSend?.call(frame) ?? true;
  }
}

/// The components this client draws, as a sorted list for `hello`.
///
/// Sorted so the frame is stable across runs; a set's iteration order
/// is not something to make a wire format depend on.
final List<String> supportedComponentsList =
    (supportedComponents.toList()..sort());

/// One request's place in the ledger for a resource's ticket answers.
///
/// A position, not just a callback. Cancelling clears [answer] and
/// leaves the entry: the ledger's positions correspond to requests
/// already on the wire, so an entry that disappears takes the next
/// control's answer with it.
class _TicketRequest {
  _TicketRequest(this.answer);

  /// Whoever is owed this answer: a control's callback, or the
  /// completer behind a direct [GlintySession.requestTicket]. Every
  /// request has one when it is made, so null means exactly one
  /// thing -- the asker has gone, and the answer is nobody's.
  void Function(String? refusal)? answer;
}
