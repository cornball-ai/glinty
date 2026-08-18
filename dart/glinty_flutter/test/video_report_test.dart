// video_output(report = TRUE): the report direction (#41).
//
// The seam under test is split the way the code splits it: the
// session owns the wire discipline (throttle, dedup, immediate
// state flips), and the renderer owns handing the embedder's player
// an onReport exactly when the component asked and there is a
// session to tell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Map<String, dynamic> welcomeWith(Object tree, {String revision = 'r1'}) => {
      'type': 'welcome',
      'session': 's1',
      'protocol': 3,
      'ui_revision': revision,
      'ui': tree,
    };

Map<String, dynamic> videoTree({required bool report}) => {
      'component': 'page',
      'title': 'Monitor',
      'children': [
        {
          'component': 'video_output',
          'id': 'monitor',
          if (report) 'report': true,
        },
      ],
    };

Map<String, dynamic> videoValue() => {
      'type': 'output',
      'id': 'monitor',
      'kind': 'video',
      'value': {'src': 'http://example.test/cut1.mp4', 'mime': 'video/mp4'},
    };

List<Map<String, dynamic>> inputFrames(GlintySession s) => [
      for (final f in s.sent)
        if (f.type == 'input') f.body,
    ];

void main() {
  group('the session owns the wire discipline', () {
    test('a report rides the input channel under the component id', () {
      final s = GlintySession();
      s.videoReport('monitor', 1.5, true);
      final frames = inputFrames(s);
      expect(frames, hasLength(1));
      expect(frames.first['id'], 'monitor');
      expect(frames.first['value'], {'current_time': 1.5, 'playing': true});
    });

    test('an unmoved position is silent, however often it is offered',
        () {
      final s = GlintySession();
      s.videoReport('monitor', 2.0, false);
      for (var i = 0; i < 20; i++) {
        // a paused player's listener may tick anyway; same rounded
        // position, same state -- nothing more goes out
        s.videoReport('monitor', 2.004, false);
      }
      expect(inputFrames(s), hasLength(1));
    });

    test('position alone waits out the floor', () async {
      final s = GlintySession();
      s.videoReport('monitor', 0.0, true);
      // a 60Hz position listener: every call a new position, well
      // inside the 250ms floor
      s.videoReport('monitor', 0.016, true);
      s.videoReport('monitor', 0.033, true);
      expect(inputFrames(s), hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      s.videoReport('monitor', 0.35, true);
      expect(inputFrames(s), hasLength(2));
    });

    test('a playing flip goes out immediately, floor or no floor', () {
      final s = GlintySession();
      s.videoReport('monitor', 0.0, true);
      // pause lands 16ms later: state is news in a way position is not
      s.videoReport('monitor', 0.016, false);
      final frames = inputFrames(s);
      expect(frames, hasLength(2));
      expect(frames.last['value'], {'current_time': 0.016, 'playing': false});
    });
  });

  group('the renderer hands the player onReport exactly when asked', () {
    Future<GlintyVideoSource?> pumpVideo(WidgetTester tester, GlintySession s,
        {required bool report}) async {
      GlintyVideoSource? captured;
      s.receive(welcomeWith(videoTree(report: report)));
      s.receive(videoValue());
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: GlintyView(
        session: s,
        videoBuilder: (context, source) {
          captured = source;
          return const SizedBox(width: 32, height: 32);
        },
      ))));
      return captured;
    }

    testWidgets('report = TRUE: a wired onReport that reaches the session',
        (tester) async {
      final s = GlintySession();
      final source = await pumpVideo(tester, s, report: true);
      expect(source, isNotNull);
      expect(source!.onReport, isNotNull);
      s.sent.clear();
      source.onReport!(3.5, true);
      final frames = inputFrames(s);
      expect(frames, hasLength(1));
      expect(frames.first['id'], 'monitor');
      expect(frames.first['value'], {'current_time': 3.5, 'playing': true});
    });

    testWidgets('no report field: the player has nothing to call',
        (tester) async {
      final s = GlintySession();
      final source = await pumpVideo(tester, s, report: false);
      expect(source, isNotNull);
      expect(source!.onReport, isNull);
    });
  });
}
