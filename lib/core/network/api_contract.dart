class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    this.fields = const {},
    this.requestId,
    this.statusCode,
  });

  final String code;
  final String message;
  final Map<String, String> fields;
  final String? requestId;
  final int? statusCode;

  @override
  String toString() => message;
}

Map<String, dynamic> requireApiData(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    final error = body?['error'];
    final errorMap =
        error is Map
            ? Map<String, dynamic>.from(error)
            : const <String, dynamic>{};
    final rawFields = errorMap['fields'];
    final fields = <String, String>{};
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        final value = entry.value;
        fields['${entry.key}'] = value is List ? value.join('\n') : '$value';
      }
    }
    final fieldMessage =
        fields.isEmpty
            ? null
            : fields.values.where((value) => value.trim().isNotEmpty).join('\n');
    throw ApiFailure(
      code: '${errorMap['code'] ?? 'INVALID_RESPONSE'}',
      message:
          fieldMessage ??
          '${errorMap['message'] ?? body?['message'] ?? 'The server returned an invalid response.'}',
      fields: fields,
      requestId: body?['request_id'] as String?,
    );
  }
  final data = body['data'];
  if (data is! Map) {
    throw const ApiFailure(
      code: 'INVALID_RESPONSE',
      message: 'The server returned an invalid response.',
    );
  }
  return Map<String, dynamic>.from(data);
}

Map<String, dynamic>? asApiJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
