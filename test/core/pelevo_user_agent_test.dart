import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';

void main() {
  tearDown(() => PelevoUserAgent.setResolved(null));

  test('formats IAB iOS and Android player strings', () {
    expect(
      PelevoUserAgent.format(
        version: '2.1.0',
        device: 'iPhone',
        os: 'iOS 17.5',
        locale: 'en-US',
      ),
      'Pelevo/2.1.0 (iPhone; iOS 17.5; en-US)',
    );
    expect(
      PelevoUserAgent.format(
        version: '2.1.0',
        device: 'Mobile',
        os: 'Android 14',
        locale: 'en-US',
      ),
      'Pelevo/2.1.0 (Mobile; Android 14; en-US)',
    );
  });

  test(
    'platform fallbacks stay Pelevo-branded and never impersonate hosts',
    () {
      final ios = PelevoUserAgent.formatForPlatform(
        version: '1.0.0',
        platform: TargetPlatform.iOS,
        osVersion: '17.5',
        locale: 'en-US',
      );
      final android = PelevoUserAgent.formatForPlatform(
        version: '1.0.0',
        platform: TargetPlatform.android,
        osVersion: '14',
        locale: 'en-US',
      );
      expect(ios, 'Pelevo/1.0.0 (iPhone; iOS 17.5; en-US)');
      expect(android, 'Pelevo/1.0.0 (Mobile; Android 14; en-US)');
      for (final value in [ios, android]) {
        expect(value, isNot(contains('Mozilla/')));
        expect(value, isNot(contains('okhttp')));
        expect(value, isNot(contains('CFNetwork')));
        expect(value, isNot(contains('Spotify')));
        expect(value, isNot(contains('Apple Podcasts')));
      }
    },
  );

  test(
    'sends the same Pelevo UA on third-party audio without auth headers',
    () {
      const ua = 'Pelevo/1.0.0 (Mobile; Android 14; en-US)';
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
    const ua = 'Pelevo/1.0.0 (iPhone; iOS 17.5; en-US)';
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
        userAgent: 'Pelevo/1.0.0 (Mobile; Android 14; en-US)',
        audioUri: 'https://cdn.example.invalid/a.mp3',
        isLocal: true,
      ),
      isNull,
    );
    expect(
      PelevoUserAgent.playbackHeaders(
        userAgent: 'Pelevo/1.0.0 (Web; Web; en-US)',
        audioUri: 'https://cdn.example.invalid/a.mp3',
        isLocal: false,
        isWeb: true,
      ),
      isNull,
    );
  });
}
