import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Rect;
import 'package:web/web.dart' as web;

/// Web: there is no filesystem and no share sheet, so the equivalent is to
/// hand the browser a blob and click a download link at it. [sharePosition]
/// is accepted only to keep one signature across platforms; nothing on the
/// web has a popover to anchor.
Future<void> shareBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? text,
  Rect? sharePosition,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  // Safari ignores .click() on an anchor that was never in the document.
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
