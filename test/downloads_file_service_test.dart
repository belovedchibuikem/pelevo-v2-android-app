import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pelevo/features/downloads/download_file_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/api_adapter.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'downloads publisher audio without sending it through the API client',
    () async {
      final dir = await Directory.systemTemp.createTemp('pelevo_dl');
      addTearDown(() => dir.delete(recursive: true));
      PathProviderPlatform.instance = _FakePathProvider(dir.path);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final api = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      var apiHits = 0;
      api.httpClientAdapter = ApiAdapter((request) {
        apiHits++;
        throw StateError('API should not fetch ${request.uri}');
      });

      final media = Dio();
      var mediaHits = 0;
      media.httpClientAdapter = ApiAdapter((request) {
        mediaHits++;
        expect(
          request.uri.toString(),
          'https://cdn.example.invalid/shift-life.mp3',
        );
        expect(
          request.headers['User-Agent'],
          'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)',
        );
        return ResponseBody.fromBytes(
          List<int>.filled(64, 1),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/mpeg'],
            Headers.contentLengthHeader: ['64'],
          },
        );
      });

      final service = DownloadFileService(
        prefs,
        api,
        media: media,
        userAgent: 'Pelevo/1.0.0 (Linux; Android 14; SM-S911U)',
      );
      addTearDown(service.dispose);

      final record = await service.downloadEpisode(
        episodeId: 'ep-1',
        url: 'https://cdn.example.invalid/shift-life.mp3',
      );

      expect(apiHits, 0);
      expect(mediaHits, 1);
      expect(File(record.path).existsSync(), isTrue);
      expect(record.bytes, 64);
    },
  );
}
