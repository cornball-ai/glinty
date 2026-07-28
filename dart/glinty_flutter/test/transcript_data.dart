// Shared access to the generated transcripts, so every Dart test
// reads the same artifact the R and browser suites do.

import 'dart:convert';
import 'dart:io';

const transcriptPath = "../../inst/fixtures/transcripts.json";

Map<String, dynamic> loadTranscriptFile() =>
    jsonDecode(File(transcriptPath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> loadTranscripts() =>
    (loadTranscriptFile()["transcripts"] as List).cast<Map<String, dynamic>>();

/// Every transcript this suite has actually read.
///
/// transcripts.json is a shared artifact: adding one is meant to
/// oblige every consumer to answer for it. Nothing enforced that, so a
/// transcript could sit in the file pinning nothing -- the same hole
/// the fixture list had when it claimed "every component, once" and
/// was missing thirteen. `transcripts_test.dart` asserts this covers
/// the file.
final usedTranscripts = <String>{};

Map<String, dynamic> transcript(String name) {
  usedTranscripts.add(name);
  return loadTranscripts().firstWhere((t) => t['name'] == name,
      orElse: () => throw StateError('no transcript named $name; the R '
          'definition and this suite have diverged'));
}

/// The frames one side sends, in order.
List<Map<String, dynamic>> frames(Map<String, dynamic> t, String dir) =>
    (t['frames'] as List)
        .cast<Map<String, dynamic>>()
        .where((f) => f['dir'] == dir)
        .map((f) => (f['message'] as Map).cast<String, dynamic>())
        .toList();

/// The first server frame of a given type in a named transcript.
Map<String, dynamic> serverFrame(String name, String type) =>
    frames(transcript(name), 'out').firstWhere((m) => m['type'] == type);
