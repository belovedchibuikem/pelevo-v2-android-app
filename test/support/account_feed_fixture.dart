import 'dart:convert';
import 'package:dio/dio.dart';

Map<String, dynamic> notificationFixture(
  String id, {
  bool read = false,
  String type = 'mention',
  String? title,
  String? body,
  Map<String, dynamic>? data,
}) => {
  'id': id,
  'title': title ?? 'Server notification $id',
  'body': body ?? 'Stored message $id',
  'type': type,
  'created_at': '2026-09-09T12:00:00Z',
  'read_at': read ? '2026-09-09T13:00:00Z' : null,
  'dismissed_at': null,
  if (data != null) 'data': data,
};
Map<String, dynamic> followedShowFixture(String id) => {
  'id': id,
  'title': 'Server show $id',
  'author': 'Server author',
  'artwork_url': null,
  'followed_at': '2026-09-09T12:00:00Z',
};
ResponseBody feedResponse(
  List<Map<String, dynamic>> items, {
  String? cursor,
  int unread = 0,
}) => ResponseBody.fromString(
  jsonEncode({
    'ok': true,
    'data': items,
    'meta': {
      'has_more': cursor != null,
      'cursor': cursor,
      'unread_count': unread,
    },
  }),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
