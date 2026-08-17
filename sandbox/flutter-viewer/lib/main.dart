// Minimal glinty Flutter client for watching gallery ports live.
// Connects to the glinty app server on port 8490 of whatever host
// serves this page, so localhost and tailnet names both work.
import 'package:flutter/material.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

void main() {
  final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
  final url = Uri.parse('ws://$host:8490/ws');
  runApp(MaterialApp(
    title: 'glinty flutter viewer',
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: GlintyApp(url: url)),
  ));
}
