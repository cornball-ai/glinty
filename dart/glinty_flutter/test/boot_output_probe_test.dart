// Probe for the boot-output display bug seen live: server sends the
// initial plot render right after welcome; the client showed nothing
// until an input round trip. Throwaway diagnostics, not yet a suite
// member.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'round5_test.dart' show FakeSocket, welcomeOf;

// 1x1 transparent png
const px =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  testWidgets('an output frame sent right after welcome is displayed',
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
        {'component': 'plot_output', 'id': 'main_plot', 'height': 300},
      ],
    }, 'r1'));
    // the boot render arrives immediately after welcome, before any
    // client frame goes up
    socket.deliver({
      'type': 'output',
      'id': 'main_plot',
      'kind': 'image',
      'value': {'src': px, 'width': 480, 'height': 360},
    });
    await tester.pumpAndSettle();
    final images = tester.widgetList(find.byType(Image)).length;
    debugPrint('PROBE images=$images '
        'sized=${tester.widgetList(find.byType(SizedBox)).length}');
    expect(images, 1,
        reason: 'the boot output should draw without an input round trip');
  });
}
