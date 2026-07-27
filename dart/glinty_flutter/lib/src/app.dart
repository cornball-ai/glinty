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

class GlintyView extends StatelessWidget {
  const GlintyView({super.key, required this.session, this.renderer});

  final GlintySession session;
  final GlintyRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    final err = session.error;
    if (err != null) return GlintyProtocolErrorView(error: err);
    final refusal = session.refusalMessage;
    if (refusal != null) {
      return GlintyRefusalView(
          title: 'Connection refused', message: refusal);
    }

    final ui = session.ui;
    if (ui == null) return const Center(child: CircularProgressIndicator());

    final r = renderer ??
        GlintyRenderer(
          onInput: session.sendInput,
          onEvent: session.sendEvent,
          values: session.values,
          spacing: glintySpacing(session.theme),
          monoStack: glintyMonoStack(session.theme),
        );
    final built = Builder(builder: (context) => r.build(context, ui));
    final tokens = session.theme;
    return tokens == null
        ? built
        : Theme(data: glintyThemeData(tokens), child: built);
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
