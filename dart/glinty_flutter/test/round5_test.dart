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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';
import 'package:web_socket/web_socket.dart';

class FakeSocket implements WebSocket {
  final List<Map<String, dynamic>> sent = [];
  final _events = StreamController<WebSocketEvent>();
  bool closed = false;

  void deliver(Map<String, dynamic> msg) =>
      _events.add(TextDataReceived(jsonEncode(msg)));

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
