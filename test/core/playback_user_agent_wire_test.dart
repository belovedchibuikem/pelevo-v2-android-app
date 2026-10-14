import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/pelevo_user_agent.dart';

void main() {
  test('a podcast host receives the Pelevo User-Agent on the media request', () async {
    const ua = 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)';
    final stamped = PelevoUserAgent.mediaRequestHeaders(
      userAgent: ua,
      uri: Uri.parse('https://cdn.example.invalid/shift-life.mp3'),
    );
    expect(stamped, isNotNull);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final captured = <String, String>{};
    server.listen((request) async {
      captured['method'] = request.method;
      captured['path'] = request.uri.path;
      captured['userAgent'] =
          request.headers.value(HttpHeaders.userAgentHeader) ?? '';
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      await request.response.close();
    });

    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.get(
      server.address.host,
      server.port,
      '/shift-life.mp3',
    );
    // ExoPlayer DefaultHttpDataSource.setUserAgent replaces the stack default.
    request.headers.set(
      HttpHeaders.userAgentHeader,
      stamped![PelevoUserAgent.headerName]!,
    );
    final response = await request.close();
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.ok);
    expect(captured['method'], 'GET');
    expect(captured['path'], '/shift-life.mp3');
    expect(captured['userAgent'], ua);
    expect(captured['userAgent'], isNot(contains('just_audio')));
    expect(captured['userAgent'], isNot(contains('Dalvik')));
    expect(captured['userAgent'], isNot(contains('okhttp')));
    expect(captured['userAgent'], isNot(contains('ExoPlayer')));
    expect(captured['userAgent'], isNot(contains('AndroidXMedia3')));
  });
}
