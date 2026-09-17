import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Rect;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Android/iOS: write to the temp directory, then open the system share
/// sheet on it.
///
/// [sharePosition] matters on iPad only, where the share sheet is a popover
/// that has to be anchored to whatever the user tapped — iPadOS throws if
/// nothing tells it where to appear. Phones ignore it.
Future<void> shareBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? text,
  Rect? sharePosition,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType)],
    text: text,
    sharePositionOrigin: sharePosition,
  );
}
