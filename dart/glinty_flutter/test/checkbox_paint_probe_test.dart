// A checked checkbox must paint the theme's primary fill with an
// on_primary check. Samples the real pixels the engine rasterizes
// under the stock theme -- widget-level asserts can't see a wrong
// MaterialState resolution, only the raster can.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'round5_test.dart' show FakeSocket, welcomeOf;

void main() {
  testWidgets('a checked checkbox paints primary fill and a check',
      (tester) async {
    late FakeSocket socket;
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        child: Scaffold(
          body: GlintyApp(
            url: Uri.parse('ws://x/ws'),
            open: (_) async => socket = FakeSocket(),
          ),
        ),
      ),
    ));
    await tester.pump();
    socket.deliver(welcomeOf({
      'component': 'page',
      'title': 'p',
      'children': [
        {
          'component': 'checkbox_input',
          'id': 'dens',
          'label': 'Density',
          'value': true,
        },
      ],
    }, 'r1'));
    await tester.pumpAndSettle();

    final cb = tester.widget<Checkbox>(find.byType(Checkbox));
    debugPrint('PROBE value=${cb.value} enabled=${cb.onChanged != null}');

    final rect = tester.getRect(find.byType(Checkbox));
    debugPrint('PROBE rect=$rect');

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      final ui.Image image = await boundary.toImage();
      final data = await image.toByteData();
      (int, int, int) at(double x, double y) {
        final o = ((y.round() * image.width) + x.round()) * 4;
        return (
          data!.getUint8(o),
          data.getUint8(o + 1),
          data.getUint8(o + 2)
        );
      }

      final c = rect.center;
      // upper-left of the interior: solid fill, clear of the check
      final fill = at(c.dx - 5, c.dy - 5);
      // dead center: the check stroke
      final check = at(c.dx, c.dy);
      debugPrint('PROBE fill=$fill check=$check');
      // stock primary #2456d6; a small tolerance rides out AA and
      // engine dithering, a wrong-state fill (grey, secondary, a
      // disabled overlay) is far outside it
      expect((fill.$1 - 36).abs() < 24, true, reason: 'fill r $fill');
      expect((fill.$2 - 86).abs() < 24, true, reason: 'fill g $fill');
      expect((fill.$3 - 214).abs() < 24, true, reason: 'fill b $fill');
      // the check is on_primary white
      expect(check.$1 > 200 && check.$2 > 200 && check.$3 > 200, true,
          reason: 'check $check');
    });
  });
}
