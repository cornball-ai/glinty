/// The top of the tree: a session's current state, on screen.
///
/// Small on purpose. It exists so that "a protocol mismatch is
/// visible" is a property of the widget tree rather than a note in the
/// documentation -- a refusal only counts if the user sees it.
library;

import 'package:flutter/material.dart';

import 'component.dart';
import 'render.dart';
import 'session.dart';
import 'theme.dart';
import 'transport.dart';

/// A glinty app: connect to [url], render whatever the server sends,
/// and keep the wire open.
///
/// This is the whole embedding surface. Everything below it -- the
/// socket, the reconnect policy, the component lowering -- is the
/// same protocol the browser client speaks, so the R app on the
/// other end does not know or care which one connected.
///
/// ```dart
/// void main() => runApp(MaterialApp(
///       home: Scaffold(
///         body: GlintyApp(url: Uri.parse('ws://10.0.2.2:8080/ws')),
///       ),
///     ));
/// ```
class GlintyApp extends StatefulWidget {
  const GlintyApp({
    super.key,
    required this.url,
    this.token,
    this.onDownload,
    this.onLink,
    this.audioBuilder,
    this.customHandlers,
    this.open,
  });

  /// The ws:// or wss:// endpoint.
  final Uri url;

  /// Opaque auth token for hello, from whatever login flow the app
  /// runs. glinty never parses it.
  final String? token;

  /// Where a granted download URL goes. Saving or opening it is
  /// platform work this package leaves to the embedder.
  final void Function(Uri url)? onDownload;

  /// Where a link tap goes; without it links are not tappable.
  final void Function(String href, {bool external})? onLink;

  /// Builds the player for an audio_output. Playing audio needs a
  /// platform plugin, which this package does not take on; without
  /// one the slot says so rather than sitting there silent.
  final GlintyAudioBuilder? audioBuilder;

  /// Handlers for `custom` frames, by name -- the Flutter half of
  /// `send_custom_message()`. glinty has no idea what an app's
  /// custom message means, which is the point of the channel. A
  /// frame naming a handler that is not here draws a visible notice
  /// rather than vanishing.
  final Map<String, void Function(dynamic value)>? customHandlers;

  /// Socket opener, for tests and embedders.
  final GlintySocketOpener? open;

  @override
  State<GlintyApp> createState() => _GlintyAppState();
}

class _GlintyAppState extends State<GlintyApp> {
  late GlintyConnection _conn;

  @override
  void initState() {
    super.initState();
    _conn = _connect();
  }

  GlintyConnection _connect() {
    final conn = GlintyConnection(
      url: widget.url,
      token: widget.token,
      onDownload: widget.onDownload,
      onLink: widget.onLink,
      audioBuilder: widget.audioBuilder,
      open: widget.open,
    );
    _wireHandlers(conn);
    return conn..start();
  }

  void _wireHandlers(GlintyConnection conn) {
    conn.session.customHandlers
      ..clear()
      ..addAll(widget.customHandlers ?? const {});
  }

  @override
  void didUpdateWidget(GlintyApp old) {
    super.didUpdateWidget(old);
    // A new endpoint or a new token is a different session: an app
    // that logs a user out and back in, or points at another server,
    // must not keep talking on the old connection.
    //
    // Wiring or unwiring onDownload changes what hello declares, so
    // it needs a new connection too. Compared by nullness rather
    // than identity: a closure rebuilt each frame is the same
    // capability, and reconnecting on every build would be worse
    // than the bug.
    if (old.url != widget.url ||
        old.token != widget.token ||
        (old.onDownload == null) != (widget.onDownload == null)) {
      _conn.dispose();
      _conn = _connect();
      return;
    }
    // Same capability, possibly a fresh closure: keep the connection
    // and point it at the current callbacks, or a download granted
    // after a rebuild would be handed to a stale one. Custom
    // handlers go the same way -- they name no feature, so wiring one
    // is not a reconnect, but a frame after a rebuild must still
    // reach the closure the app is holding now.
    _conn.onDownload = widget.onDownload;
    _conn.onLink = widget.onLink;
    _wireHandlers(_conn);
  }

  @override
  void dispose() {
    _conn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _conn,
        builder: (context, _) => GlintyView(
          connection: _conn,
          audioBuilder: widget.audioBuilder,
        ),
      );
}

/// Whatever the session currently amounts to, on screen.
///
/// Takes a [connection] in an app, or a bare [session] in a test.
/// The precedence is deliberate: refusals before trees, because a
/// client that draws a stale tree over a refusal is exactly the
/// silent failure this protocol keeps refusing to ship.
class GlintyView extends StatelessWidget {
  const GlintyView(
      {super.key,
      this.session,
      this.connection,
      this.renderer,
      this.audioBuilder})
      : assert(session != null || connection != null,
            'GlintyView needs a session or a connection');

  final GlintySession? session;
  final GlintyConnection? connection;
  final GlintyRenderer? renderer;

  /// Builds the player for an audio_output; see [GlintyApp].
  final GlintyAudioBuilder? audioBuilder;

  @override
  Widget build(BuildContext context) {
    final conn = connection;
    final s = session ?? conn!.session;

    final err = s.error;
    if (err != null) return GlintyProtocolErrorView(error: err);
    final refusal = s.refusalMessage;
    if (refusal != null) {
      return GlintyRefusalView(
          title: 'Connection refused',
          message: refusal,
          lost: conn?.droppedInteractions ?? 0);
    }
    if (conn != null && conn.state == GlintyConnectionState.stopped) {
      return GlintyRefusalView(
          title: 'Disconnected',
          message: conn.stoppedReason ??
              'The connection to the server ended.',
          lost: conn.droppedInteractions);
    }

    final ui = s.ui;
    if (ui == null) return const Center(child: CircularProgressIndicator());

    // Local only. The server holds its own idea of whether a dialog
    // is open, and dismissing one is not an answer to what it asked
    // -- modal_button() and easy_close are both the app saying the
    // question was optional.
    void dismiss() {
      s.modal = null;
      s.notifyChanged();
    }

    final r = renderer ??
        GlintyRenderer(
          onInput: s.sendInput,
          onLocalInput: s.setInputLocal,
          onEvent: s.sendEvent,
          // Only while a dialog is open. A close button with no
          // dialog behind it renders disabled, which is the honest
          // answer -- an enabled one that closes nothing is the same
          // dead control this rule keeps catching.
          onModalClose: s.modal == null ? null : dismiss,
          // Deduplicated inside the session: layout runs every frame,
          // and a report per frame would have the server re-render a
          // plot that then arrives back, relayouts, and measures
          // again.
          onMeasure: s.measure,
          // A relative image src is served by the same app; only the
          // connection knows what address that is.
          assetBase: conn?.assetBase,
          audioBuilder: audioBuilder ?? conn?.audioBuilder,
          // A download registers itself as the waiter for its own
          // request, so a refusal reaches the control that asked.
          awaitTicket: s.awaitTicket,
          // Only when the connection can actually deliver one. A
          // download button wired to a ticket request whose grant
          // has nowhere to go is the same lie as an InkWell with an
          // empty onTap; the renderer disables it when this is null.
          onTicket: (conn == null || conn.onDownload != null)
              ? s.requestTicket
              : null,
          onLink: conn?.onLink,
          values: s.values,
          kinds: s.kinds,
          uiValues: s.uiValues,
          errors: s.errors,
          inputs: s.inputs,
          pushes: s.pushes,
          overrides: s.overrides,
          condition: s.conditionHolds,
          spacing: glintySpacing(s.theme),
          monoStack: glintyMonoStack(s.theme),
        );
    // Keyed by generation: a replaced tree (or a refused resume that
    // cleared the state) must not leave Flutter reusing the element
    // and controller state of the tree that is gone.
    final built = KeyedSubtree(
      key: ValueKey('glinty-tree-${s.generation}'),
      child: Builder(builder: (context) => r.build(context, ui)),
    );
    // Overlays, drawn above the tree rather than inside it: a dialog
    // and a progress report are things the server says about the app,
    // not parts of it, and both arrive as frames rather than tree
    // nodes. Building them here is what stops show_modal() and
    // with_progress() from being no-ops against this client.
    //
    // Always a Stack, even with nothing above the tree. An overlay
    // that comes and goes must not change the shape of the tree
    // *underneath* it: wrapping the app in a Stack only when a layer
    // appears reparents every widget in it, and Flutter answers a
    // reparent by throwing the old elements away. So opening a dialog
    // cleared half-typed fields, and the reconnect banner wiped the
    // very transfer refusal it appeared alongside. The app stays at
    // index 0, and layers land after it.
    //
    // passthrough, not the default loose: the app was a direct child
    // of whatever holds this view, and a Stack that loosens the
    // constraints changes what "fill the space" means one level down.
    // A page that filled its parent would start sizing to its content
    // instead, and every plot_output under it would measure and
    // report a different box.
    final stacked = Stack(fit: StackFit.passthrough, children: [
      built,
      if (s.progress.isNotEmpty) _ProgressStack(reports: s.progress),
      if (s.unhandledCustom.isNotEmpty)
        _UnhandledCustomNotice(handlers: s.unhandledCustom),
      if (s.modal != null)
        _ModalLayer(
          frame: s.modal!,
          renderer: r,
          generation: s.generation,
          onDismiss: dismiss,
        ),
      // What the connection has to say, in one strip at the top.
      //
      // Not Positioned, which is the part that is easy to get wrong:
      // a positioned child does not count towards the Stack's size,
      // and the Stack here is only as tall as the app inside it. A
      // page that sizes to its content is shorter than this strip,
      // so a positioned strip drew past the bottom edge and was
      // clipped out of hit testing -- visible, and untouchable, which
      // for a notice with a dismiss button is worse than not drawing
      // at all. Aligned and unpositioned, it participates in sizing,
      // and the Stack grows to hold whichever is taller.
      if (conn != null &&
          (conn.state == GlintyConnectionState.reconnecting ||
              conn.droppedInteractions > 0))
        Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // A reconnect in progress is honest, not hidden: the app
            // stays usable and says what is happening.
            if (conn.state == GlintyConnectionState.reconnecting)
              const _ReconnectBanner(),
            // And so is work the app could not send. The user is the
            // only one who can redo it, and only if they are told.
            if (conn.droppedInteractions > 0)
              _DroppedNotice(
                count: conn.droppedInteractions,
                onDismiss: conn.clearDroppedInteractions,
              ),
          ]),
        ),
    ]);

    // Not conditional in the same way: the theme arrives with the
    // welcome, and the tree does not render before one.
    final tokens = s.theme;
    return tokens == null
        ? stacked
        : Theme(data: glintyThemeData(tokens), child: stacked);
  }
}

/// The dialog `show_modal()` opens.
///
/// An overlay rather than `showDialog`, because the frame is state
/// the session owns: a `modal` hide, a refused resume or a dropped
/// connection must be able to take the dialog away, and a route
/// pushed onto the navigator would outlive all three.
class _ModalLayer extends StatelessWidget {
  const _ModalLayer(
      {required this.frame,
      required this.renderer,
      required this.generation,
      required this.onDismiss});

  final Map<String, dynamic> frame;
  final GlintyRenderer renderer;
  final int generation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final title = frame['title'];
    final body = frame['body'];
    final footer = frame['footer'];
    final scheme = Theme.of(context).colorScheme;
    return KeyedSubtree(
      key: ValueKey('glinty-modal-$generation'),
      child: Stack(children: [
        // The scrim is not decoration: it is what makes the dialog
        // modal, by eating the taps the tree behind would otherwise
        // still take. easy_close decides whether it also dismisses.
        Positioned.fill(
          child: GestureDetector(
            onTap: frame['easy_close'] == true ? onDismiss : () {},
            child: const ColoredBox(color: Color(0x8A000000)),
          ),
        ),
        Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title is String)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                    if (body is List)
                      ...body.whereType<Map>().map((node) => renderer.build(
                          context,
                          GlintyComponent.fromJson(
                              node.cast<String, dynamic>()))),
                    if (footer is Map)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: renderer.build(
                            context,
                            GlintyComponent.fromJson(
                                footer.cast<String, dynamic>())),
                      ),
                    // A dialog with neither a footer nor easy_close
                    // has no way out at all -- the server closes it,
                    // and until then the app is stuck behind it.
                    if (footer is! Map && frame['easy_close'] != true)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Waiting for the server to close this.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Progress reports from `with_progress()`, stacked bottom-left.
class _ProgressStack extends StatelessWidget {
  const _ProgressStack({required this.reports});

  final Map<String, Map<String, dynamic>> reports;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: reports.values.map((r) {
          final value = r['value'];
          final message = r['message'];
          final detail = r['detail'];
          return Card(
            key: Key('g-progress-${r['id']}'),
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message is String && message.isNotEmpty) Text(message),
                  const SizedBox(height: 8),
                  // A null value means "working, no idea how far" --
                  // which is what an indeterminate bar says, and what
                  // pinning it to zero would misreport as stalled.
                  LinearProgressIndicator(
                      value: value is num ? value.toDouble() : null),
                  if (detail is String && detail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(detail,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A custom message the server sent that nothing was listening for.
///
/// The same rule as an unsupported component: name the gap on screen.
/// An app whose JavaScript half was never ported would otherwise look
/// like it works and quietly do half of what it says.
class _UnhandledCustomNotice extends StatelessWidget {
  const _UnhandledCustomNotice({required this.handlers});

  final Set<String> handlers;

  @override
  Widget build(BuildContext context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: const Color(0xFFFFF3CD),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '[no handler for custom message: '
              '${handlers.join(", ")}]',
              style: const TextStyle(color: Color(0xFF664D03)),
            ),
          ),
        ),
      );
}

/// What the app had to throw away, and how much of it.
///
/// The send queue is capped so a user tapping at a dead app cannot
/// grow memory without limit, which means that past the cap an
/// interaction is lost. Lost quietly, it looks to the user like the
/// app simply ignored them -- so it says so, and stays until
/// dismissed. Not a toast: this is a report of work that has to be
/// redone, and it should still be there when they look up.
class _DroppedNotice extends StatelessWidget {
  const _DroppedNotice({required this.count, required this.onDismiss});

  final int count;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(children: [
          Expanded(
            child: Text(
              count == 1
                  ? '1 thing you did could not be sent, and has been '
                      'lost. Please check and try it again.'
                  : '$count things you did could not be sent, and have '
                      'been lost. Please check and try them again.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
            color: scheme.onErrorContainer,
            tooltip: 'Dismiss',
          ),
        ]),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: double.infinity,
          child: Text('Reconnecting…',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onPrimary)),
        ),
      ),
    );
  }
}

/// The refusal, drawn.
///
/// Deliberately not a dialog and not a snackbar: it replaces the
/// content rather than sitting on top of it, because there is no
/// content this client can be trusted to have understood.
class GlintyProtocolErrorView extends StatelessWidget {
  const GlintyProtocolErrorView({super.key, required this.error});

  final GlintyProtocolError error;

  @override
  Widget build(BuildContext context) => GlintyRefusalView(
      title: 'Incompatible glinty server', message: error.message);
}

/// Any fatal refusal, drawn: protocol mismatch, authentication, or
/// whatever the server named. Replaces the content rather than
/// sitting on top of it, because there is no content this client can
/// be trusted to show.
class GlintyRefusalView extends StatelessWidget {
  const GlintyRefusalView(
      {super.key, required this.title, required this.message, this.lost = 0});

  final String title;
  final String message;

  /// How many of the user's interactions went unsent when the
  /// connection ended.
  ///
  /// Reported here rather than in the notice the running app draws,
  /// because this screen *replaces* that app: a terminal refusal is
  /// exactly the case where the work is most certainly lost and least
  /// likely to be mentioned.
  final int lost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          if (lost > 0) ...[
            const SizedBox(height: 8),
            Text(
              lost == 1
                  ? '1 thing you did was never sent.'
                  : '$lost things you did were never sent.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ],
        ],
      ),
    );
  }
}
