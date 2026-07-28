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
        builder: (context, _) => GlintyView(connection: _conn),
      );
}

/// Whatever the session currently amounts to, on screen.
///
/// Takes a [connection] in an app, or a bare [session] in a test.
/// The precedence is deliberate: refusals before trees, because a
/// client that draws a stale tree over a refusal is exactly the
/// silent failure this protocol keeps refusing to ship.
class GlintyView extends StatelessWidget {
  const GlintyView({super.key, this.session, this.connection, this.renderer})
      : assert(session != null || connection != null,
            'GlintyView needs a session or a connection');

  final GlintySession? session;
  final GlintyConnection? connection;
  final GlintyRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    final conn = connection;
    final s = session ?? conn!.session;

    final err = s.error;
    if (err != null) return GlintyProtocolErrorView(error: err);
    final refusal = s.refusalMessage;
    if (refusal != null) {
      return GlintyRefusalView(
          title: 'Connection refused', message: refusal);
    }
    if (conn != null && conn.state == GlintyConnectionState.stopped) {
      return GlintyRefusalView(
          title: 'Disconnected',
          message: conn.stoppedReason ??
              'The connection to the server ended.');
    }

    final ui = s.ui;
    if (ui == null) return const Center(child: CircularProgressIndicator());

    final r = renderer ??
        GlintyRenderer(
          onInput: s.sendInput,
          onLocalInput: s.setInputLocal,
          onEvent: s.sendEvent,
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
    final layers = <Widget>[
      built,
      if (s.progress.isNotEmpty) _ProgressStack(reports: s.progress),
      if (s.unhandledCustom.isNotEmpty)
        _UnhandledCustomNotice(handlers: s.unhandledCustom),
      if (s.modal != null)
        _ModalLayer(
          frame: s.modal!,
          renderer: r,
          generation: s.generation,
          // Local only. The server holds its own idea of whether a
          // dialog is open, and a tap on the backdrop is not an
          // answer to what the dialog asked -- easy_close is the app
          // saying the question was optional.
          onDismiss: () {
            s.modal = null;
            s.notifyChanged();
          },
        ),
    ];
    final stacked =
        layers.length == 1 ? built : Stack(children: layers);

    final tokens = s.theme;
    final themed = tokens == null
        ? stacked
        : Theme(data: glintyThemeData(tokens), child: stacked);
    // A reconnect in progress is honest, not hidden: the app stays
    // usable and says what is happening.
    if (conn != null && conn.state == GlintyConnectionState.reconnecting) {
      return Stack(children: [themed, const _ReconnectBanner()]);
    }
    return themed;
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

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: scheme.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
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
      {super.key, required this.title, required this.message});

  final String title;
  final String message;

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
        ],
      ),
    );
  }
}
