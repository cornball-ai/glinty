// Where a stock Material Slider actually puts its track. _slider's
// bubble and scale position at trackInset + f * (width - 2 *
// trackInset) with trackInset = 24 -- the max(overlay, thumb)/2 of
// BaseSliderTrackShape.getPreferredRect. If a Material redesign
// moves the track, this fails and points at that constant.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('track extent at a known width', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: Slider(value: 1, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final sliderRect = tester.getRect(find.byType(Slider));
    debugPrint('PROBE slider=$sliderRect');

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      final ui.Image image = await boundary.toImage();
      final data = await image.toByteData();
      bool colored(int x, int y) {
        final o = ((y * image.width) + x) * 4;
        final r = data!.getUint8(o),
            g = data.getUint8(o + 1),
            b = data.getUint8(o + 2);
        return (r - 255).abs() + (g - 255).abs() + (b - 255).abs() > 30;
      }

      final y = sliderRect.center.dy.round();
      int? first, last;
      for (var x = sliderRect.left.round(); x < sliderRect.right.round(); x++) {
        if (colored(x, y)) {
          first ??= x;
          last = x;
        }
      }
      final insetL = first! - sliderRect.left.round();
      debugPrint('PROBE first=$first last=$last insetL=$insetL '
          'insetR=${sliderRect.right.round() - last!}');
      // render.dart _slider trackInset must equal this
      expect(insetL, 24);
    });
  });
}
