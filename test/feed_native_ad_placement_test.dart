import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/ads/feed_native_ads.dart';

void main() {
  test('search native ad reserves a compact row before it loads', () {
    expect(FeedNativeAds.searchHeight, inInclusiveRange(72, 80));
    expect(FeedNativeAds.searchFactoryId, isNot(FeedNativeAds.homeFactoryId));
  });

  test('search native ad is the third row when the list is long enough', () {
    expect(searchNativeAdSlotIndex(0), -1);
    expect(searchNativeAdSlotIndex(1), 1);
    expect(searchNativeAdSlotIndex(2), 2);
    expect(searchNativeAdSlotIndex(6), 2);

    expect(insertAtSearchAdSlot(<String>[], 'ad'), isEmpty);
    expect(insertAtSearchAdSlot(['a'], 'ad'), ['a', 'ad']);
    expect(insertAtSearchAdSlot(['a', 'b', 'c', 'd'], 'ad'), [
      'a',
      'b',
      'ad',
      'c',
      'd',
    ]);
  });

  test('feed native ads stay hidden unless the listener is confirmed free', () {
    expect(
      feedNativeAdVisible(
        catalogPreview: false,
        platformSupported: true,
        hasAdUnit: true,
        entitlementReady: true,
        premiumActive: false,
      ),
      isTrue,
    );
    expect(
      feedNativeAdVisible(
        catalogPreview: false,
        platformSupported: true,
        hasAdUnit: true,
        entitlementReady: true,
        premiumActive: true,
      ),
      isFalse,
    );
    expect(
      feedNativeAdVisible(
        catalogPreview: false,
        platformSupported: true,
        hasAdUnit: true,
        entitlementReady: false,
        premiumActive: false,
      ),
      isFalse,
    );
    expect(
      feedNativeAdVisible(
        catalogPreview: true,
        platformSupported: true,
        hasAdUnit: true,
        entitlementReady: true,
        premiumActive: false,
      ),
      isFalse,
    );
    expect(
      feedNativeAdVisible(
        catalogPreview: false,
        platformSupported: true,
        hasAdUnit: false,
        entitlementReady: true,
        premiumActive: false,
      ),
      isFalse,
    );
  });

  test('search native ads are omitted on Android 10 and older', () {
    expect(
      searchNativeAdAllowed(
        platform: TargetPlatform.android,
        androidSdk: 29,
        androidSdkResolved: true,
      ),
      isFalse,
    );
    expect(
      searchNativeAdAllowed(
        platform: TargetPlatform.android,
        androidSdk: 21,
        androidSdkResolved: true,
      ),
      isFalse,
    );
    expect(
      searchNativeAdAllowed(
        platform: TargetPlatform.android,
        androidSdk: null,
        androidSdkResolved: false,
      ),
      isFalse,
    );
    expect(
      searchNativeAdAllowed(
        platform: TargetPlatform.android,
        androidSdk: 30,
        androidSdkResolved: true,
      ),
      isTrue,
    );
    expect(
      searchNativeAdAllowed(
        platform: TargetPlatform.iOS,
        androidSdk: null,
        androidSdkResolved: false,
      ),
      isTrue,
    );
  });
}
