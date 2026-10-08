import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pelevo/features/reels/reel_limits.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReelCaptureSource { camera, gallery }

class ReelDraft {
  const ReelDraft({
    required this.id,
    required this.path,
    required this.source,
    required this.createdAt,
    this.caption = '',
    this.tag = 'Mindset',
    this.name = 'Untitled Reel',
  });

  final String id;
  final String path;
  final ReelCaptureSource source;
  final DateTime createdAt;
  final String caption;
  final String tag;
  final String name;

  ReelDraft copyWith({
    String? path,
    String? caption,
    String? tag,
    String? name,
  }) => ReelDraft(
    id: id,
    path: path ?? this.path,
    source: source,
    createdAt: createdAt,
    caption: caption ?? this.caption,
    tag: tag ?? this.tag,
    name: name ?? this.name,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'source': source.name,
    'createdAt': createdAt.toIso8601String(),
    'caption': caption,
    'tag': tag,
    'name': name,
  };

  factory ReelDraft.fromJson(Map<String, dynamic> json) => ReelDraft(
    id: json['id'] as String,
    path: json['path'] as String,
    source: ReelCaptureSource.values.firstWhere(
      (value) => value.name == json['source'],
      orElse: () => ReelCaptureSource.gallery,
    ),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    caption: json['caption'] as String? ?? '',
    tag: json['tag'] as String? ?? 'Mindset',
    name: json['name'] as String? ?? 'Untitled Reel',
  );
}

class ReelCreateService extends ChangeNotifier {
  ReelCreateService._();
  static final ReelCreateService instance = ReelCreateService._();

  static const _draftsKey = 'pelevo_reel_drafts_v1';
  final ImagePicker _picker = ImagePicker();

  final List<ReelDraft> drafts = [];
  ReelDraft? activeDraft;
  bool ready = false;
  String? lastError;

  Future<void> ensureLoaded() async {
    if (ready) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_draftsKey) ?? const [];
    drafts
      ..clear()
      ..addAll(
        raw.map((item) => ReelDraft.fromJson(jsonDecode(item) as Map<String, dynamic>)),
      );
    ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _draftsKey,
      drafts.map((draft) => jsonEncode(draft.toJson())).toList(),
    );
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (camera.isGranted && mic.isGranted) return true;
    if (camera.isPermanentlyDenied || mic.isPermanentlyDenied) {
      lastError = 'Camera permission is blocked. Enable it in Settings.';
      await openAppSettings();
      notifyListeners();
      return false;
    }
    lastError = 'Camera and microphone permission are required to record.';
    notifyListeners();
    return false;
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    if (photos.isGranted ||
        videos.isGranted ||
        photos.isLimited ||
        await Permission.storage.request().isGranted) {
      return true;
    }
    if (photos.isPermanentlyDenied || videos.isPermanentlyDenied) {
      lastError = 'Media permission is blocked. Enable it in Settings.';
      await openAppSettings();
      notifyListeners();
      return false;
    }
    lastError = 'Gallery permission is required to upload a reel.';
    notifyListeners();
    return false;
  }

  Future<String?> _persistPickedFile(XFile file) async {
    if (kIsWeb) return file.path;
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, 'reels'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final extension = p.extension(file.path).isEmpty ? '.mp4' : p.extension(file.path);
    final destPath = p.join(
      folder.path,
      'reel_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await file.saveTo(destPath);
    return destPath;
  }

  Future<ReelDraft?> captureFromCamera({
    Duration maxDuration = reelMaxDuration,
  }) async {
    lastError = null;
    if (!await _ensureCameraPermission()) return null;
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        lastError = 'Recording cancelled.';
        notifyListeners();
        return null;
      }
      final path = await _persistPickedFile(file);
      if (path == null) {
        lastError = 'Could not save the recorded video.';
        notifyListeners();
        return null;
      }
      final draft = ReelDraft(
        id: 'draft-${DateTime.now().millisecondsSinceEpoch}',
        path: path,
        source: ReelCaptureSource.camera,
        createdAt: DateTime.now(),
        name: 'Camera Reel',
      );
      activeDraft = draft;
      notifyListeners();
      return draft;
    } catch (error) {
      lastError = 'Unable to open camera: $error';
      notifyListeners();
      return null;
    }
  }

  Future<ReelDraft?> pickFromGallery({
    Duration maxDuration = reelMaxDuration,
  }) async {
    lastError = null;
    if (!await _ensureGalleryPermission()) return null;
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
      if (file == null) {
        lastError = 'Upload cancelled.';
        notifyListeners();
        return null;
      }
      final path = await _persistPickedFile(file);
      if (path == null) {
        lastError = 'Could not save the selected video.';
        notifyListeners();
        return null;
      }
      final draft = ReelDraft(
        id: 'draft-${DateTime.now().millisecondsSinceEpoch}',
        path: path,
        source: ReelCaptureSource.gallery,
        createdAt: DateTime.now(),
        name: p.basenameWithoutExtension(path),
      );
      activeDraft = draft;
      notifyListeners();
      return draft;
    } catch (error) {
      lastError = 'Unable to open gallery: $error';
      notifyListeners();
      return null;
    }
  }

  Future<String?> pickCoverImage() async {
    lastError = null;
    if (!await _ensureGalleryPermission()) return null;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null) {
        lastError = 'Cover selection cancelled.';
        notifyListeners();
        return null;
      }
      return _persistPickedFile(file);
    } catch (error) {
      lastError = 'Unable to open gallery: $error';
      notifyListeners();
      return null;
    }
  }

  Future<void> saveDraft(ReelDraft draft) async {
    final index = drafts.indexWhere((item) => item.id == draft.id);
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.insert(0, draft);
    }
    activeDraft = draft;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteDraft(String id) async {
    ReelDraft? existing;
    for (final item in drafts) {
      if (item.id == id) {
        existing = item;
        break;
      }
    }
    drafts.removeWhere((item) => item.id == id);
    if (activeDraft?.id == id) activeDraft = null;
    if (!kIsWeb && existing != null) {
      final file = File(existing.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _persist();
    notifyListeners();
  }

  void openDraft(ReelDraft draft) {
    activeDraft = draft;
    notifyListeners();
  }

  Future<ReelDraft?> publishActive() async {
    final draft = activeDraft;
    if (draft == null) return null;
    drafts.removeWhere((item) => item.id == draft.id);
    activeDraft = null;
    await _persist();
    notifyListeners();
    return draft;
  }
}
