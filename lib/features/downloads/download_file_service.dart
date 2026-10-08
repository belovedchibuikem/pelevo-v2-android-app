import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDownloadRecord {
  const LocalDownloadRecord({
    required this.episodeId,
    required this.path,
    required this.savedAt,
    this.bytes,
  });

  final String episodeId;
  final String path;
  final DateTime savedAt;
  final int? bytes;

  Map<String, dynamic> toJson() => {
    'episodeId': episodeId,
    'path': path,
    'savedAt': savedAt.toIso8601String(),
    'bytes': bytes,
  };

  factory LocalDownloadRecord.fromJson(Map<String, dynamic> json) =>
      LocalDownloadRecord(
        episodeId: json['episodeId'] as String,
        path: json['path'] as String,
        savedAt:
            DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
        bytes: json['bytes'] as int?,
      );
}

class DownloadFileService {
  DownloadFileService(this._prefs, this._dio, {Dio? media, String? userAgent})
    : _userAgent = userAgent ?? PelevoUserAgent.current,
      _media =
          media ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 10),
              followRedirects: true,
              maxRedirects: 8,
              responseType: ResponseType.bytes,
              headers: {
                'Accept': '*/*',
                'User-Agent': userAgent ?? PelevoUserAgent.current,
              },
            ),
          );

  static const _key = 'pelevo_local_downloads_v1';

  final SharedPreferences _prefs;
  final Dio _dio;
  final Dio _media;
  final String _userAgent;
  final Map<String, LocalDownloadRecord> _records = {};
  bool _loaded = false;

  void dispose() {
    if (!identical(_media, _dio)) {
      _media.close(force: true);
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = _prefs.getStringList(_key) ?? const [];
    _records
      ..clear()
      ..addEntries(
        raw.map((row) {
          final record = LocalDownloadRecord.fromJson(
            jsonDecode(row) as Map<String, dynamic>,
          );
          return MapEntry(record.episodeId, record);
        }),
      );
    _loaded = true;
  }

  Future<void> _persist() async {
    await _prefs.setStringList(
      _key,
      _records.values.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<LocalDownloadRecord?> recordFor(String episodeId) async {
    await ensureLoaded();
    final record = _records[episodeId];
    if (record == null) return null;
    if (!kIsWeb && !await File(record.path).exists()) {
      _records.remove(episodeId);
      await _persist();
      return null;
    }
    return record;
  }

  Future<String?> localPath(String episodeId) async =>
      (await recordFor(episodeId))?.path;

  Future<bool> isDownloaded(String episodeId) async =>
      await localPath(episodeId) != null;

  Future<LocalDownloadRecord> downloadEpisode({
    required String episodeId,
    required String url,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) async {
    if (kIsWeb) {
      throw const ApiFailure(
        code: 'UNSUPPORTED',
        message: 'Offline downloads are not available on web.',
      );
    }
    await ensureLoaded();
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'pelevo_downloads'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final extension = _extensionFor(url);
    final target = File(p.join(folder.path, '$episodeId$extension'));
    final tmp = File('${target.path}.part');
    try {
      await _transfer(
        episodeId: episodeId,
        url: url,
        savePath: tmp.path,
        headers: headers,
        onProgress: onProgress,
      );
      if (await target.exists()) {
        await target.delete();
      }
      await tmp.rename(target.path);
      final bytes = await target.length();
      final record = LocalDownloadRecord(
        episodeId: episodeId,
        path: target.path,
        savedAt: DateTime.now(),
        bytes: bytes,
      );
      _records[episodeId] = record;
      await _persist();
      return record;
    } on DioException catch (error) {
      if (await tmp.exists()) {
        await tmp.delete();
      }
      throw apiFailureFromDio(error);
    }
  }

  Future<void> _transfer({
    required String episodeId,
    required String url,
    required String savePath,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) async {
    Future<void> get(Dio client, String target) {
      return client.download(
        target,
        savePath,
        options: Options(
          headers: {...?headers, 'User-Agent': _userAgent},
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: onProgress,
      );
    }

    try {
      await get(_clientFor(url), url);
    } on DioException {
      if (_isApiUrl(url)) {
        rethrow;
      }
      await get(_dio, '/episodes/${Uri.encodeComponent(episodeId)}/stream');
    }
  }

  Dio _clientFor(String url) => _isApiUrl(url) ? _dio : _media;

  bool _isApiUrl(String url) {
    final uri = Uri.tryParse(url);
    final base = Uri.tryParse(_dio.options.baseUrl);
    if (uri == null || base == null || !uri.hasScheme) {
      return true;
    }
    return uri.origin == base.origin;
  }

  Future<int> clearAll() async {
    await ensureLoaded();
    final ids = _records.keys.toList(growable: false);
    for (final id in ids) {
      await deleteLocal(id);
    }
    return ids.length;
  }

  Future<void> deleteLocal(String episodeId) async {
    await ensureLoaded();
    final record = _records.remove(episodeId);
    await _persist();
    if (record != null && !kIsWeb) {
      final file = File(record.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _extensionFor(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.mp3')) return '.mp3';
    if (path.endsWith('.m4a')) return '.m4a';
    if (path.endsWith('.aac')) return '.aac';
    if (path.endsWith('.ogg')) return '.ogg';
    return '.audio';
  }
}

final downloadFileServiceProvider = Provider<DownloadFileService>((ref) {
  final service = DownloadFileService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(dioProvider),
    userAgent: ref.watch(pelevoUserAgentProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
