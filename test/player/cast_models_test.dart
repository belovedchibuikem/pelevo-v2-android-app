import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/player/cast/pelevo_cast_models.dart';

void main() {
  test('copyWith can clear the connected device name', () {
    const snapshot = PelevoCastSnapshot(
      supported: true,
      ready: true,
      connected: true,
      playing: true,
      deviceName: 'Living Room',
      devices: [PelevoCastDevice(id: '1', name: 'Living Room')],
    );

    final next = snapshot.copyWith(
      connected: false,
      playing: false,
      clearDeviceName: true,
    );

    expect(next.supported, isTrue);
    expect(next.connected, isFalse);
    expect(next.playing, isFalse);
    expect(next.deviceName, isNull);
    expect(next.devices, hasLength(1));
  });

  test('copyWith preserves permission and discovery flags', () {
    const snapshot = PelevoCastSnapshot(
      supported: true,
      ready: true,
      connected: false,
      playing: false,
      discovering: true,
      permissionDenied: true,
      statusMessage: 'Need nearby devices',
    );

    final next = snapshot.copyWith(
      discovering: false,
      permissionDenied: false,
      clearStatusMessage: true,
    );

    expect(next.discovering, isFalse);
    expect(next.permissionDenied, isFalse);
    expect(next.statusMessage, isNull);
    expect(next.ready, isTrue);
  });
}
