// Minimal glinty Flutter client for watching gallery ports live.
// Connects to the glinty app server on whatever host serves this
// page, so localhost and tailnet names both work. The app port is
// selectable so one viewer build follows the loop from app to app:
// web picks it from the page URL (?port=8496), native from the
// first command-line argument; both fall back to 8490.
import 'package:flutter/material.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

import 'transfer_stub.dart'
    if (dart.library.html) 'transfer_web.dart' as transfer;

void main(List<String> args) {
  final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
  final port = int.tryParse(Uri.base.queryParameters['port'] ??
          (args.isNotEmpty ? args.first : '')) ??
      8490;
  final url = Uri.parse('ws://$host:$port/ws');
  runApp(MaterialApp(
    title: 'glinty flutter viewer',
    debugShowCheckedModeBanner: false,
    // SizedBox.expand: a Scaffold body hands its child loose
    // constraints, and a shrink-wrapped app shows the embedder's
    // Material surface through every margin below the content.
    home: Scaffold(
        body: SizedBox.expand(
            child: GlintyApp(
                url: url,
                onUpload: transfer.uploadHandler,
                onDownload: transfer.downloadHandler))),
  ));
}
