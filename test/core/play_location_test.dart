import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/player/play_location.dart';

void main() {
  setUp(PlayLocation.instance.reset);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PlayLocation.instance.reset();
  });

  test('play location rounds a coarse device fix', () {
    expect(
      const PlayFix(
        latitude: 6.52441,
        longitude: 3.37921,
        accuracyMeters: 120.4,
      ).toJson(),
      {
        'latitude': 6.524,
        'longitude': 3.379,
        'accuracy_m': 120,
        'source': 'device',
      },
    );
  });

  test('play location stays empty off mobile', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(await PlayLocation.instance.fields(), isEmpty);
  });

  test('a missing location plugin does not block a play report', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await PlayLocation.instance.fields(), isEmpty);
  });
}
