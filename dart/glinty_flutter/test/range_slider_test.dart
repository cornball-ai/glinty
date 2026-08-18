// A range_slider renders one control with two thumbs and emits the
// pair [lo, hi]. Both ends quantize to the slider's real granularity
// (its step, or the implied step when the app set none), and the
// pair arrives ordered even mid-drag.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'round5_test.dart' show FakeSocket, welcomeOf;

Future<FakeSocket> pumpRange(WidgetTester tester,
    Map<String, dynamic> component) async {
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
  socket.deliver(welcomeOf({
    'component': 'page',
    'title': 'p',
    'children': [component],
  }, 'r1'));
  await tester.pumpAndSettle();
  return socket;
}

void main() {
  testWidgets('a range slider renders both ends and the bounds',
      (tester) async {
    await pumpRange(tester, {
      'component': 'range_slider',
      'id': 'rng',
      'label': 'Range:',
      'min': 1,
      'max': 1000,
      'value': [200, 500],
      'emit': 'live',
    });
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Range:'), findsOneWidget);
    // value bubbles for both thumbs, end chips for both bounds
    expect(find.text('200'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('1000'), findsWidgets);
  });

  testWidgets('a stepless range slider emits whole ordered pairs',
      (tester) async {
    final socket = await pumpRange(tester, {
      'component': 'range_slider',
      'id': 'rng',
      'label': 'Range:',
      'min': 1,
      'max': 1000,
      'value': [200, 500],
      'emit': 'live',
    });

    // an uneven drag distance so the raw value would be fractional
    await tester.drag(find.byType(RangeSlider), const Offset(37.3, 0));
    await tester.pumpAndSettle();

    final inputs = socket.sent
        .where((m) => m['type'] == 'input' && m['id'] == 'rng')
        .toList();
    expect(inputs, isNotEmpty,
        reason: 'the drag should have emitted input frames');
    for (final m in inputs) {
      final pair = (m['value'] as List).cast<num>();
      expect(pair.length, 2);
      expect(pair[0] <= pair[1], true, reason: 'unordered pair $pair');
      for (final v in pair) {
        expect(v.toDouble() % 1, 0, reason: 'fractional end $v');
        expect(v >= 1 && v <= 1000, true);
      }
    }
  });

  testWidgets('under settle only the release reaches the socket',
      (tester) async {
    final socket = await pumpRange(tester, {
      'component': 'range_slider',
      'id': 'rng',
      'label': 'Range:',
      'min': 0,
      'max': 100,
      'value': [20, 80],
      'step': 5,
      'emit': 'settle',
    });

    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(RangeSlider)) + const Offset(-100, 0));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(
        socket.sent.where((m) => m['type'] == 'input' && m['id'] == 'rng'),
        isEmpty,
        reason: 'mid-drag frames must stay local under settle');
    await gesture.up();
    await tester.pumpAndSettle();

    final inputs = socket.sent
        .where((m) => m['type'] == 'input' && m['id'] == 'rng')
        .toList();
    expect(inputs.length, 1, reason: 'one frame at release');
    final pair = (inputs.single['value'] as List).cast<num>();
    for (final v in pair) {
      expect(v.toDouble() % 5, 0, reason: 'end $v off the step grid');
    }
  });
}
