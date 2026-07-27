/// The top of the tree: a session's current state, on screen.
///
/// Small on purpose. It exists so that "a protocol mismatch is
/// visible" is a property of the widget tree rather than a note in the
/// documentation -- a refusal only counts if the user sees it.
library;

import 'package:flutter/material.dart';

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

  GlintyConnection _connect() => GlintyConnection(
        url: widget.url,
        token: widget.token,
        onDownload: widget.onDownload,
        onLink: widget.onLink,
        open: widget.open,
      )..start();

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
    // after a rebuild would be handed to a stale one.
    _conn.onDownload = widget.onDownload;
    _conn.onLink = widget.onLink;
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
          inputs: s.inputs,
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
    final tokens = s.theme;
    final themed = tokens == null
        ? built
        : Theme(data: glintyThemeData(tokens), child: built);
    // A reconnect in progress is honest, not hidden: the app stays
    // usable and says what is happening.
    if (conn != null && conn.state == GlintyConnectionState.reconnecting) {
      return Stack(children: [themed, const _ReconnectBanner()]);
    }
    return themed;
  }
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
