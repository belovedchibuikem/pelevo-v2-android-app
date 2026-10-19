import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pelevo/app.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/network/api_environment.dart';

/// Maps App Links / Universal Links / custom schemes into go_router locations.
abstract final class PelevoDeepLinks {
  static StreamSubscription<Uri>? _sub;
  static var _bound = false;

  static Future<void> bind() async {
    if (_bound || kIsWeb) return;
    _bound = true;
    final links = AppLinks();
    try {
      final initial = await links.getInitialLink();
      if (initial != null) {
        await open(initial);
      }
    } on Object {
      // Missing platform channel in tests is fine.
    }
    _sub = links.uriLinkStream.listen((uri) {
      unawaited(open(uri));
    });
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _bound = false;
  }

  static Future<void> open(Uri uri) async {
    final location = await locationFor(uri);
    if (location == null || location.isEmpty) return;
    pelevoRouter.go(location);
  }

  /// Converts an incoming URI into a go_router location.
  static Future<String?> locationFor(Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'pelevo') {
      return _fromCustomScheme(uri);
    }
    if (scheme == 'http' || scheme == 'https') {
      return _fromHttps(uri);
    }
    return null;
  }

  static String? _fromCustomScheme(Uri uri) {
    final host = uri.host.toLowerCase();
    final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    // pelevo://episode/{id}  OR  pelevo:///episode/{id}
    final kind = host.isNotEmpty ? host : (parts.isNotEmpty ? parts.first : '');
    final id =
        host.isNotEmpty
            ? (parts.isNotEmpty ? parts.first : '')
            : (parts.length > 1 ? parts[1] : '');
    if (kind.isEmpty || id.isEmpty) return null;
    return switch (kind) {
      'episode' => '/episodes/$id',
      'show' => '/shows/$id',
      'reel' => '/reels/$id',
      'creator' => '/creators/$id',
      'invite' => '/screen/auth-sign-in?invite=$id',
      's' => '/s/$id',
      _ => null,
    };
  }

  static Future<String?> _fromHttps(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != 'pelevo.com' &&
        host != 'www.pelevo.com' &&
        host != 'localhost' &&
        host != '10.0.2.2' &&
        !host.endsWith('.pelevo.com')) {
      // Still allow path-style handling when the OS delivered a pelevo path.
      if (!uri.path.startsWith('/s/') &&
          !uri.path.startsWith('/episodes/') &&
          !uri.path.startsWith('/shows/') &&
          !uri.path.startsWith('/reels/') &&
          !uri.path.startsWith('/creator/') &&
          !uri.path.startsWith('/creators/')) {
        return null;
      }
    }
    final segments = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first == 's') {
      return '/s/${segments[1]}';
    }
    if (segments.length >= 2 &&
        (segments.first == 'creator' || segments.first == 'creators')) {
      return '/creators/${segments[1]}';
    }
    if (segments.length >= 2 &&
        const {
          'episodes',
          'shows',
          'reels',
        }.contains(segments.first)) {
      return '/${segments[0]}/${segments[1]}';
    }
    return null;
  }

  /// Resolves `/s/{token}` via the public API into a catalog route.
  static Future<String?> resolveShareToken(String token, {Dio? dio}) async {
    final client =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiEnvironment.baseUrl,
            headers: const {'Accept': 'application/json'},
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );
    try {
      final body =
          (await client.get<Map<String, dynamic>>(
            '/s/${Uri.encodeComponent(token)}',
          )).data;
      final data = requireApiData(body);
      final type = '${data['subject_type'] ?? ''}';
      final id = '${data['subject_id'] ?? ''}';
      if (id.isEmpty) return null;
      final showId = data['show_id']?.toString();
      return switch (type) {
        'episode' =>
          showId == null || showId.isEmpty
              ? '/episodes/$id'
              : '/episodes/$id?showId=$showId',
        'show' => '/shows/$id',
        'reel' => '/reels/$id',
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}
