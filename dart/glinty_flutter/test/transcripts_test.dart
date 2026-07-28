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


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'transcript_data.dart';


void main() {
  // transcripts.json is a shared artifact, and a transcript nobody
  // replays pins nothing. Dart runs each test file in its own
  // isolate, so the contract is per-file: this is the file that must
  // answer for every entry.
  tearDownAll(() {
    final all = loadTranscripts().map((t) => t['name'] as String).toSet();
    expect(all.difference(usedTranscripts), isEmpty,
        reason: 'transcripts checked in and never replayed here');
  });

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
      // The revision is opaque: present, compared for equality, never
      // shape-checked. Asserting its length here would teach this
      // client something the protocol says it must not know.
      expect(s.uiRevision, isNotEmpty);
      expect(s.source, GlintyTreeSource.rebuilt);
      expect(s.sent.length, before,
          reason: 'invariant 2: receiving a tree emits nothing');
    });

    test('welcome carries the theme tokens, when the app set one', () {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      expect(s.theme, isNotNull);
      expect((s.theme!['colors'] as Map)['primary'], '#2456d6');

      final bare = GlintySession();
      bare.receive({'type': 'welcome', 'session': 's0', 'protocol': 3});
      expect(bare.theme, isNull,
          reason: 'a themeless app leaves the platform defaults alone');
    });
  });

  group('theme tokens map onto ThemeData', () {
    test('hex parsing is strict and fallback-friendly', () {
      expect(glintyColor('#2456d6'), const Color(0xff2456d6));
      expect(glintyColor('#2456d680'), const Color(0x802456d6));
      expect(glintyColor('red'), isNull);
      expect(glintyColor('#12345'), isNull);
      expect(glintyColor(12), isNull);
    });

    test('the transcript theme builds the declared palette', () {
      final theme = serverFrame('hello-welcome', 'welcome')['theme']
          as Map<String, dynamic>;
      final data = glintyThemeData(theme);

      expect(data.colorScheme.primary, const Color(0xff2456d6));
      expect(data.colorScheme.onPrimary, const Color(0xffffffff));
      expect(data.colorScheme.error, const Color(0xffb3261e));
      expect(data.scaffoldBackgroundColor, const Color(0xffffffff));
      expect(data.colorScheme.brightness, Brightness.light);
      expect(glintySpacing(theme), 4);
    });

    test('a dark background makes a dark scheme', () {
      final data = glintyThemeData({
        'colors': {'background': '#16181d', 'text': '#e6e6e6'}
      });
      expect(data.colorScheme.brightness, Brightness.dark);
    });

    test('muted, radius and mono land where the renderer reads them', () {
      final data = glintyThemeData({
        'colors': {'muted': '#6a6a6a'},
        'radius': 6,
      });
      expect(data.colorScheme.onSurfaceVariant, const Color(0xff6a6a6a));
      final shape = data.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(6));
      expect(data.filledButtonTheme.style?.shape?.resolve({}),
          isA<RoundedRectangleBorder>());

      // a custom mono family leads its stack and degrades within the
      // mono role, never to sans
      expect(glintyMonoStack({'font': {'mono': 'JetBrains Mono'}}),
          ['JetBrains Mono', 'monospace', 'Menlo', 'Courier New']);
      expect(glintyMonoStack({'font': {'body': 'Inter'}}), glintyMonoRole);
      expect(glintyMonoStack(null), glintyMonoRole);

      // ghost buttons are TextButtons -- the one family radius missed
      expect(data.textButtonTheme.style?.shape?.resolve({}),
          isA<RoundedRectangleBorder>());
    });

    test('CSS generics preserve their role instead of collapsing', () {
      // The framework's own error style says fontFamily: 'monospace'
      // (flutter/lib/src/material/app.dart): the generic names are
      // resolvable on Android, and the stacks append faces Apple and
      // desktop platforms know. body monospace stays mono, mono
      // serif goes serif -- neither collapses to the default sans.
      final monoBody = glintyThemeData({
        'font': {'body': 'monospace'}
      });
      expect(monoBody.textTheme.bodyMedium?.fontFamily, 'monospace');
      expect(monoBody.textTheme.bodyMedium?.fontFamilyFallback,
          contains('Menlo'));

      expect(glintyMonoStack({'font': {'mono': 'serif'}}),
          ['serif', 'Georgia', 'Times New Roman']);

      // sans roles ARE the platform default; ui-monospace keeps mono
      expect(glintyFontStack('system-ui'), ['sans-serif']);
      expect(glintyMonoStack({'font': {'mono': 'ui-monospace'}}),
          glintyMonoRole);
      final sansBody = glintyThemeData({
        'font': {'body': 'system-ui'}
      });
      expect(sansBody.textTheme.bodyMedium?.fontFamily,
          isNot('system-ui'));
    });

    test('spacing zero is a unit, not an absence', () {
      expect(glintySpacing({'spacing': 0}), 0);
      expect(glintySpacing({'spacing': 8}), 8);
      expect(glintySpacing({}), 4);
      expect(glintySpacing(null), 4);
    });

    testWidgets('danger buttons take the theme danger token',
        (tester) async {
      final data = glintyThemeData({
        'colors': {'danger': '#b3261e'}
      });
      final r = GlintyRenderer();
      await tester.pumpWidget(MaterialApp(
        theme: data,
        home: Scaffold(
          body: Builder(
            builder: (context) => r.build(
                context,
                GlintyComponent.fromJson({
                  'component': 'button',
                  'id': 'del',
                  'label': 'Delete',
                  'variant': 'danger'
                })),
          ),
        ),
      ));
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.style?.backgroundColor?.resolve({}),
          const Color(0xffb3261e));
    });

    testWidgets('sidebar panels are distinct from plain ones',
        (tester) async {
      final r = GlintyRenderer();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => r.build(
                context,
                GlintyComponent.fromJson({
                  'component': 'panel',
                  'variant': 'sidebar',
                  'children': [
                    {'component': 'text', 'value': 'nav'}
                  ]
                })),
          ),
        ),
      ));
      final box = tester.widget<Container>(find.byType(Container).first);
      final deco = box.decoration as BoxDecoration;
      expect(deco.border, isNotNull,
          reason: 'the sidebar edge is what tells it apart from plain');
    });

    testWidgets('GlintyView applies the theme to what it renders',
        (tester) async {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GlintyView(session: s))));

      final ctx = tester.element(find.text('Demo'));
      expect(Theme.of(ctx).colorScheme.primary, const Color(0xff2456d6));
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

    test('hello carries the auth token, when the app has one', () {
      final expected = frames(transcript('hello-authenticated'), 'in').first;
      final s = GlintySession(
          client: expected['client'] as String,
          token: expected['token'] as String);
      final hello = s.hello();
      expect(hello.body['token'], expected['token']);
      expect(GlintySession().hello().body.containsKey('token'), isFalse,
          reason: 'no token, no field');
    });

    testWidgets('a refused connection is visible, not a spinner',
        (tester) async {
      final s = GlintySession(token: 'expired.or.wrong');
      s.hello();
      s.receive(serverFrame('hello-refused', 'error'));

      expect(s.refused, isTrue);
      expect(s.ui, isNull);
      s.receive(serverFrame('hello-welcome', 'welcome'));
      expect(s.sessionId, isNull,
          reason: 'nothing after a refusal is meaningful');

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GlintyView(session: s))));
      expect(find.text('Connection refused'), findsOneWidget);
      expect(find.textContaining('authentication failed'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a refusal on RECONNECT is visible too', (tester) async {
      // The token that worked an hour ago has expired. A client that
      // keyed "is this a refusal?" on having never connected would
      // treat this as an ordinary error and retry forever.
      final s = GlintySession(token: 'was.valid.once');
      s.hello();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      expect(s.refused, isFalse);
      expect(s.ui, isNotNull);

      s.hello(); // reconnect
      s.receive(serverFrame('hello-refused', 'error'));

      expect(s.refused, isTrue);
      expect(s.refusalMessage, contains('authentication'));
      expect(s.ui, isNull, reason: 'the stale tree must not stay on screen');

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: GlintyView(session: s))));
      expect(find.text('Connection refused'), findsOneWidget);
    });

    test('an output error after welcome is not a refusal', () {
      // the other half of the window: id-less errors only refuse
      // while a welcome is outstanding
      final s = GlintySession();
      s.hello();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive({'type': 'error', 'id': 'greeting', 'message': 'boom'});

      expect(s.refused, isFalse);
      expect(s.ui, isNotNull);
      expect(s.values['greeting'], isNull);
    });

    test('a ticket request matches the transcript, and the grant lands',
        () {
      final t = transcript('ticket-grant');
      final expected = frames(t, 'in').first;
      final grant = frames(t, 'out').first;
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.sent.clear();

      s.requestTicket(expected['id'] as String,
          expected['purpose'] as String);
      expect(s.sent.single.body, expected);

      s.receive(grant);
      expect(s.tickets['upload:dataset'], grant);
    });

    test('an event frame matches the transcript shape', () {
      final expected = frames(transcript('button-event'), 'in').first;
      final s = GlintySession();
      s.sendEvent(expected['id'] as String);

      expect(s.sent.single.body, expected);
    });

    test('a refused ticket lands as a transfer error, not a grant', () {
      // The refusal answers on the ticket channel. As an `error`
      // frame this client stored it against an output id, and a
      // download_button is not an output, so it was invisible.
      final refusal = frames(transcript('ticket-refused'), 'out').first;
      final s = GlintySession();
      String? got;
      s.awaitTicket(refusal['id'] as String, 'download', (r) => got = r);
      s.receive(refusal);

      expect(got, refusal['error']);
      expect(s.tickets, isEmpty);
      expect(s.errors, isEmpty,
          reason: 'a refused transfer is not a render failure');
    });

    test('a valued event frame matches the transcript shape', () {
      // The other half of the event shape: a press from a list row
      // carries which row. A client that drops the value reports a
      // press the server cannot place.
      final expected = frames(transcript('valued-event'), 'in').first;
      final s = GlintySession();
      s.sendEvent(expected['id'] as String,
          value: expected['value'] as String);

      expect(s.sent.single.body, expected);
    });

    test('a measure frame matches the transcript shape', () {
      final expected = frames(transcript('measure-then-image'), 'in').first;
      final s = GlintySession();
      s.sendMeasure(expected['id'] as String, expected['width'] as int,
          expected['height'] as int, dpr: expected['dpr'] as num);

      expect(s.sent.single.body, expected);
    });

    test('an audio value keeps what it is, not only where it is', () {
      // This client cannot play it -- audio_output is a named
      // refusal until it grows a platform player -- but the value
      // has to survive intact, because the type is the whole reason
      // a native client can hand it to one. The browser sniffs the
      // bytes and never needed the field, which is exactly how it
      // went missing from render_audio() for so long.
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive(serverFrame('audio-output', 'output'));

      expect(s.refused, isFalse);
      expect(s.kinds['player'], 'audio');
      final value = s.values['player'] as Map<String, dynamic>;
      expect(value['src'], startsWith('data:audio/wav'));
      expect(value['mime'], 'audio/wav');
      expect(value['duration'], 1.5);
    });

    test('a ui-kind output stores its tree without being drawable', () {
      // ui_output is on this client's unsupported list until stage 2
      // of its own growth; the session must still accept the value
      // rather than dying on it.
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive(serverFrame('event-then-ui', 'output'));

      expect(s.refused, isFalse);
      expect(s.values['panel'], isA<Map<String, dynamic>>());
    });

    test('input_update is ignored until this client renders inputs live',
        () {
      final s = GlintySession();
      s.receive(serverFrame('hello-welcome', 'welcome'));
      s.receive(serverFrame('input-update', 'input_update'));

      expect(s.refused, isFalse);
      expect(s.ui, isNotNull);
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
