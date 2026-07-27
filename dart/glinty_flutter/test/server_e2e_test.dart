// The Flutter client against a real glinty server.
//
// Everything else in this suite replays recorded frames. This spawns
// R, serves an actual app, opens an actual WebSocket, and drives the
// real client through it -- the one test that can catch a divergence
// between what the server sends and what the transcripts say it
// sends.
//
// Skipped when Rscript or the glinty package is unavailable, which
// is the honest behaviour on a machine that only builds the Dart
// side. The R e2e suite covers the same wire from the other end.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

/// A glinty app served by a child R process.
class GlintyServer {
  GlintyServer(this.process, this.port, this.script);

  final Process process;
  final int port;
  final File script;

  Uri get ws => Uri.parse('ws://127.0.0.1:$port/ws');
  Uri get http => Uri.parse('http://127.0.0.1:$port');

  Future<void> stop() async {
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(const Duration(seconds: 5),
        onTimeout: () => -1);
    if (script.existsSync()) script.deleteSync();
  }

  /// Spawn a server on a free port and wait for it to answer.
  ///
  /// [appBody] is R building an `a <- app(...)`; [runArgs] is what
  /// goes into run_app() beyond the port.
  static Future<GlintyServer?> start(String appBody,
      {String runArgs = ''}) async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    final script = File('${Directory.systemTemp.path}/glinty_dart_e2e_'
        '${DateTime.now().microsecondsSinceEpoch}.R');
    script.writeAsStringSync('''
library(glinty)
$appBody
run_app(a, port = ${port}L, quiet = TRUE$runArgs)
''');

    final Process process;
    try {
      process = await Process.start('Rscript', ['--vanilla', script.path]);
    } on ProcessException {
      script.deleteSync();
      return null; // no R on this machine
    }
    final log = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(log.write);
    process.stderr.transform(utf8.decoder).listen(log.write);

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final s = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(seconds: 1));
        s.destroy();
        return GlintyServer(process, port, script);
      } catch (_) {
        if (log.toString().contains('there is no package called')) {
          process.kill();
          script.deleteSync();
          return null; // glinty not installed
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    process.kill();
    script.deleteSync();
    throw StateError('glinty server never came up: $log');
  }
}

/// Wait for [check] to hold, pumping the event loop.
Future<void> until(bool Function() check,
    {Duration timeout = const Duration(seconds: 10),
    String what = 'condition'}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  throw StateError('timed out waiting for $what');
}

void main() {
  test('the client renders, interacts and resumes against a real server',
      () async {
    final server = await GlintyServer.start('''
a <- app(
    ui = page(
        heading("Live", level = 1L),
        text_input("name", "Name:"),
        text_output("greeting"),
        button("bump", "Bump"),
        text_output("count"),
        title = "e2e"
    ),
    theme = app_theme(colors = list(primary = "#7c3aed")),
    server = function(input, output) {
        output\$greeting <- render_text(function() {
            paste("Hello,", input\$name())
        })
        output\$count <- render_text(function() {
            n <- input\$bump()
            if (is.null(n)) "0" else as.character(n)
        })
    }
)''');
    if (server == null) {
      markTestSkipped("Rscript or glinty unavailable");
      return;
    }

    try {
      final conn = GlintyConnection(url: server.ws);
      await conn.start();

      // the bootstrap: a real welcome, from a real server
      await until(() => conn.session.ui != null, what: 'welcome');
      expect(conn.state, GlintyConnectionState.live);
      expect(conn.session.ui!.type, 'page');
      expect(conn.session.sessionId, isNotNull);
      expect(conn.session.uiRevision, isNotEmpty);

      // the theme the R app declared arrives and maps to ThemeData
      expect((conn.session.theme!['colors'] as Map)['primary'], '#7c3aed');
      expect(glintyThemeData(conn.session.theme!).colorScheme.primary,
          const Color(0xff7c3aed));

      // the server seeded its inputs from the tree: an empty text
      // field is "", so the greeting is already computed
      await until(() => conn.session.values['greeting'] != null,
          what: 'seeded greeting');
      expect(conn.session.values["greeting"], "Hello, ");
      expect(conn.session.values['count'], '0');

      // an input reaches R and the dependent output comes back
      conn.session.sendInput('name', 'Troy');
      await until(() => conn.session.values['greeting'] == 'Hello, Troy',
          what: 'greeting update');

      // an event increments, twice, once each
      conn.session.sendEvent('bump');
      await until(() => conn.session.values['count'] == '1',
          what: 'first bump');
      conn.session.sendEvent('bump');
      await until(() => conn.session.values['count'] == '2',
          what: 'second bump');

      // a ticket is granted over the socket, scoped and short-lived
      conn.session.requestTicket('name', 'upload');
      await until(() => conn.session.tickets['upload:name'] != null,
          what: 'ticket grant');
      final grant = conn.session.tickets['upload:name']!;
      expect(grant['token'].toString(), startsWith('tk_'));
      expect(grant['expires'], greaterThan(0));

      final sid = conn.session.sessionId;
      conn.dispose();

      // a second connection resumes that session and gets its state
      // replayed -- no interactions repeated
      final again = GlintyConnection(url: server.ws);
      again.session.sessionId = sid;
      await again.start();
      await until(() => again.session.values['count'] == '2',
          what: 'resumed state');
      expect(again.session.values['greeting'], 'Hello, Troy');
      again.dispose();
    } finally {
      await server.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('an auth-gated server refuses, visibly, over a real socket',
      () async {
    final server = await GlintyServer.start('''
a <- app(
    ui = page(text_output("who"), title = "gated"),
    server = function(input, output, session) {
        output\$who <- render_text(function() session\$principal\$id)
    }
)''', runArgs: ''',
    auth = function(token) {
        if (identical(token, "letmein")) list(id = "u_42")
    }''');
    if (server == null) {
      markTestSkipped("Rscript or glinty unavailable");
      return;
    }

    try {
      // no token: refused, and the client stops rather than looping
      final bad = GlintyConnection(url: server.ws, maxRetries: 2);
      await bad.start();
      await until(() => bad.session.refused, what: 'refusal');
      expect(bad.session.refusalMessage, contains('authentication'));
      await until(() => bad.state == GlintyConnectionState.stopped,
          what: 'stopped');
      expect(bad.session.ui, isNull);
      bad.dispose();

      // the right token: welcomed, and the principal reaches the app
      final good =
          GlintyConnection(url: server.ws, token: 'letmein');
      await good.start();
      await until(() => good.session.values['who'] == 'u_42',
          what: 'principal rendered');
      expect(good.session.refused, isFalse);
      good.dispose();
    } finally {
      await server.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
