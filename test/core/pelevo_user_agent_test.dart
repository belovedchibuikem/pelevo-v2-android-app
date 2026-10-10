import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';

void main() {
  tearDown(() => PelevoUserAgent.setResolved(null));

  test('formats the IAB player string hosts read on media requests', () {
    expect(
      PelevoUserAgent.format(
        version: '1.0.0',
        system: 'Linux',
        os: 'Android 14',
        device: 'SM-S911U',
      ),
      'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)',
    );
    expect(
      PelevoUserAgent.format(
        version: '2.1.0',
        system: 'iPhone',
        os: 'iOS 17.5',
        device: 'iPhone15,2',
      ),
      'Pelevo/2.1.0 (iPhone; iOS 17.5; iPhone15,2)',
    );
  });

  test(
    'platform fallbacks stay Pelevo-branded and never impersonate hosts',
    () {
      final ios = PelevoUserAgent.formatForPlatform(
        version: '1.0.0',
        platform: TargetPlatform.iOS,
        osVersion: '17.5',
        deviceModel: 'iPhone15,2',
      );
      final android = PelevoUserAgent.formatForPlatform(
        version: '1.0.0',
        platform: TargetPlatform.android,
        osVersion: '14',
        deviceModel: 'SM-S911U',
      );
      expect(ios, 'Pelevo/1.0.0 (iPhone; iOS 17.5; iPhone15,2)');
      expect(android, 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)');
      for (final value in [ios, android]) {
        expect(value, isNot(contains('Mozilla/')));
        expect(value, isNot(contains('okhttp')));
        expect(value, isNot(contains('CFNetwork')));
        expect(value, isNot(contains('just_audio')));
        expect(value, isNot(contains('ExoPlayer')));
        expect(value, isNot(contains('Spotify')));
        expect(value, isNot(contains('Apple Podcasts')));
      }
    },
  );

  test('stamps the IAB User-Agent onto remote media requests', () {
    const ua = 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)';
    final headers = PelevoUserAgent.mediaRequestHeaders(
      userAgent: ua,
      uri: Uri.parse('https://cdn.example.invalid/shift-life.mp3'),
      headers: const {'Accept': '*/*'},
    );
    expect(headers, {'Accept': '*/*', 'User-Agent': ua});
  });

  test(
    'sends the same Pelevo UA on third-party audio without auth headers',
    () {
      const ua = 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)';
      final headers = PelevoUserAgent.playbackHeaders(
        userAgent: ua,
        audioUri: 'https://cdn.example.invalid/shift-life.mp3',
        isLocal: false,
        accessToken: 'secret-token',
        deviceId: 'device-a',
      );
      expect(headers, {'User-Agent': ua});
    },
  );

  test('keeps first-party auth while still identifying Pelevo', () {
    const ua = 'Pelevo/1.0.0 (iPhone; iOS 17.5; iPhone15,2)';
    final headers = PelevoUserAgent.playbackHeaders(
      userAgent: ua,
      audioUri: 'https://media.pelevo.com/episodes/1.m4a',
      isLocal: false,
      accessToken: 'secret-token',
      deviceId: 'device-a',
    );
    expect(headers, {
      'User-Agent': ua,
      'Authorization': 'Bearer secret-token',
      'X-Device-Id': 'device-a',
    });
  });

  test('omits headers for local files and web media elements', () {
    expect(
      PelevoUserAgent.playbackHeaders(
        userAgent: 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)',
        audioUri: 'https://cdn.example.invalid/a.mp3',
        isLocal: true,
      ),
      isNull,
    );
    expect(
      PelevoUserAgent.mediaRequestHeaders(
        userAgent: 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)',
        uri: Uri.file('/tmp/episode.mp3'),
      ),
      isNull,
    );
    expect(
      PelevoUserAgent.playbackHeaders(
        userAgent: 'Pelevo/1.0.0 (Web; Web; Web)',
        audioUri: 'https://cdn.example.invalid/a.mp3',
        isLocal: false,
        isWeb: true,
      ),
      isNull,
    );
    expect(
      PelevoUserAgent.mediaRequestHeaders(
        userAgent: 'Pelevo/1.0.0 (Web; Web; Web)',
        uri: Uri.parse('https://cdn.example.invalid/a.mp3'),
        headers: const {'Accept': '*/*'},
        isWeb: true,
      ),
      {'Accept': '*/*'},
    );
  });
}
