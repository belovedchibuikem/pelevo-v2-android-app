import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Origin rect the iOS/macOS share popover anchors to (required on iPad).
Rect pelevoShareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.size.width > 0 && box.size.height > 0) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

bool get pelevoAirDropAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Opens the platform share sheet so iOS AirDrop / Android Nearby Share appear.
Future<ShareResult> pelevoShare({
  required BuildContext context,
  String? text,
  Uri? uri,
  List<XFile>? files,
  String? title,
  String? subject,
}) {
  final origin = pelevoShareOrigin(context);
  if (uri != null && (files == null || files.isEmpty) && text == null) {
    return SharePlus.instance.share(
      ShareParams(
        uri: uri,
        title: title,
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      files: files,
      title: title,
      subject: subject,
      sharePositionOrigin: origin,
    ),
  );
}

Future<ShareResult> pelevoShareEpisodeLink({
  required BuildContext context,
  required String url,
  required String title,
}) {
  final parsed = Uri.tryParse(url);
  if (parsed != null && (parsed.isScheme('http') || parsed.isScheme('https'))) {
    return pelevoShare(
      context: context,
      uri: parsed,
      title: title,
      subject: title,
    );
  }
  return pelevoShare(context: context, text: url, title: title, subject: title);
}

Future<ShareResult> pelevoShareFile({
  required BuildContext context,
  required File file,
  String? text,
  String? title,
  String mimeType = 'image/png',
}) {
  return pelevoShare(
    context: context,
    files: [XFile(file.path, mimeType: mimeType, name: file.uri.pathSegments.last)],
    text: text,
    title: title,
  );
}
