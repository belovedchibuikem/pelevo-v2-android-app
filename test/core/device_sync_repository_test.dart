import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/device_sync/device_sync_data.dart';
import '../support/api_adapter.dart';
import '../support/device_sync_fixture.dart';

void main() {
  DeviceSyncRepository repository(Dio dio) => DeviceSyncRepository(dio);

  Dio dioWith(ApiAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  test('devices and pull omit payloads', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        if (request.path == '/devices') {
          return jsonResponse([syncDeviceFixture()]);
        }
        if (request.path == '/sync/pull') {
          return jsonResponse([syncChangeFixture()]);
        }
        if (request.path == '/sync/conflicts') {
          return jsonResponse([syncConflictFixture()]);
        }
        throw StateError('${request.method} ${request.path}');
      }),
    );
    final token = CancelToken();
    final devices = await repository(dio).devices(token);
    expect(devices.single.name, 'iPhone 15 Pro');
    final pull = await repository(dio).pull(token);
    expect(pull.single.resourceType, 'playlist');
    final conflicts = await repository(dio).conflicts(token);
    expect(conflicts.single.id, 'sync-conflict-1');
  });

  test('pairing code uses the server code', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.path, '/devices/pairing-code');
        return jsonResponse(pairingCodeFixture(code: 'ZXCV9876'), status: 201);
      }),
    );
    final code = await repository(dio).pairingCode();
    expect(code.code, 'ZXCV9876');
    expect(code.expiresIn, 600);
  });

  test('restore posts the backup id', () async {
    final dio = dioWith(
      ApiAdapter((request) {
        expect(request.method, 'POST');
        expect(request.path, '/backups/backup-1/restore');
        return jsonResponse({'restored': true});
      }),
    );
    await repository(dio).restoreBackup('backup-1');
  });
}
