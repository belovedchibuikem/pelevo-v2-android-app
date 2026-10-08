import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareCardExportFailure implements Exception {
  ShareCardExportFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class ShareCardGallerySave {
  const ShareCardGallerySave({required this.succeeded, this.message});
  final bool succeeded;
  final String? message;
}

abstract class ShareCardExporter {
  Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    required double pixelRatio,
  });

  Future<File> writeTempPng(Uint8List bytes, {String prefix = 'pelevo-share'});

  Future<void> saveToGallery(
    Uint8List bytes, {
    String name = 'pelevo-share-card',
  });

  Future<void> shareImage(
    File file, {
    String? text,
    Rect? sharePositionOrigin,
  });

  Future<void> shareText(String text, {Rect? sharePositionOrigin});

  Future<void> openGallery();
}

class DeviceShareCardExporter implements ShareCardExporter {
  @override
  Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    required double pixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw ShareCardExportFailure(
        'The share card preview is not ready to export.',
      );
    }
    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw ShareCardExportFailure(
        'The share card preview is not ready to export.',
      );
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw ShareCardExportFailure('Could not encode the share card image.');
    }
    return data.buffer.asUint8List();
  }

  @override
  Future<File> writeTempPng(
    Uint8List bytes, {
    String prefix = 'pelevo-share',
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/$prefix-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Future<void> saveToGallery(
    Uint8List bytes, {
    String name = 'pelevo-share-card',
  }) async {
    final allowed = await Gal.requestAccess();
    if (!allowed) {
      throw ShareCardExportFailure('Photo library access was denied.');
    }
    await Gal.putImageBytes(bytes, name: name, album: 'Pelevo');
  }

  @override
  Future<void> shareImage(
    File file, {
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
        title: 'Pelevo',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  @override
  Future<void> shareText(String text, {Rect? sharePositionOrigin}) async {
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      await SharePlus.instance.share(
        ShareParams(
          uri: uri,
          title: 'Pelevo',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: sharePositionOrigin),
    );
  }

  @override
  Future<void> openGallery() => Gal.open();
}

final shareCardExporterProvider = Provider<ShareCardExporter>(
  (ref) => DeviceShareCardExporter(),
);

class ShareCardGallerySaveNotifier extends Notifier<ShareCardGallerySave?> {
  @override
  ShareCardGallerySave? build() => null;

  void setResult(ShareCardGallerySave? value) => state = value;
}

final shareCardGallerySaveProvider =
    NotifierProvider<ShareCardGallerySaveNotifier, ShareCardGallerySave?>(
      ShareCardGallerySaveNotifier.new,
    );
