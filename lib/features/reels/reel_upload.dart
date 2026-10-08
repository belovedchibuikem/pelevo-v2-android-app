import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/reels/reel_limits.dart';

/// Point local signed PUT URLs at the API origin the app already uses.
///
/// Reservations are signed with APP_URL (often localhost). Emulators and
/// phones cannot reach that host even though JSON calls to 10.0.2.2 / LAN
/// already work. Object-storage URLs are left unchanged.
@visibleForTesting
Uri resolveReelUploadUrl(String uploadUrl, String apiBaseUrl) {
  final api = Uri.parse(apiBaseUrl);
  final trimmed = uploadUrl.trim();
  final upload = Uri.parse(trimmed);
  if (!upload.hasScheme || upload.host.isEmpty) {
    return api.resolve(trimmed);
  }
  if (_isObjectStoragePut(upload) || !_isPelevoUploadPut(upload)) {
    return upload;
  }
  if (upload.origin == api.origin) {
    return upload;
  }
  return Uri(
    scheme: api.scheme,
    host: api.host,
    port: api.hasPort ? api.port : null,
    path: upload.path,
    query: upload.hasQuery ? upload.query : null,
  );
}

bool _isPelevoUploadPut(Uri uri) {
  final path = uri.path;
  return path.contains('/uploads/') && path.endsWith('/content');
}

bool _isObjectStoragePut(Uri uri) {
  final host = uri.host.toLowerCase();
  final query = uri.queryParameters;
  return host.contains('amazonaws.com') ||
      host.contains('r2.cloudflarestorage.com') ||
      host.contains('storage.googleapis.com') ||
      host.contains('googleapis.com') ||
      host.contains('mux.com') ||
      host.contains('supabase.co') ||
      host.contains('s3.') ||
      query.containsKey('X-Amz-Algorithm') ||
      query.containsKey('X-Amz-Signature') ||
      query.containsKey('X-Amz-Credential');
}

class ReelUploadReservation {
  const ReelUploadReservation({
    required this.id,
    required this.uploadUrl,
    required this.headers,
  });

  final String id;
  final String uploadUrl;
  final Map<String, String> headers;
}

class ReelPublishResult {
  const ReelPublishResult({
    required this.id,
    required this.state,
    this.truncated = false,
    this.truncatedMessage,
  });

  final String id;
  final String state;
  final bool truncated;
  final String? truncatedMessage;
}

/// Reserves a media upload, PUTs bytes, completes processing, then publishes.
class ReelUploadRepository {
  ReelUploadRepository(this._dio);

  final Dio _dio;

  Future<ReelPublishResult> publishFile({
    required File file,
    String? title,
    String? caption,
    String? draftId,
    String? episodeId,
    String? showId,
    void Function(String stage)? onStage,
    void Function(String stage, double? progress)? onProgress,
  }) async {
    void report(String stage, [double? progress]) {
      onStage?.call(stage);
      onProgress?.call(stage, progress);
    }

    if (!await file.exists()) {
      throw const ApiFailure(
        code: 'MISSING_FILE',
        message: 'The reel video file is missing on this device.',
      );
    }
    final bytes = await file.length();
    if (bytes <= 0) {
      throw const ApiFailure(
        code: 'EMPTY_FILE',
        message: 'The reel video file is empty.',
      );
    }
    final mime = _mimeFor(file.path);
    report('Reserving upload…');
    final reservation = await _reserve(
      mime: mime,
      size: bytes,
    );
    report('Uploading video…', 0);
    await _putBytes(
      reservation,
      file,
      mime,
      onSendProgress: (sent, total) {
        if (total > 0) {
          report('Uploading video…', (sent / total).clamp(0, 1));
        }
      },
    );
    report('Processing video…');
    await _complete(reservation.id);
    final processedId = await _waitProcessed(reservation.id, report);
    report('Publishing reel…');
    return _createReel(
      uploadId: processedId,
      title: title,
      caption: caption,
      draftId: draftId,
      episodeId: episodeId,
      showId: showId,
    );
  }

  String _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  Future<ReelUploadReservation> _reserve({
    required String mime,
    required int size,
  }) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/uploads',
          data: {
            'mime': mime,
            'size': size,
          },
          options: _mediaOptions(),
        )).data,
      );
      final id = data['id'];
      final url = data['upload_url'];
      if (id is! String || url is! String || url.isEmpty) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Upload reservation was incomplete.',
        );
      }
      final headers = <String, String>{};
      final rawHeaders = data['upload_headers'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((key, value) {
          if (key != null && value != null) {
            headers['$key'] = '$value';
          }
        });
      }
      return ReelUploadReservation(
        id: id,
        uploadUrl: url,
        headers: headers,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> _putBytes(
    ReelUploadReservation reservation,
    File file,
    String mime, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final target = resolveReelUploadUrl(
      reservation.uploadUrl,
      _dio.options.baseUrl,
    );
    if (!_isObjectStoragePut(target)) {
      try {
        await _putViaSession(
          reservation.id,
          file,
          mime,
          onSendProgress: onSendProgress,
        );
        return;
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status != 404 && status != 405) {
          throw apiFailureFromDio(error);
        }
      }
    }
    await _putDirect(
      target,
      reservation,
      file,
      mime,
      onSendProgress: onSendProgress,
    );
  }

  Future<void> _putViaSession(
    String uploadId,
    File file,
    String mime, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final name =
        file.uri.pathSegments.isEmpty ? 'reel.mp4' : file.uri.pathSegments.last;
    final response = await _dio.post<dynamic>(
      '/uploads/$uploadId/content',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: name,
          contentType: DioMediaType.parse(mime),
        ),
      }),
      options: _mediaOptions(),
      onSendProgress: onSendProgress,
    );
    _throwIfUploadRejected(response.data);
  }

  Future<void> _putDirect(
    Uri target,
    ReelUploadReservation reservation,
    File file,
    String mime, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final length = await file.length();
    final headers = <String, dynamic>{
      Headers.contentLengthHeader: length,
      ...reservation.headers,
    };
    if (!_isObjectStoragePut(target)) {
      headers.putIfAbsent('Content-Type', () => mime);
      final userAgent = _dio.options.headers['User-Agent'];
      if (userAgent != null) {
        headers.putIfAbsent('User-Agent', () => userAgent);
        headers.putIfAbsent('Accept', () => 'application/json');
      }
    } else {
      headers.putIfAbsent('Content-Type', () => 'application/octet-stream');
    }
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 3),
        followRedirects: false,
      ),
    );
    try {
      final response = await client.put<dynamic>(
        target.toString(),
        data: file.openRead(),
        onSendProgress: onSendProgress,
        options: Options(
          headers: headers,
          contentType: headers['Content-Type']?.toString(),
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );
      _throwIfUploadRejected(response.data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    } finally {
      client.close();
    }
  }

  void _throwIfUploadRejected(Object? body) {
    if (body is Map && body['ok'] == false) {
      final error = body['error'];
      if (error is Map &&
          error['code'] is String &&
          error['message'] is String) {
        throw ApiFailure(
          code: error['code'] as String,
          message: error['message'] as String,
        );
      }
      throw const ApiFailure(
        code: 'UPLOAD_FAILED',
        message: 'The reel upload was rejected.',
      );
    }
  }

  Options _mediaOptions() => Options(
    sendTimeout: const Duration(minutes: 5),
    receiveTimeout: const Duration(minutes: 3),
  );

  Future<void> _complete(String uploadId) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/uploads/$uploadId/complete',
          options: _mediaOptions(),
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<String> _waitProcessed(
    String uploadId,
    void Function(String stage, [double? progress]) report,
  ) async {
    const timeout = Duration(minutes: 2);
    final started = DateTime.now();
    var misses = 0;
    while (DateTime.now().difference(started) < timeout) {
      try {
        final data = requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/uploads/$uploadId',
            options: _mediaOptions(),
          )).data,
        );
        misses = 0;
        final state = data['state'];
        final elapsed = DateTime.now().difference(started);
        if (state == 'processed') return uploadId;
        if (state == 'failed') {
          throw const ApiFailure(
            code: 'UPLOAD_FAILED',
            message: 'Video processing failed. Please try another clip.',
          );
        }
        if (state == 'rejected') {
          final reason = data['failure_reason'];
          throw ApiFailure(
            code: 'UPLOAD_REJECTED',
            message:
                reason == 'UPLOAD_TOO_LONG'
                    ? 'Reels may not exceed $reelMaxDurationLabel.'
                    : reason == 'CHECKSUM_MISMATCH'
                    ? 'The video file was damaged during upload. Please try again.'
                    : reason is String && reason.isNotEmpty
                    ? 'Upload rejected: $reason'
                    : 'The uploaded reel was rejected during processing.',
          );
        }
        if (state == 'queued' && elapsed > const Duration(seconds: 20)) {
          throw const ApiFailure(
            code: 'QUEUE_STALLED',
            message:
                'Pelevo has not started processing this video. On the server, Horizon must be running and listening to the media queue.',
          );
        }
        report(
          state == 'processing'
              ? 'Encoding your reel…'
              : 'Waiting for processing to start…',
        );
      } on ApiFailure {
        rethrow;
      } on DioException catch (error) {
        misses += 1;
        if (misses >= 3) {
          throw apiFailureFromDio(error);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    throw const ApiFailure(
      code: 'UPLOAD_TIMEOUT',
      message:
          'Video processing timed out. Confirm Horizon is running, then try again.',
    );
  }

  Future<ReelPublishResult> _createReel({
    required String uploadId,
    String? title,
    String? caption,
    String? draftId,
    String? episodeId,
    String? showId,
  }) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reels',
          data: {
            'upload_id': uploadId,
            if (title != null && title.isNotEmpty) 'title': title,
            if (caption != null && caption.isNotEmpty) 'caption': caption,
            if (draftId != null) 'draft_id': draftId,
            if (episodeId != null) 'episode_id': episodeId,
            if (showId != null) 'show_id': showId,
          },
          options: _mediaOptions(),
        )).data,
      );
      final id = data['id'];
      final state = data['state'];
      if (id is! String) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Published reel id was missing.',
        );
      }
      return ReelPublishResult(
        id: id,
        state: state is String ? state : 'processing',
        truncated: data['truncated'] == true,
        truncatedMessage:
            data['truncated_message'] is String
                ? data['truncated_message'] as String
                : null,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> uploadCover({
    required String reelId,
    required File file,
  }) async {
    if (!await file.exists()) {
      throw const ApiFailure(
        code: 'MISSING_FILE',
        message: 'The cover image is missing on this device.',
      );
    }
    try {
      final name = file.uri.pathSegments.isEmpty
          ? 'cover.jpg'
          : file.uri.pathSegments.last;
      await _dio.post<Map<String, dynamic>>(
        '/reels/$reelId/cover',
        data: FormData.fromMap({
          'cover': await MultipartFile.fromFile(file.path, filename: name),
        }),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final reelUploadRepositoryProvider = Provider(
  (ref) => ReelUploadRepository(ref.watch(dioProvider)),
);
