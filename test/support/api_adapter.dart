import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Test-only transport: never imported by the application.
class ApiAdapter implements HttpClientAdapter {
  ApiAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object? data, {
  int status = 200,
  Map<String, dynamic> meta = const {},
}) =>
    ResponseBody.fromString(
      jsonEncode({
        'ok': status < 400,
        'data': status < 400 ? data : null,
        'error':
            status >= 400
                ? {'code': 'UNAUTHENTICATED', 'message': 'Please sign in.'}
                : null,
        'meta': meta,
        'request_id': 'test-request',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody errorResponse({
  int status = 400,
  String code = 'UNAUTHENTICATED',
  String message = 'Please sign in.',
}) => ResponseBody.fromString(
  jsonEncode({
    'ok': false,
    'data': null,
    'error': {'code': code, 'message': message},
    'meta': {},
    'request_id': 'test-request',
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
