// Web viewer: the browser is both the picker and the downloader.
//
// Upload: a transient <input type=file> opens the OS dialog; the
// chosen files POST as multipart/form-data (field name `file`, the
// shape the ticket target expects). Cancelling resolves without
// calling target(), which is how a handler says "cancelled".
//
// Download: an anchor click, which is a top-level navigation -- it
// works cross-origin (the viewer's page origin is 8492, the app is
// 8490), where an XHR would need CORS.
//
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/widgets.dart';
import 'package:glinty_flutter/glinty_flutter.dart';

Future<void> _upload(BuildContext context, GlintyUploadRequest req) async {
  final input = html.FileUploadInputElement()..multiple = req.multiple;
  if (req.accept.isNotEmpty) {
    input.accept = req.accept.join(',');
  }
  input.click();
  await Future.any([
    input.onChange.first,
    input.on['cancel'].first,
  ]);
  final files = input.files;
  if (files == null || files.isEmpty) {
    return;
  }
  final target = await req.target();
  final form = html.FormData();
  for (final f in files) {
    form.appendBlob('file', f, f.name);
  }
  await html.HttpRequest.request(target.toString(),
      method: 'POST', sendData: form);
}

void _download(Uri url) {
  html.AnchorElement(href: url.toString())
    ..download = ''
    ..style.display = 'none'
    ..click();
}

const GlintyUploadHandler uploadHandler = _upload;
const void Function(Uri url) downloadHandler = _download;
