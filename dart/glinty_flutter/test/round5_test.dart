/// Codex round 5: what the client dropped on the floor.
///
/// Every test here drives a real [GlintyApp] over a fake socket and
/// asserts on what a person would see, because each of these bugs
/// passed a unit test that inspected state instead. The pattern the
/// round found: the session held enough to be right and the renderer
/// never asked.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';
import 'package:web_socket/web_socket.dart';

import 'transcript_data.dart';

class FakeSocket implements WebSocket {
  final List<Map<String, dynamic>> sent = [];
  final _events = StreamController<WebSocketEvent>();
  bool closed = false;

  void deliver(Map<String, dynamic> msg) =>
      _events.add(TextDataReceived(jsonEncode(msg)));

  /// The wire going away under the app, rather than either side
  /// closing it.
  void drop() {
    if (closed) return;
    closed = true;
    _events.add(CloseReceived(1006, 'gone'));
    unawaited(_events.close());
  }

  @override
  void sendText(String s) {
    if (closed) throw WebSocketConnectionClosed();
    sent.add(jsonDecode(s) as Map<String, dynamic>);
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!closed) {
      closed = true;
      unawaited(_events.close());
    }
  }

  @override
  void sendBytes(_) => throw UnimplementedError();

  @override
  String get protocol => '';
}

Map<String, dynamic> welcomeOf(Object tree, String rev) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': rev,
      'ui': tree,
    };

/// Boots an app over a fresh socket and returns it, welcomed.
Future<FakeSocket> boot(WidgetTester tester, Object tree, String rev) async {
  late FakeSocket socket;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: GlintyApp(
        url: Uri.parse('ws://x/ws'),
        open: (_) async => socket = FakeSocket(),
      ),
    ),
  ));
  await tester.pump();
  socket.deliver(welcomeOf(tree, rev));
  await tester.pumpAndSettle();
  return socket;
}

final outputTree = {
  'component': 'page',
  'title': 'Outputs',
  'children': [
    {'component': 'text', 'value': 'still here', 'variant': 'normal'},
    {'component': 'text_output', 'id': 'msg'},
    {'component': 'verbatim_output', 'id': 'log'},
  ],
};

final multiTree = {
  'component': 'page',
  'title': 'Multi',
  'children': [
    {
      'component': 'select_input',
      'id': 'tags',
      'label': 'Tags:',
      'multiple': true,
      'emit': 'settle',
      'choices': [
        {'value': 'a', 'label': 'Alpha'},
        {'value': 'b', 'label': 'Beta'},
        {'value': 'c', 'label': 'Gamma'},
      ],
    },
  ],
};

final settleSliderTree = {
  'component': 'page',
  'title': 'Slider',
  'children': [
    {
      'component': 'slider_input',
      'id': 'n',
      'label': 'N:',
      'min': 0.0,
      'max': 10.0,
      'value': 5.0,
      'step': 1.0,
      'emit': 'settle',
    },
  ],
};

final settleTextTree = {
  'component': 'page',
  'title': 'Text',
  'children': [
    {
      'component': 'text_input',
      'id': 'note',
      'label': 'Note:',
      'value': '',
      'emit': 'settle',
    },
  ],
};

final buttonTree = {
  'component': 'page',
  'title': 'Buttons',
  'children': [
    {'component': 'button', 'id': 'run', 'label': 'Run',
      'variant': 'primary'},
  ],
};

/// A slot the server fills with a component tree later. How both apps
/// build everything that depends on state.
final uiSlotTree = {
  'component': 'page',
  'title': 'Dynamic',
  'children': [
    {'component': 'text', 'value': 'the static part', 'variant': 'normal'},
    {'component': 'ui_output', 'id': 'panel'},
  ],
};

/// A section the user opens themselves: state no frame carries, so
/// losing it can only come from the client throwing the tree away.
final collapsedTree = {
  'component': 'page',
  'title': 'Collapse',
  'children': [
    {
      'component': 'collapse',
      'id': 'details',
      'title': 'Details',
      'open': false,
      'children': [
        {'component': 'text', 'value': 'the fine print', 'variant': 'normal'},
      ],
    },
  ],
};

final liveTextTree = {
  'component': 'page',
  'title': 'Text',
  'children': [
    {
      'component': 'text_input',
      'id': 'note',
      'label': 'Note:',
      'value': '',
      'emit': 'live',
    },
  ],
};

void main() {
  _round7();
  _v31();
  _ticketRefusals();
  group('outputs carry their kind and their errors', () {
    testWidgets('a kind this slot cannot draw is named, not stringified',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');

      // The server answers a text_output with an image value. It is
      // entitled to: the kind field exists precisely so a client can
      // tell. Dropping the kind left the slot calling toString() on
      // the payload map.
      socket.deliver({
        'type': 'output',
        'id': 'msg',
        'kind': 'image',
        'value': {'src': 'data:image/png;base64,iVBORw0KGgo', 'alt': 'plot'},
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot display image'), findsOneWidget);
      expect(find.textContaining('base64'), findsNothing,
          reason: 'stringifying the payload is not displaying it');
    });

    testWidgets('a matching kind still draws', (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'output',
        'id': 'msg',
        'kind': 'text',
        'value': 'all good',
      });
      await tester.pumpAndSettle();
      expect(find.text('all good'), findsOneWidget);
    });

    testWidgets('a render error shows its message', (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'output',
        'id': 'log',
        'kind': 'text',
        'value': 'stale output',
      });
      await tester.pumpAndSettle();
      expect(find.text('stale output'), findsOneWidget);

      socket.deliver({
        'type': 'error',
        'id': 'log',
        'message': 'object "x" not found',
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('object "x" not found'), findsOneWidget);
      expect(find.text('stale output'), findsNothing,
          reason: 'the value is stale; the error is current');
    });

    testWidgets('a later good value clears the error', (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver(
          {'type': 'error', 'id': 'msg', 'message': 'boom'});
      await tester.pumpAndSettle();
      expect(find.textContaining('boom'), findsOneWidget);

      socket.deliver({
        'type': 'output',
        'id': 'msg',
        'kind': 'text',
        'value': 'recovered',
      });
      await tester.pumpAndSettle();
      expect(find.text('recovered'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('an id-less error after welcome is not a refusal',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({'type': 'error', 'message': 'transient'});
      await tester.pumpAndSettle();
      // still the app, not the refusal screen
      expect(find.text('still here'), findsOneWidget);
    });
  });

  group('round 6: frames this client used to drop', () {
    testWidgets('an unrenderable kind is named even with no value',
        (tester) async {
      // Whether a slot can draw a kind is a fact about the kind and
      // the slot, not about what arrived. Gating the refusal on a
      // non-null value let an image output with a null value render
      // as an ordinary empty slot -- this client could not have drawn
      // it either way, and said nothing.
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'output',
        'id': 'msg',
        'kind': 'image',
        'value': null,
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot display image'), findsOneWidget);
    });

    testWidgets('work the app could not send is said out loud',
        (tester) async {
      // Counting a dropped interaction is only half of it. A count
      // nobody draws is the same silence, one layer further in.
      final sockets = <FakeSocket>[];
      final conn = GlintyConnection(
        url: Uri.parse('ws://x/ws'),
        // long enough that the retry never fires mid-test
        retryBase: const Duration(seconds: 30),
        retryCap: const Duration(seconds: 30),
        open: (_) async {
          sockets.add(FakeSocket());
          return sockets.last;
        },
      );
      unawaited(conn.start());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: conn,
            builder: (context, _) => GlintyView(connection: conn),
          ),
        ),
      ));
      await tester.pump();
      sockets.last.deliver(welcomeOf(buttonTree, 'rd'));
      await tester.pumpAndSettle();

      sockets.last.drop();
      await tester.pump();
      expect(find.textContaining('could not be sent'), findsNothing);

      // fill the queue past its cap with distinct ids, then one more
      for (var i = 0; i < 65; i++) {
        conn.session.sendInput('field$i', i);
      }
      await tester.pump();

      expect(find.textContaining('1 thing you did could not be sent'),
          findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.pump();
      expect(find.textContaining('could not be sent'), findsNothing,
          reason: 'dismissing is the user saying they have read it');
      conn.dispose();
    });

    testWidgets('a refusal says what went unsent with it', (tester) async {
      // The refusal screen replaces the app, and the notice the
      // running app draws goes with it. So the count has to be said
      // here or not at all -- and this is the case where the work is
      // most certainly lost.
      final sockets = <FakeSocket>[];
      final conn = GlintyConnection(
        url: Uri.parse('ws://x/ws'),
        retryBase: const Duration(milliseconds: 10),
        retryCap: const Duration(milliseconds: 20),
        open: (_) async {
          sockets.add(FakeSocket());
          return sockets.last;
        },
      );
      unawaited(conn.start());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: conn,
            builder: (context, _) => GlintyView(connection: conn),
          ),
        ),
      ));
      await tester.pump();
      sockets.last.deliver(welcomeOf(buttonTree, 'rr'));
      await tester.pumpAndSettle();

      // typed while the wire is down; it queues for the next socket
      sockets.last.drop();
      await tester.pump();
      conn.session.sendInput('note', 'half a thought');

      // and the next socket says no, so it is never going out
      await tester.pump(const Duration(milliseconds: 50));
      expect(sockets, hasLength(2));
      sockets.last.deliver({'type': 'error', 'message': 'that token expired'});
      await tester.pumpAndSettle();

      expect(find.text('Connection refused'), findsOneWidget);
      expect(find.textContaining('that token expired'), findsOneWidget);
      expect(find.textContaining('1 thing you did was never sent'),
          findsOneWidget);
      conn.dispose();
    });

    testWidgets('and so does giving up on the connection', (tester) async {
      // The other way this screen is reached: the retries ran out
      // rather than the server saying no. Same loss, same screen,
      // and the count has to survive both routes into _stop().
      final sockets = <FakeSocket>[];
      final conn = GlintyConnection(
        url: Uri.parse('ws://x/ws'),
        maxRetries: 1,
        retryBase: const Duration(milliseconds: 10),
        retryCap: const Duration(milliseconds: 20),
        open: (_) async {
          sockets.add(FakeSocket());
          return sockets.last;
        },
      );
      unawaited(conn.start());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: conn,
            builder: (context, _) => GlintyView(connection: conn),
          ),
        ),
      ));
      await tester.pump();
      sockets.last.deliver(welcomeOf(buttonTree, 'rg'));
      await tester.pumpAndSettle();

      sockets.last.drop();
      await tester.pump();
      conn.session.sendInput('note', 'half a thought');
      conn.session.sendEvent('save');

      // the last retry connects and dies without a welcome
      await tester.pump(const Duration(milliseconds: 50));
      expect(sockets, hasLength(2));
      sockets.last.drop();
      await tester.pumpAndSettle();

      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.textContaining('2 things you did were never sent'),
          findsOneWidget);
      conn.dispose();
    });

    testWidgets('a ui output builds into its slot, bindings and all',
        (tester) async {
      // render_ui() is how both apps build everything that depends on
      // state: cornfab's history list, voice picker, model section and
      // both container panels are all ui_output. Refused, most of the
      // app was a placeholder.
      final socket = await boot(tester, uiSlotTree, 'ru');
      expect(find.textContaining('unsupported'), findsNothing);

      socket.deliver({
        'type': 'output',
        'id': 'panel',
        'kind': 'ui',
        'value': {
          'component': 'column',
          'children': [
            {'component': 'text', 'value': 'from the server',
              'variant': 'normal'},
            {'component': 'button', 'id': 'go', 'label': 'Run',
              'variant': 'primary', 'value': 'row-7'},
          ],
        },
      });
      await tester.pumpAndSettle();

      expect(find.text('from the server'), findsOneWidget);
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      final events = socket.sent.where((m) => m['type'] == 'event').toList();
      expect(events, hasLength(1));
      expect(events.single['id'], 'go');
      expect(events.single['value'], 'row-7',
          reason: 'a button that arrived late is still a button');
    });

    testWidgets('a control that arrives in a slot has a value to draw',
        (tester) async {
      // Server-side these inputs are NULL until touched, which is what
      // render_ui() documents. The client still has to draw something,
      // and a select that refuses to hold the value its own tree
      // declares renders empty next to a tree that plainly says which
      // choice is selected.
      final socket = await boot(tester, uiSlotTree, 'ru2');
      socket.deliver({
        'type': 'output',
        'id': 'panel',
        'kind': 'ui',
        'value': {
          'component': 'select_input',
          'id': 'voice',
          'label': 'Voice:',
          'emit': 'settle',
          'selected': 'nova',
          'choices': [
            {'value': 'alloy', 'label': 'Alloy'},
            {'value': 'nova', 'label': 'Nova'},
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('Nova'), findsOneWidget);
    });

    testWidgets('an audio value reaches the app that can play it',
        (tester) async {
      // Playing audio needs a platform plugin this package will not
      // take on, so it goes where onLink and onDownload go: glinty
      // says where the player belongs and what to play, the app says
      // how.
      final played = <GlintyAudioSource>[];
      late FakeSocket socket;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
            audioBuilder: (context, source) {
              played.add(source);
              return const Text('player');
            },
          ),
        ),
      ));
      await tester.pump();
      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Audio',
        'children': [
          {'component': 'audio_output', 'id': 'player', 'controls': true,
            'autoplay': true},
        ],
      }, 'ra'));
      await tester.pumpAndSettle();
      expect(played, isEmpty, reason: 'nothing to play yet');

      socket.deliver(frames(transcript('audio-output'), 'out').first);
      await tester.pumpAndSettle();

      expect(find.text('player'), findsOneWidget);
      expect(played, hasLength(1));
      expect(played.single.src.scheme, 'data');
      expect(played.single.mime, 'audio/wav');
      expect(played.single.duration, 1.5);
      expect(played.single.autoplay, isTrue);
    });

    testWidgets('a mixed-case data URI is decoded, not fetched',
        (tester) async {
      // A URI scheme is case-insensitive, and R accepts DATA: for
      // that reason. Matched by prefix, an image with one skipped the
      // decode branch and the http branch and ended up in
      // Image.network -- asking the network for a URI that carries
      // its own bytes.
      final socket = await boot(tester, {
        'component': 'page',
        'title': 'Image',
        'children': [
          {'component': 'image', 'alt': 'dot',
            'src': 'DATA:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'},
        ],
      }, 'rimg');
      await tester.pumpAndSettle();
      expect(socket.sent, isNotEmpty);

      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<MemoryImage>(),
          reason: 'a data URI carries its own bytes');
    });

    testWidgets('an audio src is read by scheme, not by prefix',
        (tester) async {
      // The audio path happened to survive prefix matching, because
      // resolving an absolute reference against a base returns it
      // unchanged -- the fallback was accidentally right. Reading the
      // scheme makes that deliberate rather than lucky.
      final played = <GlintyAudioSource>[];
      late FakeSocket socket;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
            audioBuilder: (context, source) {
              played.add(source);
              return const Text('player');
            },
          ),
        ),
      ));
      await tester.pump();
      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Audio',
        'children': [{'component': 'audio_output', 'id': 'player'}],
      }, 'ra4'));
      await tester.pumpAndSettle();
      socket.deliver({
        'type': 'output', 'id': 'player', 'kind': 'audio',
        'value': {'src': 'DATA:audio/wav;base64,UklGRg', 'mime': 'audio/wav'},
      });
      await tester.pumpAndSettle();

      expect(played.single.src.scheme, 'data');
    });

    testWidgets('hello does not claim audio without a player wired',
        (tester) async {
      // A component this client only draws a placeholder for is not
      // one it renders, and hello is where the server is told. The
      // same rule the download feature already follows.
      late FakeSocket bare;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => bare = FakeSocket(),
          ),
        ),
      ));
      await tester.pump();
      final claimed = bare.sent.single['components'] as List;
      expect(claimed, isNot(contains('audio_output')));
      expect(claimed, contains('ui_output'),
          reason: 'the ones it does draw are still claimed');

      // Wiring one in is a different claim, so it is a different
      // connection. Deliberately the same widget position and no key:
      // this goes through didUpdateWidget, which is where an app that
      // wires its player after a login would actually hit it. Keyed,
      // the test would build a fresh GlintyApp and never exercise
      // that path at all.
      final sockets = <FakeSocket>[bare];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async {
              sockets.add(FakeSocket());
              return sockets.last;
            },
            audioBuilder: (context, source) => const Text('player'),
          ),
        ),
      ));
      await tester.pump();
      expect(sockets, hasLength(2), reason: 'a new claim is a new hello');
      expect(sockets.last.sent.single['components'],
          contains('audio_output'));

      // and back out again
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async {
              sockets.add(FakeSocket());
              return sockets.last;
            },
          ),
        ),
      ));
      await tester.pump();
      expect(sockets, hasLength(3));
      expect(sockets.last.sent.single['components'],
          isNot(contains('audio_output')));
    });

    testWidgets('a rebuilt player closure is the one that gets called',
        (tester) async {
      // Same capability, new closure: not a reconnect, but the slot
      // has to reach the one the app is holding now. A builder
      // captured at connect time would go on calling into a closure
      // over state the app has already moved past.
      late FakeSocket socket;
      final calls = <String>[];
      Widget appWith(String tag) => MaterialApp(
            home: Scaffold(
              body: GlintyApp(
                url: Uri.parse('ws://x/ws'),
                open: (_) async => socket = FakeSocket(),
                audioBuilder: (context, source) {
                  calls.add(tag);
                  return Text('player $tag');
                },
              ),
            ),
          );

      await tester.pumpWidget(appWith('first'));
      await tester.pump();
      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Audio',
        'children': [{'component': 'audio_output', 'id': 'player'}],
      }, 'rb'));
      await tester.pumpAndSettle();
      socket.deliver(frames(transcript('audio-output'), 'out').first);
      await tester.pumpAndSettle();
      expect(calls, contains('first'));

      calls.clear();
      await tester.pumpWidget(appWith('second'));
      await tester.pumpAndSettle();

      expect(calls, isNotEmpty);
      expect(calls, everyElement('second'),
          reason: 'the stale closure is not the app any more');
      expect(find.text('player second'), findsOneWidget);
    });

    testWidgets('a file input picks, then asks for its ticket',
        (tester) async {
      // Ordering is the whole reason target() is a callback: a ticket
      // lives 30 seconds and a picker dialog lasts as long as the
      // user does, so one minted before the dialog opened would
      // routinely expire in front of them. The browser asks in the
      // same order.
      late FakeSocket socket;
      final asked = <String>[];
      Uri? target;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://example.test:8080/ws'),
            open: (_) async => socket = FakeSocket(),
            onUpload: (context, request) async {
              asked.addAll(request.accept);
              // the "dialog": nothing is requested until it returns
              await Future<void>.delayed(Duration.zero);
              target = await request.target();
            },
          ),
        ),
      ));
      await tester.pump();
      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Upload',
        'children': [
          {'component': 'file_input', 'id': 'voice_upload',
            'label': 'Add Voice', 'accept': ['.wav', '.mp3'],
            'multiple': false},
        ],
      }, 'rf'));
      await tester.pumpAndSettle();

      expect(socket.sent.where((m) => m['type'] == 'ticket'), isEmpty,
          reason: 'nothing asked for yet');
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(asked, ['.wav', '.mp3']);

      final ticketFrame =
          socket.sent.lastWhere((m) => m['type'] == 'ticket');
      expect(ticketFrame['purpose'], 'upload');
      expect(ticketFrame['id'], 'voice_upload');

      socket.deliver({
        'type': 'ticket', 'id': 'voice_upload', 'purpose': 'upload',
        'token': 'tk_up', 'expires': 30,
      });
      await tester.pumpAndSettle();

      expect(target.toString(),
          'http://example.test:8080/upload?ticket=tk_up');
    });

    testWidgets('a refused upload gives the control back and says why',
        (tester) async {
      late FakeSocket socket;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
            // lets the refusal through, which is the point: a handler
            // that only wants the happy path writes no error handling
            onUpload: (context, request) => request.target(),
          ),
        ),
      ));
      await tester.pump();
      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Upload',
        'children': [{'component': 'file_input', 'id': 'voice_upload'}],
      }, 'rf2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose file'));
      await tester.pump();
      expect(
          tester
              .widget<OutlinedButton>(find.byType(OutlinedButton))
              .onPressed,
          isNull,
          reason: 'unpressable while it works');

      socket.deliver({
        'type': 'ticket', 'id': 'voice_upload', 'purpose': 'upload',
        'error': 'too many pending transfers',
      });
      await tester.pumpAndSettle();

      expect(find.text('too many pending transfers'), findsOneWidget);
      expect(
          tester
              .widget<OutlinedButton>(find.byType(OutlinedButton))
              .onPressed,
          isNotNull,
          reason: 'and given back rather than left dead');
    });

    testWidgets('a file input with no handler says so, and is not claimed',
        (tester) async {
      late FakeSocket socket;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
          ),
        ),
      ));
      await tester.pump();
      final hello = socket.sent.single;
      expect(hello['components'], isNot(contains('file_input')));
      expect(hello['features'], isNot(contains('upload')));

      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Upload',
        'children': [{'component': 'file_input', 'id': 'voice_upload'}],
      }, 'rf3'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no file picker wired'), findsOneWidget);
    });

    testWidgets('an audio slot with no player says so', (tester) async {
      // Not an empty box. A slot that draws nothing is
      // indistinguishable from audio that failed to play, and the
      // gap is the embedder's to close.
      final socket = await boot(tester, {
        'component': 'page',
        'title': 'Audio',
        'children': [{'component': 'audio_output', 'id': 'player'}],
      }, 'ra2');
      socket.deliver(frames(transcript('audio-output'), 'out').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('no audio player wired'), findsOneWidget);
    });

    testWidgets('a relative audio src resolves against the server',
        (tester) async {
      // The same rule an image follows: only the connection knows the
      // address the app is served from.
      final played = <GlintyAudioSource>[];
      late FakeSocket socket;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://example.test:8080/ws'),
            open: (_) async => socket = FakeSocket(),
            audioBuilder: (context, source) {
              played.add(source);
              return const Text('player');
            },
          ),
        ),
      ));
      await tester.pump();
      socket.deliver(welcomeOf({
        'component': 'page',
        'title': 'Audio',
        'children': [{'component': 'audio_output', 'id': 'player'}],
      }, 'ra3'));
      await tester.pumpAndSettle();
      socket.deliver({
        'type': 'output', 'id': 'player', 'kind': 'audio',
        'value': {'src': '/static/chime.wav', 'mime': 'audio/wav'},
      });
      await tester.pumpAndSettle();

      expect(played.single.src.toString(),
          'http://example.test:8080/static/chime.wav');
      expect(played.single.duration, isNull,
          reason: 'the server did not say, so neither does this');
      expect(played.single.controls, isFalse,
          reason: 'and the component did not ask for them');
    });

    testWidgets('the app still fills the box it was given', (tester) async {
      // Making the Stack unconditional put a widget between the app
      // and its parent, and a Stack loosens the constraints it passes
      // down by default. An app that filled its window would start
      // sizing to its content, so a background would stop covering
      // the screen and a modal scrim with it. passthrough is what
      // being a direct child meant.
      late FakeSocket socket;
      await tester.pumpWidget(MaterialApp(
        home: SizedBox.expand(
          child: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
          ),
        ),
      ));
      await tester.pump();
      // Short content, so a stack that shrink-wrapped would be
      // obviously smaller than the box rather than accidentally right.
      socket.deliver(welcomeOf(buttonTree, 'rfill'));
      await tester.pumpAndSettle();

      expect(
          tester.getSize(find.descendant(
              of: find.byType(GlintyView), matching: find.byType(Column))),
          const Size(800, 600),
          reason: "the page sizes to the box, as a direct child would");
    });

    testWidgets('a dialog opening does not reset the app behind it',
        (tester) async {
      // An overlay is drawn *above* the app, so nothing about the app
      // changed. But wrapping it in a Stack only once a layer exists
      // moves every widget in it to a new place in the element tree,
      // and Flutter answers a move by throwing the old elements away
      // -- taking expanded sections, scroll positions and transfer
      // refusals with it. What the user opened is theirs, and the
      // server never said to close it.
      final socket = await boot(tester, collapsedTree, 'rc');
      expect(find.text('the fine print'), findsNothing);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('the fine print'), findsOneWidget);

      socket.deliver({
        'type': 'modal',
        'action': 'show',
        'title': 'Are you sure?',
        'body': [
          {'component': 'text', 'value': 'It cannot be undone.',
            'variant': 'normal'}
        ],
        'easy_close': true,
      });
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('the fine print'), findsOneWidget,
          reason: 'the dialog is above the app, not instead of it');

      socket.deliver({'type': 'modal', 'action': 'hide'});
      await tester.pumpAndSettle();
      expect(find.text('the fine print'), findsOneWidget,
          reason: 'and closing it is not a change to the app either');
    });

    testWidgets('show_modal draws a dialog, hide takes it away',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'modal',
        'action': 'show',
        'title': 'Download the model?',
        'body': [
          {'component': 'text', 'value': 'It is 1.4 GB.', 'variant': 'normal'}
        ],
        'footer': {
          'component': 'button', 'id': 'confirm', 'label': 'Download',
          'variant': 'primary'
        },
        'easy_close': false,
      });
      await tester.pumpAndSettle();

      expect(find.text('Download the model?'), findsOneWidget);
      expect(find.text('It is 1.4 GB.'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);

      // and the footer button is live: a dialog that asks a question
      // and cannot take the answer is worse than no dialog
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(socket.sent.last['type'], 'event');
      expect(socket.sent.last['id'], 'confirm');

      socket.deliver({'type': 'modal', 'action': 'hide'});
      await tester.pumpAndSettle();
      expect(find.text('Download the model?'), findsNothing);
    });

    testWidgets('a modal blocks the tree behind it', (tester) async {
      final socket = await boot(tester, buttonTree, 'rb');
      socket.deliver({
        'type': 'modal',
        'action': 'show',
        'title': 'Busy',
        'body': <dynamic>[],
        'easy_close': false,
      });
      await tester.pumpAndSettle();

      final before = socket.sent.length;
      await tester.tap(find.text('Run'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(socket.sent.length, before,
          reason: 'modal means modal -- a scrim that lets taps through '
              'is a picture of a dialog');
    });

    testWidgets('with_progress draws a report, and hide removes it',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'progress',
        'action': 'show',
        'id': 'p1',
        'message': 'Transcribing',
        'detail': 'chunk 1 of 8',
        'value': 0.125,
      });
      await tester.pumpAndSettle();
      expect(find.text('Transcribing'), findsOneWidget);
      expect(find.text('chunk 1 of 8'), findsOneWidget);
      var bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.125, 1e-9));

      socket.deliver({
        'type': 'progress',
        'action': 'update',
        'id': 'p1',
        'message': 'Transcribing',
        'detail': 'chunk 8 of 8',
        'value': 1.0,
      });
      await tester.pumpAndSettle();
      expect(find.text('chunk 8 of 8'), findsOneWidget);
      expect(find.text('chunk 1 of 8'), findsNothing);

      socket.deliver({'type': 'progress', 'action': 'hide', 'id': 'p1'});
      await tester.pumpAndSettle();
      expect(find.text('Transcribing'), findsNothing);
    });

    testWidgets('a progress report with no value is indeterminate',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'progress', 'action': 'show', 'id': 'p1',
        'message': 'Working', 'value': null,
      });
      // pump, not pumpAndSettle: an indeterminate bar animates
      // forever by design, so "settled" never arrives. That it does
      // not settle is itself the assertion behind this one.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, isNull,
          reason: 'pinning an unknown fraction to zero reports stalled');
    });

    testWidgets('two progress reports stack rather than replace',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({'type': 'progress', 'action': 'show', 'id': 'a',
        'message': 'Outer', 'value': 0.5});
      socket.deliver({'type': 'progress', 'action': 'show', 'id': 'b',
        'message': 'Inner', 'value': 0.5});
      await tester.pumpAndSettle();
      expect(find.text('Outer'), findsOneWidget);
      expect(find.text('Inner'), findsOneWidget);

      socket.deliver({'type': 'progress', 'action': 'hide', 'id': 'b'});
      await tester.pumpAndSettle();
      expect(find.text('Outer'), findsOneWidget,
          reason: 'nested with_progress closes inside-out');
      expect(find.text('Inner'), findsNothing);
    });

    testWidgets('a custom message with no handler says so on screen',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({
        'type': 'custom', 'handler': 'startRecording', 'value': {'ms': 30},
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('startRecording'), findsOneWidget,
          reason: 'an app whose JavaScript half was never ported looks '
              'like it works and quietly does half of what it says');
    });

    testWidgets('a wired custom handler gets the value and no notice',
        (tester) async {
      late FakeSocket socket;
      dynamic received;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
            customHandlers: {'ping': (v) => received = v},
          ),
        ),
      ));
      await tester.pump();
      socket.deliver(welcomeOf(outputTree, 'ro'));
      await tester.pumpAndSettle();

      socket.deliver(
          {'type': 'custom', 'handler': 'ping', 'value': 42});
      await tester.pumpAndSettle();
      expect(received, 42);
      expect(find.textContaining('no handler'), findsNothing);
    });

    testWidgets('a refused resume clears dialogs and progress',
        (tester) async {
      final socket = await boot(tester, outputTree, 'ro');
      socket.deliver({'type': 'modal', 'action': 'show', 'title': 'Old',
        'body': <dynamic>[], 'easy_close': false});
      socket.deliver({'type': 'progress', 'action': 'show', 'id': 'p',
        'message': 'Old work', 'value': 0.5});
      await tester.pumpAndSettle();
      expect(find.text('Old'), findsOneWidget);

      // the server hands back a different session
      socket.deliver({
        'type': 'welcome', 'session': 's2', 'protocol': 3,
        'ui_revision': 'ro', 'ui': outputTree, 'resumed': false,
      });
      await tester.pumpAndSettle();

      expect(find.text('Old'), findsNothing,
          reason: 'that dialog belonged to a session that is gone');
      expect(find.text('Old work'), findsNothing);
    });
  });

  group('inputs', () {
    testWidgets('a multiple select sends a list, and can hold two',
        (tester) async {
      final socket = await boot(tester, multiTree, 'rm');
      final before = socket.sent.length;

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      final frames = socket.sent.skip(before).toList();
      expect(frames.length, 2);
      // A single-select lowering would have replaced, not added --
      // the second frame would read ['c'].
      expect(frames.first['value'], ['a']);
      expect(frames.last['value'], ['a', 'c']);

      // and tapping a selected one removes it
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(socket.sent.last['value'], ['c']);
    });

    testWidgets('a settle slider sends once, on release', (tester) async {
      final socket = await boot(tester, settleSliderTree, 'rs');
      final before = socket.sent.length;

      // A stepped gesture: many onChanged calls, one onChangeEnd.
      // emit=settle means one frame, at the end. Sending each
      // intermediate value is what "live" means, and the server told
      // us it wants the other thing.
      final g = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('n'))));
      for (var i = 0; i < 4; i++) {
        await g.moveBy(const Offset(60, 0));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();

      final frames = socket.sent.skip(before).toList();
      expect(frames.length, 1,
          reason: 'settle means one frame per gesture, not per pixel');
      expect(frames.single['type'], 'input');
      expect(frames.single['id'], 'n');

      // and the thumb still tracked the finger while it moved: a
      // settle control that reports nothing must still redraw, or
      // the slider sits at its old value under a moving thumb
      final slider = tester.widget<Slider>(find.byKey(const Key('n')));
      expect(slider.value, greaterThan(5.0));
    });

    testWidgets('a live slider sends during the drag', (tester) async {
      final live = {
        'component': 'page',
        'title': 'Slider',
        'children': [
          {
            'component': 'slider_input',
            'id': 'n',
            'label': 'N:',
            'min': 0.0,
            'max': 10.0,
            'value': 5.0,
            'step': 1.0,
            'emit': 'live',
          },
        ],
      };
      final socket = await boot(tester, live, 'rl');
      final before = socket.sent.length;
      // A stepped gesture, not tester.drag: one drag call moves the
      // pointer once, which cannot tell "streams" from "reports
      // when the finger lifts".
      final g = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('n'))));
      for (var i = 0; i < 4; i++) {
        await g.moveBy(const Offset(60, 0));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(socket.sent.skip(before).length, greaterThan(1),
          reason: 'live is the mode that streams');
    });

    testWidgets('a settle text field sends on blur', (tester) async {
      final socket = await boot(tester, settleTextTree, 'rt');
      final before = socket.sent.length;

      await tester.tap(find.byKey(const Key('note')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note')), 'hello');
      await tester.pumpAndSettle();

      expect(socket.sent.skip(before).length, 0,
          reason: 'settle does not send per keystroke');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final frames = socket.sent.skip(before).toList();
      expect(frames.length, 1,
          reason: 'a settle field that never sends on blur only sends '
              'if the user happens to press enter -- otherwise the '
              'typing is silently discarded');
      expect(frames.single['id'], 'note');
      expect(frames.single['value'], 'hello');
    });

    testWidgets('blur with no edit sends nothing', (tester) async {
      final socket = await boot(tester, settleTextTree, 'rt');
      final before = socket.sent.length;
      await tester.tap(find.byKey(const Key('note')));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(socket.sent.skip(before).length, 0,
          reason: 'focus alone is not a change');
    });

    testWidgets('an identical push after a refused one still lands',
        (tester) async {
      // A LIVE field on purpose. Under settle the blur report writes
      // the local text back through the store, which moves the value
      // and lets a naive "did the value change" check work by
      // accident. Live is where the store is left holding the
      // server's value while the field shows the user's, and where
      // comparing values instead of counting pushes actually loses
      // the second one.
      final socket = await boot(tester, liveTextTree, 'rv');

      await tester.tap(find.byKey(const Key('note')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note')), 'mine');
      await tester.pumpAndSettle();

      // refused: the field is focused
      socket.deliver(
          {'type': 'input_update', 'id': 'note', 'value': 'theirs'});
      await tester.pumpAndSettle();
      expect(find.text('mine'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('mine'), findsOneWidget,
          reason: 'a refused push must not land on the next rebuild '
              'either -- that is deferring, not refusing');

      // The same value again, now that focus is gone. This is the
      // server resyncing a client it can see has drifted. Tracking
      // "the last value I saw" makes it a no-op: the field keeps
      // showing 'mine' forever while the server believes 'theirs'.
      socket.deliver(
          {'type': 'input_update', 'id': 'note', 'value': 'theirs'});
      await tester.pumpAndSettle();
      expect(find.text('theirs'), findsOneWidget,
          reason: 'a refused push is not a delivered one');
    });
  });
}

// --- Codex round 7: three claims that were not true ---

final plotTree = {
  'component': 'page',
  'title': 'Plots',
  'children': [
    {'component': 'plot_output', 'id': 'scatter'},
  ],
};

final fixedPlotTree = {
  'component': 'page',
  'title': 'Plots',
  'children': [
    {'component': 'plot_output', 'id': 'fixed', 'width': 400,
      'height': 300},
  ],
};

/// A 1x1 transparent PNG, as the server would send it.
const pngDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAf'
    'FcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void _round7() {
  testWidgets('a responsive plot reports its box, once per size',
      (tester) async {
    final socket = await boot(tester, plotTree, 'rp');

    final measures = socket.sent.where((m) => m['type'] == 'measure');
    expect(measures, hasLength(1),
        reason: 'hello declares the measure feature; a client that '
            'declares it and never measures has told the server '
            'something untrue');
    final m = measures.single;
    expect(m['id'], 'scatter');
    expect(m['width'], greaterThan(0));
    expect(m['height'], greaterThan(0));
    expect(m['dpr'], isNotNull);

    // A rebuild at the same size says nothing. Layout runs every
    // frame; an undeduplicated report would put one measure on the
    // wire per frame, and the plot coming back would relayout and
    // measure again -- a loop that never settles.
    socket.deliver({'type': 'output', 'id': 'scatter', 'kind': 'image',
      'value': {'src': pngDataUri, 'alt': 'a plot'}});
    await tester.pumpAndSettle();
    expect(socket.sent.where((f) => f['type'] == 'measure'), hasLength(1));

    // and the value it got back is drawn
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a resize reports the new box', (tester) async {
    final socket = await boot(tester, plotTree, 'rp');
    expect(socket.sent.where((f) => f['type'] == 'measure'), hasLength(1));

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final measures =
        socket.sent.where((f) => f['type'] == 'measure').toList();
    expect(measures.length, greaterThan(1),
        reason: 'a box that changed is news');
    expect(measures.last['width'], isNot(measures.first['width']));
  });

  testWidgets('a fixed-size plot still reports, for the dpr',
      (tester) async {
    // Size is only half of a measurement. The other half is the
    // device pixel ratio, which the app cannot know and the server
    // needs: a 400x300 plot that never reports is rasterized at
    // 400x300 and drawn on a 2x screen at half the resolution it
    // should be. The app said how big, not how sharp. The browser
    // walks every img.g-plot-output for exactly this reason.
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final socket = await boot(tester, fixedPlotTree, 'rf');

    final measures =
        socket.sent.where((f) => f['type'] == 'measure').toList();
    expect(measures, hasLength(1));
    expect(measures.single['id'], 'fixed');
    expect(measures.single['width'], 400);
    expect(measures.single['height'], 300);
    expect(measures.single['dpr'], 2.0,
        reason: 'this is the whole point of measuring a fixed plot');
  });

  testWidgets('a width-only plot keeps its width and picks a height',
      (tester) async {
    final socket = await boot(tester, {
      'component': 'page',
      'title': 'Plots',
      'children': [
        {'component': 'plot_output', 'id': 'half', 'width': 200},
      ],
    }, 'rw');

    final m = socket.sent.firstWhere((f) => f['type'] == 'measure');
    expect(m['width'], 200,
        reason: 'the declared axis wins over the box on that axis');
    // 4:3 off the declared width, the same ratio the browser's CSS
    // commits to for a plot with no dimensions
    expect(m['height'], 150);
  });

  testWidgets('a height-only plot in a Row derives its width',
      (tester) async {
    // A Row gives its children an unbounded horizontal axis, so a
    // height-only plot has neither a declared width nor a bounded
    // one. It does have a height and a ratio, so the width follows
    // -- the same 4:3 rule read the other way. Without it the plot
    // never measured, and never measuring took the dpr with it.
    final socket = await boot(tester, {
      'component': 'page',
      'title': 'Plots',
      'children': [
        {
          'component': 'row',
          'children': [
            {'component': 'plot_output', 'id': 'tall', 'height': 300},
          ],
        },
      ],
    }, 'rh');

    final m = socket.sent.firstWhere((f) => f['type'] == 'measure');
    expect(m['id'], 'tall');
    expect(m['height'], 300);
    expect(m['width'], 400);
    expect(m['dpr'], isNotNull);
  });

  testWidgets('an image_output draws at the size the wire gave it',
      (tester) async {
    // Flutter sizes an Image to the raster's pixel count when no size
    // is set, so a plot rasterized at dpr 2 for a 400x300 box would
    // draw 800x600 logical. The protocol says the opposite: the
    // client sets the display size from the value and never inspects
    // the raster.
    final socket = await boot(tester, {
      'component': 'page',
      'title': 'Image',
      'children': [
        {'component': 'image_output', 'id': 'cover', 'alt': 'art'},
      ],
    }, 'ri');
    socket.deliver({
      'type': 'output', 'id': 'cover', 'kind': 'image',
      'value': {'src': pngDataUri, 'width': 120, 'height': 90},
    });
    await tester.pumpAndSettle();

    final img = tester.widget<Image>(find.byType(Image));
    expect(img.width, 120);
    expect(img.height, 90);
  });

  testWidgets('an image src this client cannot load is named',
      (tester) async {
    final socket = await boot(tester, plotTree, 'rp');
    socket.deliver({'type': 'output', 'id': 'scatter', 'kind': 'image',
      'value': {'src': 'ftp://example.com/plot.png'}});
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot load an image'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('modal_button closes the dialog and tells nobody',
      (tester) async {
    final socket = await boot(tester, outputTree, 'ro');
    socket.deliver({
      'type': 'modal',
      'action': 'show',
      'title': 'Delete it?',
      'body': <dynamic>[],
      'footer': {
        'component': 'row',
        'children': [
          {'component': 'button', 'id': '..modal_close', 'label': 'Cancel',
            'variant': 'ghost'},
          {'component': 'button', 'id': 'yes', 'label': 'Delete',
            'variant': 'danger'},
        ],
      },
      'easy_close': false,
    });
    await tester.pumpAndSettle();
    expect(find.text('Delete it?'), findsOneWidget);

    final before = socket.sent.length;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete it?'), findsNothing,
        reason: 'a Cancel that renders and does nothing is the same '
            'dead control the download button was');
    expect(socket.sent.length, before,
        reason: 'dismissing a dialog is not news; that is the whole '
            'difference between modal_button() and button()');
  });

  testWidgets('a close button outside a dialog is visibly disabled',
      (tester) async {
    await boot(tester, {
      'component': 'page',
      'title': 'Loose',
      'children': [
        {'component': 'button', 'id': '..modal_close', 'label': 'Cancel',
          'variant': 'ghost'},
      ],
    }, 'rc');
    final btn = tester.widget<TextButton>(find.byType(TextButton));
    expect(btn.onPressed, isNull,
        reason: 'an enabled button that closes nothing is the lie, '
            'not the disabled one');
  });
}

// --- v3.1: what the earshot port proved the vocabulary was missing ---

void _v31() {
  testWidgets('a width becomes a SizedBox, a grow becomes Expanded',
      (tester) async {
    // A fixed sidebar beside a filling centre: the shape both
    // migrated apps are built on, and the one thing row/column could
    // not say. CSS spends it as flex-basis and flex-grow; Flutter as
    // SizedBox and Expanded.
    await boot(tester, {
      'component': 'page',
      'title': 'Layout',
      'children': [
        {
          'component': 'row',
          'gap': 16,
          'children': [
            {'component': 'panel', 'variant': 'sidebar', 'width': 280,
              'children': [
                {'component': 'text', 'value': 'side', 'variant': 'normal'}
              ]},
            {'component': 'column', 'grow': 1, 'children': [
              {'component': 'text', 'value': 'fills', 'variant': 'normal'}
            ]},
          ],
        },
      ],
    }, 'rl1');

    final box = tester.widget<SizedBox>(find.ancestor(
        of: find.text('side'), matching: find.byType(SizedBox)).first);
    expect(box.width, 280);

    expect(
        find.ancestor(of: find.text('fills'), matching: find.byType(Expanded)),
        findsOneWidget,
        reason: 'a grown column in a Row is exactly what Expanded is for');
    // and the fixed one is not also expanded, or both would flex
    expect(
        find.ancestor(of: find.text('side'), matching: find.byType(Expanded)),
        findsNothing);
  });

  testWidgets('a grown container under a non-flex parent does not crash',
      (tester) async {
    // Expanded is legal only as the direct child of a Flex. The first
    // version asked the element tree "is there a RenderFlex above
    // me?", which finds any ancestor -- so a grown component under a
    // Column > Padding said yes and threw ParentDataWidget at build.
    // A collapse puts real padding between the Column and its
    // children, which is exactly that shape.
    //
    // The previous version of this test rendered no grown component
    // at all, so it proved nothing.
    await boot(tester, {
      'component': 'page',
      'title': 'Loose',
      'children': [
        {
          'component': 'collapse',
          'title': 'Settings',
          'open': true,
          'children': [
            {'component': 'column', 'grow': 1, 'children': [
              {'component': 'text', 'value': 'inside', 'variant': 'normal'}
            ]},
          ],
        },
      ],
    }, 'rl2');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('inside'), findsOneWidget);
    // and it simply does not grow, the way flex-grow on a child of a
    // non-flex parent does nothing in the browser
    expect(
        find.ancestor(of: find.text('inside'), matching: find.byType(Expanded)),
        findsNothing);
  });

  testWidgets('a grown child of an auto-height column does not crash',
      (tester) async {
    // The second half of the same problem, and the one the first fix
    // missed. Being the direct child of a Flex makes Expanded legal;
    // it does not make it *work*. A Column with an unbounded main
    // axis -- inside a scroll view, or inside an ExpansionTile -- has
    // no spare height to divide, and a flexed child there throws
    // "non-zero flex but incoming height constraints are unbounded".
    await boot(tester, {
      'component': 'page',
      'title': 'Unbounded',
      'children': [
        {
          'component': 'collapse',
          'title': 'Settings',
          'open': true,
          'children': [
            {'component': 'column', 'children': [
              {'component': 'panel', 'grow': 1, 'children': [
                {'component': 'text', 'value': 'deep', 'variant': 'normal'}
              ]},
            ]},
          ],
        },
      ],
    }, 'ru1');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('deep'), findsOneWidget);
    expect(
        find.ancestor(of: find.text('deep'), matching: find.byType(Expanded)),
        findsNothing,
        reason: 'nothing to grow into, so it does not grow -- the same '
            'as flex-grow inside an auto-height container');
  });

  testWidgets('a grown child of a bounded column still grows', (tester) async {
    // And the check has to be a check, not a blanket refusal: a
    // Column that does have bounded height must still share it out.
    await boot(tester, {
      'component': 'page',
      'title': 'Bounded',
      'children': [
        {
          'component': 'row',
          'children': [
            {'component': 'column', 'grow': 1, 'children': [
              {'component': 'text', 'value': 'wide', 'variant': 'normal'}
            ]},
          ],
        },
      ],
    }, 'ru2');
    expect(tester.takeException(), isNull);
    expect(
        find.ancestor(of: find.text('wide'), matching: find.byType(Expanded)),
        findsOneWidget,
        reason: 'a row is bounded horizontally by the page');
  });

  testWidgets('a grown container in a modal footer does not crash',
      (tester) async {
    // The other non-flex parent a component can land under: a dialog
    // body is a SingleChildScrollView, and render_ui() output goes
    // wherever the app puts it.
    final socket = await boot(tester, outputTree, 'rl3');
    socket.deliver({
      'type': 'modal',
      'action': 'show',
      'title': 'Busy',
      'body': [
        {'component': 'column', 'grow': 1, 'children': [
          {'component': 'text', 'value': 'in a dialog', 'variant': 'normal'}
        ]},
      ],
      'easy_close': false,
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('in a dialog'), findsOneWidget);
  });

  testWidgets('an image draws from a data URI at the size it was given',
      (tester) async {
    await boot(tester, {
      'component': 'page',
      'title': 'Img',
      'children': [
        {'component': 'image', 'src': pngDataUri, 'alt': 'logo',
          'width': 32, 'height': 32},
      ],
    }, 'ri1');
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.width, 32);
    expect(img.height, 32);
  });

  testWidgets('a relative src resolves against the server address',
      (tester) async {
    // /static/logo.png is served by the same glinty app. The renderer
    // has no idea what that is relative to; the connection does,
    // because it is the thing holding the address.
    //
    // Image.network really fetches, even under the test binding, so
    // the request is stubbed -- otherwise this asserts a 400 from a
    // host called "x" rather than the URL the renderer built.
    await HttpOverrides.runZoned(() async {
      await boot(tester, {
        'component': 'page',
        'title': 'Img',
        'children': [
          {'component': 'image', 'src': '/static/logo.png', 'alt': 'logo'},
        ],
      }, 'ri2');
      final img = tester.widget<Image>(find.byType(Image));
      expect((img.image as NetworkImage).url, 'http://x/static/logo.png');
      expect(find.textContaining('cannot load'), findsNothing);
    }, createHttpClient: (_) => _FakePngClient());
  });

  testWidgets('a bare renderer says it cannot resolve one', (tester) async {
    // No connection, so no origin. Naming that beats guessing at a
    // host or drawing a broken-image box.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => GlintyRenderer().build(
              c,
              GlintyComponent.fromJson({
                'component': 'image', 'src': '/static/logo.png', 'alt': ''
              })),
        ),
      ),
    ));
    expect(find.textContaining('no server address'), findsOneWidget);
  });

  testWidgets('a collapse folds and unfolds', (tester) async {
    await boot(tester, {
      'component': 'page',
      'title': 'Fold',
      'children': [
        {'component': 'collapse', 'title': 'Parameters', 'open': false,
          'children': [
            {'component': 'text', 'value': 'inside', 'variant': 'normal'}
          ]},
      ],
    }, 'rc1');

    expect(find.text('Parameters'), findsOneWidget);
    expect(find.text('inside'), findsNothing,
        reason: 'open defaults false, so it starts folded');

    await tester.tap(find.text('Parameters'));
    await tester.pumpAndSettle();
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('a collapse marked open starts open', (tester) async {
    await boot(tester, {
      'component': 'page',
      'title': 'Fold',
      'children': [
        {'component': 'collapse', 'title': 'Parameters', 'open': true,
          'children': [
            {'component': 'text', 'value': 'inside', 'variant': 'normal'}
          ]},
      ],
    }, 'rc2');
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('a link wraps children instead of its own text',
      (tester) async {
    await boot(tester, {
      'component': 'page',
      'title': 'Link',
      'children': [
        {'component': 'link', 'href': 'https://cornball.ai',
          'external': true,
          'children': [
            {'component': 'text', 'value': 'earshot', 'variant': 'strong'}
          ]},
      ],
    }, 'rk1');
    expect(find.text('earshot'), findsOneWidget);
    final t = tester.widget<Text>(find.text('earshot'));
    expect(t.style?.decoration, isNot(TextDecoration.underline),
        reason: 'a logo inside a link is still a logo, not link text');
  });

  testWidgets('a list of valued buttons sharing a handler renders',
      (tester) async {
    // The point of `value` is that rows share one handler, so a list
    // of them shares one component id. Keying on the id alone gave
    // every row the same key, and duplicate keys among siblings are
    // an error in Flutter -- the widget equivalent of the duplicate
    // DOM ids the browser lowering was emitting.
    final socket = await boot(tester, {
      'component': 'page',
      'title': 'History',
      'children': [
        {'component': 'column', 'children': [
          for (final v in ['a', 'b', 'c'])
            {'component': 'button', 'id': 'history_view', 'label': 'row $v',
              'value': v, 'variant': 'ghost'},
          // Same id AND same value. Neither field is guaranteed
          // distinct -- the id is routing, the value is data -- so a
          // key derived from either still collides. There is no
          // identity here to key on, and inventing one is what
          // crashed.
          {'component': 'button', 'id': 'history_view', 'label': 'row a',
            'value': 'a', 'variant': 'ghost'},
          // And two *unvalued* buttons sharing an id, which is the
          // plain case: a form with Save at the top and the bottom.
          // Nothing makes a button id unique, so nothing derived from
          // it can be a key.
          {'component': 'button', 'id': 'save', 'label': 'Save top',
            'variant': 'ghost'},
          {'component': 'button', 'id': 'save', 'label': 'Save bottom',
            'variant': 'ghost'},
        ]},
      ],
    }, 'rk2');

    expect(tester.takeException(), isNull);
    expect(find.byType(TextButton), findsNWidgets(6));

    // and pressing one says which
    await tester.tap(find.text('row b'));
    await tester.pumpAndSettle();
    expect(socket.sent.last['id'], 'history_view');
    expect(socket.sent.last['value'], 'b');
  });

  testWidgets('a valued button carries its value, a plain one does not',
      (tester) async {
    // One handler serves a list of rows: the press says which row.
    final socket = await boot(tester, {
      'component': 'page',
      'title': 'Rows',
      'children': [
        {'component': 'button', 'id': 'history_view', 'label': '12:04',
          'value': 'entry_7', 'variant': 'default'},
        {'component': 'button', 'id': 'go', 'label': 'Run',
          'variant': 'primary'},
      ],
    }, 'rb1');

    await tester.tap(find.text('12:04'));
    await tester.pumpAndSettle();
    var last = socket.sent.last;
    expect(last['type'], 'event');
    expect(last['id'], 'history_view');
    expect(last['value'], 'entry_7');

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    last = socket.sent.last;
    expect(last['id'], 'go');
    expect(last.containsKey('value'), isFalse,
        reason: 'an ordinary press is the whole message; a null value '
            'field would make the server decide what null means');
  });
}

/// An HttpClient that answers every GET with a 1x1 PNG.
///
/// Image.network really opens a socket, even under the test binding,
/// so a test about *which URL was built* would otherwise assert a
/// connection failure instead. Only the surface Image.network touches
/// is implemented; anything else throws rather than pretending.
class _FakePngClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakePngRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakePngRequest(url);

  @override
  bool autoUncompress = true;
  @override
  noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _FakePngRequest implements HttpClientRequest {
  _FakePngRequest(this.uri);
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _FakeHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakePngResponse();
  @override
  noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _FakePngResponse implements HttpClientResponse {
  static final _bytes = base64Decode(pngDataUri.split(',').last);

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _FakeHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

/// A refused transfer answers on the ticket channel.
///
/// It used to arrive as an `error` frame scoped to the resource id.
/// This client stores those against output ids and a download_button
/// is not an output, so a Flutter refusal was invisible: the press
/// did nothing and nothing said why.
void _ticketRefusals() {
  final downloadTree = {
    'component': 'page',
    'title': 'Download',
    'children': [
      {'component': 'download_button', 'id': 'report', 'label': 'Save',
        'variant': 'primary'},
    ],
  };

  Future<FakeSocket> bootDownload(WidgetTester tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
          onDownload: (_) {},
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcomeOf(downloadTree, 'rt1'));
    await tester.pumpAndSettle();
    return socket;
  }

  testWidgets('a refused transfer is visible, beside the control',
      (tester) async {
    final socket = await bootDownload(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(socket.sent.last['type'], 'ticket');

    socket.deliver({
      'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'too many pending transfers',
    });
    await tester.pumpAndSettle();

    expect(find.text('too many pending transfers'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget,
        reason: 'the label is the control; an error must not replace it');
  });

  testWidgets('asking again clears the refusal', (tester) async {
    final socket = await bootDownload(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    socket.deliver({
      'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'at the cap',
    });
    await tester.pumpAndSettle();
    expect(find.text('at the cap'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('at the cap'), findsNothing,
        reason: 'a refusal belongs to the attempt that earned it');
  });

  testWidgets('a refusal reaches the button that asked, not its twin',
      (tester) async {
    // Two download buttons sharing a handler id, which the protocol
    // allows -- the id is routing, not identity. Held against the id,
    // one button's refusal appeared under both.
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
          onDownload: (_) {},
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcomeOf({
      'component': 'page',
      'title': 'Two',
      'children': [
        {'component': 'download_button', 'id': 'report', 'label': 'Top',
          'variant': 'ghost'},
        {'component': 'download_button', 'id': 'report', 'label': 'Bottom',
          'variant': 'ghost'},
      ],
    }, 'rt2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bottom'));
    await tester.pumpAndSettle();
    socket.deliver({
      'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'at the cap',
    });
    await tester.pumpAndSettle();

    expect(find.text('at the cap'), findsOneWidget,
        reason: 'one button asked, so one refusal is shown');
    // and it is under the one that asked
    final under = find.descendant(
        of: find.ancestor(
            of: find.text('Bottom'), matching: find.byType(Column)).first,
        matching: find.text('at the cap'));
    expect(under, findsOneWidget);
  });

  test('answers go to waiters in the order they asked', () {
    // Two controls waiting on the same resource. The server answers
    // requests for a resource in order, so the front of the queue is
    // whose answer this is -- handing it to all of them would put one
    // control's refusal under another that is still waiting.
    final s = GlintySession();
    final got = <String, String?>{};
    s.awaitTicket('report', 'download', (r) => got['first'] = r);
    s.awaitTicket('report', 'download', (r) => got['second'] = r);

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'first refusal'});
    expect(got, {'first': 'first refusal'});
    expect(got.containsKey('second'), isFalse,
        reason: 'the second is still waiting on its own answer');

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk', 'expires': 30});
    expect(got['second'], isNull, reason: 'a grant is not a refusal');
    expect(got.containsKey('second'), isTrue);
  });

  test('a cancelled waiter still consumes the answer it asked for', () {
    // Cancelling gets rid of the control, not of the request: it is
    // on the wire and the server will answer it. Dropping the waiter
    // out of the queue slides everyone behind it forward a place, so
    // the next control is handed an answer to a question it never
    // asked -- exactly the misrouting the queue exists to prevent.
    final s = GlintySession();
    var reached = 0;
    final cancel = s.awaitTicket('report', 'download', (_) {
      throw StateError('a disposed control must not be answered');
    });
    cancel();
    s.awaitTicket('report', 'download', (_) => reached++);

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'first'});
    expect(reached, 0,
        reason: 'the first answer belongs to the request that is gone');

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'second'});
    expect(reached, 1);
  });

  test('an answer nobody is waiting for is marked unclaimed', () {
    // What the transport reads to decide whether a granted download
    // belongs to anybody. Left set from the previous answer it would
    // suppress a live grant; left clear it would open a file for a
    // button that is not on screen any more.
    final s = GlintySession();
    final cancel = s.awaitTicket('report', 'download', (_) {});
    s.awaitTicket('report', 'download', (_) {});
    cancel();

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk1', 'expires': 30});
    expect(s.lastTicketUnclaimed, isTrue);

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk2', 'expires': 30});
    expect(s.lastTicketUnclaimed, isFalse);
  });

  test('a grant nothing asked for is not a grant', () {
    // The client asks, the server answers. A ticket that answers no
    // request is the server volunteering a transfer -- which the
    // browser drops on the floor, and which this client would have
    // handed to the embedder to open.
    final s = GlintySession(onSend: (_) => true);
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'unbidden', 'expires': 30});
    expect(s.lastTicketUnclaimed, isTrue);

    // requestTicket() straight, with no control behind it, is a
    // supported way to ask -- and its grant is nobody's to withhold.
    s.requestTicket('report', 'download');
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'asked-for', 'expires': 30});
    expect(s.lastTicketUnclaimed, isFalse);

    // and that request is spent: the next unbidden one is refused
    // again rather than riding on it.
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'unbidden-again', 'expires': 30});
    expect(s.lastTicketUnclaimed, isTrue);
  });

  test('answers follow the order the requests went out in', () {
    // A direct request and a button's, for the same resource. Kept as
    // a count beside a queue these were two orderings: the direct one
    // went out first and the button sat first in the queue, so the
    // button was handed an answer to a question it never asked -- and
    // then its own answer went to nobody.
    final s = GlintySession(onSend: (_) => true);
    s.requestTicket('report', 'download');
    final got = <String?>[];
    s.awaitTicket('report', 'download', got.add);

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'the direct one'});
    expect(got, isEmpty, reason: 'that answer was not the button\'s');

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'the button one'});
    expect(got, ['the button one']);
  });

  test('a waiter cannot vouch for a grant nothing asked for', () {
    // awaitTicket() asks as it registers, so a control cannot be
    // waiting on a request that was never sent. Were registering
    // separate from asking, a waiter alone would legitimise a ticket
    // the server volunteered.
    final s = GlintySession(onSend: (_) => true);
    s.awaitTicket('report', 'download', (_) {});
    expect(s.sent.where((f) => f.type == 'ticket'), hasLength(1),
        reason: 'registering is asking');
  });

  test('an answer that is both a refusal and a grant is not a grant', () {
    // Classified once. Read separately, the session called this a
    // refusal and told the button so, while the transport found a
    // token and opened it: one press that both failed and downloaded.
    final s = GlintySession(onSend: (_) => true);
    String? told;
    s.awaitTicket('report', 'download', (r) => told = r);
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'at the cap', 'token': 'tk_should_not_open', 'expires': 30});

    expect(told, 'at the cap');
    expect(s.lastTicketGrant, isNull);
  });

  test('an empty credential is not a credential', () {
    final s = GlintySession(onSend: (_) => true);
    String? told;
    s.awaitTicket('report', 'download', (r) => told = r);
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': '', 'expires': 30});

    expect(told, isNotNull, reason: 'the request is over either way');
    expect(s.lastTicketGrant, isNull);
  });

  test('a ticket frame too malformed to route clears the last verdict', () {
    // Without an id there is nothing to answer, so the frame is
    // dropped -- but a verdict left over from the previous one would
    // let it open that grant a second time.
    final s = GlintySession(onSend: (_) => true);
    s.awaitTicket('report', 'download', (_) {});
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk_real', 'expires': 30});
    expect(s.lastTicketGrant, 'tk_real');

    s.receive({'type': 'ticket', 'purpose': 'download', 'token': 'tk_real'});
    expect(s.lastTicketGrant, isNull);
  });

  test('a request the wire would not take is not a request', () {
    // The send queue is capped, and a frame past the cap is dropped.
    // Recorded in the ledger anyway, that entry stands for a question
    // the server was never asked -- so it waits forever, and it eats
    // the answer meant for the next control in line.
    var takes = false;
    final s = GlintySession(onSend: (_) => takes);
    String? told;
    s.awaitTicket('report', 'download', (r) => told = r);
    expect(told, isNotNull, reason: 'a control cannot wait on nothing');

    // and it left no entry behind, so the next request -- once the
    // wire is taking frames again -- is first in line for its own
    // answer rather than second behind a ghost.
    takes = true;
    String? next;
    s.awaitTicket('report', 'download', (r) => next = r);
    s.receive({'type': 'ticket', 'id': 'report',
      'purpose': 'download', 'error': 'mine'});
    expect(next, 'mine');
  });

  test('a direct request can see its own refusal', () {
    // requestTicket() has no control behind it, so a refusal had
    // nowhere to land: the caller saw a future that never completed
    // and a transfer that never happened, with nothing said.
    final s = GlintySession(onSend: (_) => true);
    final granted = s.requestTicket('report', 'download');
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'at the cap'});
    expect(granted, completion('at the cap'));

    final ok = s.requestTicket('report', 'download');
    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk', 'expires': 30});
    expect(ok, completion(isNull), reason: 'null is granted');

    // and a dropped connection is an answer too, rather than a
    // future that never settles
    final lost = s.requestTicket('report', 'download');
    s.failPendingTickets('the connection dropped');
    expect(lost, completion('the connection dropped'));

    // and so is being unable to ask at all
    final unsent = GlintySession(onSend: (_) => false);
    expect(unsent.requestTicket('report', 'download'), completion(isNotNull));
  });

  test('a request does not outlive the socket that carried it', () {
    // The wire it went out on is gone, so it will never be answered.
    // Left standing it vouches for whatever the *next* socket says
    // first -- a grant that answers nothing, waved through on the
    // strength of a request that died with the connection.
    final s = GlintySession(onSend: (_) => true);
    s.requestTicket('report', 'download');
    s.failPendingTickets('the connection dropped');

    s.receive({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'from-the-new-socket', 'expires': 30});
    expect(s.lastTicketUnclaimed, isTrue);
  });

  testWidgets('an answer that refuses does not also download',
      (tester) async {
    // Both an error and a token in one frame. The session read it as
    // a refusal and said so under the button; the transport read the
    // same frame for itself, found a token, and opened it. One press,
    // refused and downloaded at once.
    final grants = <Uri>[];
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async => socket = FakeSocket(),
          onDownload: grants.add,
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcomeOf(downloadTree, 'rt1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    socket.deliver({
      'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'at the cap', 'token': 'tk_should_not_open', 'expires': 30,
    });
    await tester.pumpAndSettle();

    expect(find.text('at the cap'), findsOneWidget);
    expect(grants, isEmpty, reason: 'a refusal is not also a grant');
  });

  testWidgets('a grant for a control that has gone away is not opened',
      (tester) async {
    // The request outlives the button. Its answer must not become a
    // download the user never asked for and cannot explain.
    final grants = <Uri>[];
    late FakeSocket socket;
    final conn = GlintyConnection(
      url: Uri.parse('ws://x/ws'),
      open: (_) async => socket = FakeSocket(),
      onDownload: grants.add,
    );
    addTearDown(conn.dispose);
    conn.start();
    await tester.pump();
    socket.deliver(welcomeOf(downloadTree, 'rt1'));
    await tester.pump();

    final cancel = conn.session.awaitTicket('report', 'download', (_) {});
    cancel();
    socket.deliver({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk_orphan', 'expires': 30});
    await tester.pump();
    expect(grants, isEmpty);

    // and the suppression is about that waiter, not about grants
    conn.session.awaitTicket('report', 'download', (_) {});
    socket.deliver({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk_real', 'expires': 30});
    await tester.pump();
    expect(grants.single.queryParameters['ticket'], 'tk_real');
  });

  testWidgets('a malformed answer is a refusal, not a grant', (tester) async {
    // Neither token nor error. Passed through as a grant it reached
    // the transport, which found no token and dropped it -- the
    // control stayed waiting and nothing said why.
    final socket = await bootDownload(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    socket.deliver(
        {'type': 'ticket', 'id': 'report', 'purpose': 'download'});
    await tester.pumpAndSettle();
    expect(find.textContaining('without a ticket'), findsOneWidget);
  });

  testWidgets('a dropped connection gives the waiting control back',
      (tester) async {
    // The socket that was going to answer is gone. Left in the queue,
    // the button waits forever with nothing said and nothing to press,
    // and the next socket's first reply goes to it rather than to
    // whoever asks after the reconnect.
    final sockets = <FakeSocket>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlintyApp(
          url: Uri.parse('ws://x/ws'),
          open: (_) async {
            sockets.add(FakeSocket());
            return sockets.last;
          },
          onDownload: (_) {},
        ),
      ),
    ));
    await tester.pump();
    sockets.last.deliver(welcomeOf(downloadTree, 'rt1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    sockets.last.drop();
    await tester.pump();
    await tester.pump();
    expect(find.text('the connection dropped'), findsOneWidget);

    // and it is pressable again, so the retry can carry a new request
    await tester.pump(const Duration(seconds: 1));
    expect(sockets, hasLength(2));
    sockets.last.deliver(welcomeOf(downloadTree, 'rt1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sockets.last.sent.where((m) => m['type'] == 'ticket'),
        hasLength(1));
  });

  testWidgets('a control waiting on a transfer cannot ask twice',
      (tester) async {
    // Two presses are two requests, and the first press cancels its
    // own waiter to make room for the second -- so answer one lands
    // on waiter two, and the button reports a refusal it did not
    // earn (or opens a file for a press that was refused).
    final socket = await bootDownload(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(socket.sent.where((m) => m['type'] == 'ticket'), hasLength(1),
        reason: 'there is one of it, and it is already waiting');

    // its answer frees it
    socket.deliver({'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'error': 'at the cap'});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(socket.sent.where((m) => m['type'] == 'ticket'), hasLength(2));
  });

  testWidgets('a grant is not a refusal', (tester) async {
    final socket = await bootDownload(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    socket.deliver({
      'type': 'ticket', 'id': 'report', 'purpose': 'download',
      'token': 'tk_abc', 'expires': 30,
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('cap'), findsNothing);
  });

  test('the refusal frame matches the shared transcript', () {
    final expected = frames(transcript('ticket-refused'), 'out').first;
    final s = GlintySession();
    String? got;
    // The control that asked registers as the waiter, so the answer
    // goes to it rather than to every control sharing the id.
    s.awaitTicket(expected['id'] as String, 'download', (r) => got = r);
    s.receive(expected);
    expect(got, expected['error']);
    expect(s.tickets, isEmpty,
        reason: 'a refusal is not a credential');
  });
}
