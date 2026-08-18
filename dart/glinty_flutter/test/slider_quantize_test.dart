// A stepless slider must not emit floats: dragging a 1..1000
// sample-count slider once produced n = 394.326. Emitted values
// quantize to the implied step (Shiny's findStepSize rule), the
// same granularity the browser's range input applies natively.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'round5_test.dart' show FakeSocket, welcomeOf;

void main() {
  testWidgets('a stepless 1..1000 slider emits whole numbers',
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
    socket.deliver(welcomeOf({
      'component': 'page',
      'title': 'p',
      'children': [
        {
          'component': 'slider_input',
          'id': 'n',
          'label': 'N:',
          'min': 1,
          'max': 1000,
          'value': 500,
          'emit': 'live',
        },
      ],
    }, 'r1'));
    await tester.pumpAndSettle();

    // an uneven drag distance so the raw value would be fractional
    await tester.drag(find.byType(Slider), const Offset(37.3, 0));
    await tester.pumpAndSettle();

    final inputs = socket.sent
        .where((m) => m['type'] == 'input' && m['id'] == 'n')
        .toList();
    expect(inputs, isNotEmpty,
        reason: 'the drag should have emitted input frames');
    for (final m in inputs) {
      final v = (m['value'] as num).toDouble();
      expect(v % 1, 0, reason: 'fractional sample count $v');
      expect(v >= 1 && v <= 1000, true);
    }
  });
}
