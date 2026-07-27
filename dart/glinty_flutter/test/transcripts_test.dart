// The wire transcripts, replayed.
//
// The fixture suite proves this client can draw a tree. This one
// proves it can hold a conversation: the opening exchange, hydration,
// and the two refusals. Both suites read files generated from the R
// definitions, so neither can drift from what the server actually
// sends.
//
// Every transcript here is also asserted by the R suite. The frames
// are the shared artifact; what each side does with them is not.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

const transcriptPath = "../../inst/fixtures/transcripts.json";

Map<String, dynamic> loadTranscriptFile() =>
    jsonDecode(File(transcriptPath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> loadTranscripts() =>
    (loadTranscriptFile()["transcripts"] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> transcript(String name) => loadTranscripts()
    .firstWhere((t) => t['name'] == name, orElse: () => throw StateError(
        'no transcript named $name; the R definition and this suite '
        'have diverged'));

/// The frames one side sends, in order.
List<Map<String, dynamic>> frames(Map<String, dynamic> t, String dir) =>
    (t['frames'] as List)
        .cast<Map<String, dynamic>>()
        .where((f) => f['dir'] == dir)
        .map((f) => (f['message'] as Map).cast<String, dynamic>())
        .toList();

/// The one server frame of a given type, or the first if there are several.
Map<String, dynamic> serverFrame(String name, String type) =>
    frames(transcript(name), 'out').firstWhere((m) => m['type'] == type);

void main() {
  group('the transcript file', () {
    test('declares the protocol this client speaks', () {
      expect(loadTranscriptFile()['protocol'], glintyProtocolVersion);
    });

    test('is the one glinty generated', () {
      final ts = loadTranscripts();
      expect(ts, isNotEmpty);
      for (final t in ts) {
        expect(t['name'], isA<String>());
        expect(t['notes'], isA<String>(),
            reason: 'every transcript explains the exchange it pins');
        expect(t['frames'], isA<List>());
        for (final f in (t['frames'] as List)) {
          expect((f as Map)['dir'], anyOf('in', 'out'));
          expect((f['message'] as Map)['type'], isA<String>());
        }
      }
    });
  });

  group('the opening exchange', () {
    test('hello declares capabilities without negotiating', () {
      final s = GlintySession();
      final hello = s.hello();

      expect(hello.body['type'], 'hello');
      expect(hello.body['protocol'], glintyProtocolVersion);
      expect(hello.body['client'], isNotEmpty);

      final declared = (hello.body['components'] as List).cast<String>();
      expect(declared, contains('page'));
      expect(declared, isNot(contains('raw_html')),
          reason: 'a component this client refuses must not be declared, '
              'or the placeholder never appears');
      // A declaration, so it says nothing about what arrives.
      expect(declared.toSet(), supportedComponents);
    });

    test('welcome installs the tree', () {
      final s = GlintySession();
      s.hello();
      final before = s.sent.length;

      s.receive(serverFrame('hello-welcome', 'welcome'));

      expect(s.refused, isFalse);
      expect(s.ui, isNotNull);
      expect(s.ui!.type, 'page');
      expect(s.sessionId, isNotEmpty);
      expect(s.uiRevision, hasLength(64));
      expect(s.source, GlintyTreeSource.rebuilt);
      expect(s.sent.length, before,
          reason: 'invariant 2: receiving a tree emits nothing');
    });
  });

  group('hydration', () {
    // A cached tree stands in for the browser's pre-rendered DOM. The
    // mechanism differs -- Flutter has no markup to adopt -- but the
    // decision is the same one: is what I already have the tree I am
    // being sent?
    GlintyComponent cachedTree(String name) =>
        GlintyComponent.fromJson(serverFrame(name, 'welcome')['ui']);

    test('a matching revision adopts and sends nothing', () {
      final welcome = serverFrame('hello-welcome-hydrated', 'welcome');
      final cached = cachedTree('hello-welcome-hydrated');
      final s = GlintySession(
        cachedUi: cached,
        cachedRevision: welcome['ui_revision'] as String,
      );
      s.hello();
      final before = s.sent.length;

      s.receive(welcome);

      expect(s.source, GlintyTreeSource.adopted);
      expect(identical(s.ui, cached), isTrue,
          reason: 'adoption keeps the tree it already had, and with it '
              'any widget state hanging off those elements');
      expect(s.sent.length, before,
          reason: 'invariant 2: adoption is not user interaction');
    });

    test('hello carries what the client already has', () {
      final welcome = serverFrame('hello-welcome-hydrated', 'welcome');
      final rev = welcome['ui_revision'] as String;
      final s = GlintySession(
          cachedUi: cachedTree('hello-welcome-hydrated'), cachedRevision: rev);

      expect(s.hello().body['prerendered'], rev);
      expect(GlintySession().hello().body.containsKey('prerendered'), isFalse,
          reason: 'a client with nothing cached must not claim a revision');
    });

    test('a mismatched revision rebuilds rather than patching', () {
      final hello = frames(transcript('revision-mismatch'), 'in').first;
      final welcome = serverFrame('revision-mismatch', 'welcome');
      final stale = GlintyComponent.fromJson({
        'component': 'page',
        'title': 'Stale',
        'children': [
          {'component': 'heading', 'value': 'Stale', 'level': 1}
        ],
      });
      final s = GlintySession(
        cachedUi: stale,
        cachedRevision: hello['prerendered'] as String,
      );
      s.hello();

      s.receive(welcome);

      expect(s.source, GlintyTreeSource.rebuilt);
      expect(identical(s.ui, stale), isFalse);
      expect(s.uiRevision, welcome['ui_revision']);
      expect(s.ui!.children.first.str('value'), 'Demo',
          reason: 'the tree on screen is the one that was sent, not the '
              'one that was cached');
    });

    testWidgets('one press is one frame, across a rebuild', (tester) async {
      // Invariant 1 in Flutter terms. There is no DOM to adopt, so the
      // hazard is a stale callback surviving a rebuild rather than a
      // second listener being attached to adopted markup. Either way
      // the assertion is the same: one press, one frame.
      //
      // The browser half -- adopting server-rendered markup without
      // attaching a second listener -- is the browser client's to
      // prove, in stage 2.
      final s = GlintySession();
      s.hello();

      final tree = GlintyComponent.fromJson({
        'component': 'page',
        'title': 'Demo',
        'children': [
          {
            'component': 'button',
            'id': 'go',
            'label': 'Run',
            'variant': 'primary'
          }
        ],
      });

      Future<void> pump() => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => GlintyRenderer(
                  onInput: s.sendInput,
                  onEvent: s.sendEvent,
                ).build(context, tree),
              ),
            ),
          ));

      int events() => s.sent.where((f) => f.type == 'event').length;

      await pump();
      await tester.tap(find.text('Run'));
      await tester.pump();
      expect(events(), 1);

      // Same tree again: a rebuild, not a new app.
      await pump();
      await tester.tap(find.text('Run'));
      await tester.pump();
      expect(events(), 2, reason: 'one press, one frame -- not two');
    });
  });

  group('a protocol mismatch', () {
    test('is refused rather than half-rendered', () {
      final s = GlintySession();
      s.hello();

      s.receive(serverFrame('protocol-mismatch', 'welcome'));

      expect(s.refused, isTrue);
      expect(s.ui, isNull,
          reason: 'the frame carries a tree this client could parse; '
              'refusing means not rendering it anyway');
      expect(s.error!.expected, glintyProtocolVersion);
      expect(s.error!.received, greaterThan(glintyProtocolVersion));
    });

    test('ignores everything that follows', () {
      final s = GlintySession();
      s.receive(serverFrame('protocol-mismatch', 'welcome'));
      s.receive({'type': 'output', 'id': 'greeting', 'value': 'Hello'});

      expect(s.values, isEmpty,
          reason: 'a refused session has no state worth updating');
    });

    testWidgets('says so on screen', (tester) async {
      final s = GlintySession();
      s.receive(serverFrame('protocol-mismatch', 'welcome'));

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GlintyView(session: s))));

      expect(find.text('Incompatible glinty server'), findsOneWidget);
      expect(find.textContaining('protocol 3'), findsOneWidget);
      expect(find.textContaining('protocol 4'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // and nothing from the tree it refused
      expect(find.text('Demo'), findsNothing);
    });

    testWidgets('a well-formed welcome renders instead', (tester) async {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GlintyView(session: s))));

      expect(find.text('Incompatible glinty server'), findsNothing);
      expect(find.text('Demo'), findsOneWidget);
    });
  });

  group('inputs and outputs', () {
    test('an input frame matches the transcript shape', () {
      final expected = frames(transcript('input-then-output'), 'in').first;
      final s = GlintySession();
      s.sendInput(expected['id'] as String, expected['value']);

      expect(s.sent.single.body, expected);
    });

    test('an output frame updates the value the renderer draws', () {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive(serverFrame('input-then-output', 'output'));

      expect(s.values['greeting'], 'Hello, Troy');
    });

    testWidgets('and reaches the screen', (tester) async {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive(serverFrame('input-then-output', 'output'));

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GlintyView(session: s))));

      expect(find.text('Hello, Troy'), findsOneWidget);
    });

    test('a measure frame matches the transcript shape', () {
      final expected = frames(transcript('measure-then-image'), 'in').first;
      final s = GlintySession();
      s.sendMeasure(expected['id'] as String, expected['width'] as int,
          expected['height'] as int);

      expect(s.sent.single.body, expected);
    });

    test('an unknown message type is ignored, not fatal', () {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive({'type': 'something_from_a_newer_server', 'payload': 1});

      expect(s.refused, isFalse);
      expect(s.ui, isNotNull);
    });
  });
}
