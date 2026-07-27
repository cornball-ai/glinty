// Shared access to the generated transcripts, so every Dart test
// reads the same artifact the R and browser suites do.

import 'dart:convert';
import 'dart:io';

const transcriptPath = "../../inst/fixtures/transcripts.json";

Map<String, dynamic> loadTranscriptFile() =>
    jsonDecode(File(transcriptPath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> loadTranscripts() =>
    (loadTranscriptFile()["transcripts"] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> transcript(String name) => loadTranscripts().firstWhere(
    (t) => t['name'] == name,
    orElse: () => throw StateError('no transcript named $name; the R '
        'definition and this suite have diverged'));

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
