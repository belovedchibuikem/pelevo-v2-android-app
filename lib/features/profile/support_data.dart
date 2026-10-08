import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';

enum CmsDocument { help, about, terms, privacy, guidelines }

const _invalidContent = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'The server returned incomplete content. Please retry.',
);

String _requiredText(
  Map<String, dynamic> data,
  String key, {
  bool allowEmpty = false,
}) {
  final value = data[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw _invalidContent;
  }
  return value;
}

class CmsSection {
  const CmsSection({required this.title, required this.body});
  final String title, body;
}

class CmsPage {
  const CmsPage({
    required this.title,
    required this.intro,
    required this.sections,
    required this.version,
    required this.publishedAt,
  });
  final String title, intro;
  final List<CmsSection> sections;
  final int version;
  final DateTime publishedAt;

  factory CmsPage.fromApi(Map<String, dynamic> data, CmsDocument expected) {
    final rawSections = data['sections'];
    final version = data['version'];
    final published = data['published_at'];
    final date = published is String ? DateTime.tryParse(published) : null;
    if (data['slug'] != expected.name ||
        data['body_format'] != 'plain_text' ||
        rawSections is! List ||
        version is! int ||
        version < 1 ||
        date == null) {
      throw _invalidContent;
    }
    return CmsPage(
      title: _requiredText(data, 'title'),
      intro: _requiredText(data, 'intro', allowEmpty: true),
      version: version,
      publishedAt: date,
      sections: List.unmodifiable(
        rawSections.map((row) {
          if (row is! Map<String, dynamic>) throw _invalidContent;
          return CmsSection(
            title: _requiredText(row, 'title'),
            body: _requiredText(row, 'body', allowEmpty: true),
          );
        }),
      ),
    );
  }
}

class SupportReceipt {
  const SupportReceipt({required this.id, required this.state});
  final String id, state;
  factory SupportReceipt.fromApi(Map<String, dynamic> data) => SupportReceipt(
    id: _requiredText(data, 'id'),
    state: _requiredText(data, 'state'),
  );
}

String newSupportRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class SupportRepository {
  const SupportRepository(this._dio);
  final Dio _dio;

  Future<CmsPage> page(
    CmsDocument document, {
    CancelToken? cancelToken,
  }) async => CmsPage.fromApi(
    requireApiData(
      (await _dio.get<Map<String, dynamic>>(
        '/cms/${document.name}',
        cancelToken: cancelToken,
      )).data,
    ),
    document,
  );

  Future<SupportReceipt> ticket({
    required String subject,
    required String message,
    required String requestId,
  }) async => _submit('/support/tickets', {
    'subject': subject.trim(),
    'message': message.trim(),
    'priority': 'normal',
    'client_request_id': requestId,
  });

  Future<SupportReceipt> feedback({
    required String type,
    required String message,
    required String requestId,
    int? rating,
  }) async => _submit('/support/feedback', {
    'type': type,
    'message': message.trim(),
    if (type == 'rating') 'rating': rating,
    'client_request_id': requestId,
  });

  Future<SupportReceipt> _submit(
    String path,
    Map<String, dynamic> data,
  ) async => SupportReceipt.fromApi(
    requireApiData(
      (await _dio.post<Map<String, dynamic>>(path, data: data)).data,
    ),
  );
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(dioProvider)),
);
final cmsPageProvider = FutureProvider.autoDispose.family<CmsPage, CmsDocument>(
  (ref, document) {
    final token = CancelToken();
    ref.onDispose(() => token.cancel());
    return ref
        .watch(supportRepositoryProvider)
        .page(document, cancelToken: token);
  },
  retry: (retryCount, error) => null,
);
