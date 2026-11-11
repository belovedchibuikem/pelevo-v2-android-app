/// Canonical podcast feed address used for duplicate detection.
class FeedAddress {
  const FeedAddress({required this.uri, required this.key});

  final Uri uri;

  /// Scheme-insensitive identity. `http` and `https` copies of the same
  /// path are one podcast, and tracking parameters are ignored.
  final String key;

  static final _tracking = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'utm_id',
    'fbclid',
    'gclid',
    'mc_cid',
    'mc_eid',
    'igshid',
  };

  static bool looksLikeUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Null when [raw] is not an http(s) URL or the host is not a public feed.
  static FeedAddress? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (!isPublicHost(uri.host)) return null;
    final normalized = _normalize(uri);
    if (!isPublicHost(normalized.host)) return null;
    return FeedAddress(uri: normalized, key: _key(normalized));
  }

  static Uri _normalize(Uri uri) {
    final kept = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      if (_tracking.contains(key.toLowerCase()) || value.isEmpty) return;
      kept[key] = value;
    });
    final names = kept.keys.toList()..sort();
    var path = uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) path = '/';
    final dropPort =
        !uri.hasPort ||
        (uri.scheme == 'https' && uri.port == 443) ||
        (uri.scheme == 'http' && uri.port == 80);
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: dropPort ? null : uri.port,
      path: path,
      queryParameters:
          names.isEmpty ? null : {for (final name in names) name: kept[name]!},
    );
  }

  static String _key(Uri uri) =>
      '${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';

  static bool isPublicHost(String host) {
    final value = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
    if (value.isEmpty ||
        value == 'localhost' ||
        value.endsWith('.local') ||
        value.endsWith('.localhost') ||
        value.endsWith('.internal') ||
        value.endsWith('.localdomain')) {
      return false;
    }
    final ipv4 = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
    ).firstMatch(value);
    if (ipv4 != null) {
      final parts = <int>[];
      for (var index = 1; index <= 4; index++) {
        final octet = int.parse(ipv4.group(index)!);
        if (octet > 255) return false;
        parts.add(octet);
      }
      final a = parts[0];
      final b = parts[1];
      if (a == 0 || a == 10 || a == 127 || a >= 224) return false;
      if (a == 169 && b == 254) return false;
      if (a == 192 && b == 168) return false;
      if (a == 172 && b >= 16 && b <= 31) return false;
      return true;
    }
    if (value.contains(':')) return false;
    return value.contains('.');
  }
}
