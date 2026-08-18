// Native viewer: no picker or download plumbing is wired, so
// file_input and download_button name the gap -- the designed
// refusal. Wiring native needs a dialog plugin the viewer does not
// take on.
import 'package:glinty_flutter/glinty_flutter.dart';

const GlintyUploadHandler? uploadHandler = null;
const void Function(Uri url)? downloadHandler = null;
