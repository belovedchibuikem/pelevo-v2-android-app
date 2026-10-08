import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pelevo/features/share_cards/share_card_export.dart';

class FakeShareCardExporter implements ShareCardExporter {
  int captureCount = 0;
  int galleryCount = 0;
  int shareImageCount = 0;
  int shareTextCount = 0;
  int openGalleryCount = 0;
  bool failCapture = false;
  bool failGallery = false;

  @override
  Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    required double pixelRatio,
  }) async {
    captureCount += 1;
    if (failCapture) {
      throw ShareCardExportFailure('The share card preview is not ready to export.');
    }
    return Uint8List.fromList(const [137, 80, 78, 71]);
  }

  @override
  Future<File> writeTempPng(
    Uint8List bytes, {
    String prefix = 'pelevo-share',
  }) async {
    return File('${Directory.systemTemp.path}/$prefix-test.png');
  }

  @override
  Future<void> saveToGallery(
    Uint8List bytes, {
    String name = 'pelevo-share-card',
  }) async {
    galleryCount += 1;
    if (failGallery) {
      throw ShareCardExportFailure('Photo library access was denied.');
    }
  }

  @override
  Future<void> shareImage(
    File file, {
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    shareImageCount += 1;
  }

  @override
  Future<void> shareText(String text, {Rect? sharePositionOrigin}) async {
    shareTextCount += 1;
  }

  @override
  Future<void> openGallery() async {
    openGalleryCount += 1;
  }
}
