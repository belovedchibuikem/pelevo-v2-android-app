import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Search on Android 11+ uses hybrid composition.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:pelevo/core/catalog_preview.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/premium/premium_data.dart';
import 'package:pelevo/features/reels/reel_ad_service.dart';

/// Home-feed and search native placements.
///
/// Debug builds use Google's sample native unit. Release builds read
/// `ADMOB_HOME_ANDROID_AD_UNIT_ID`, `ADMOB_HOME_IOS_AD_UNIT_ID`,
/// `ADMOB_SEARCH_ANDROID_AD_UNIT_ID`, and `ADMOB_SEARCH_IOS_AD_UNIT_ID`.
abstract final class FeedNativeAds {
  static const homeFactoryId = 'pelevoHomeNative';
  static const searchFactoryId = 'pelevoSearchNative';
  // Tall enough that the video MediaView stays at least 120dp after the
  // headline, body, padding, and call-to-action.
  static const homeHeight = 300.0;
  // Reserved before the ad loads. Kept inside the 72–80dp search row.
  static const searchHeight = 76.0;

  /// Android 11. Search must not call AdMob on Android 10 (API 29) or older.
  static const searchMinAndroidSdk = 30;

  /// Last SDK read. Search loading stays off until this is known.
  static int? androidSdkInt;

  static const _androidTestUnit = 'ca-app-pub-3940256099942544/2247696110';
  static const _iosTestUnit = 'ca-app-pub-3940256099942544/3986624511';

  static bool get supported =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);

  static String? homeAdUnitId() {
    const android = String.fromEnvironment('ADMOB_HOME_ANDROID_AD_UNIT_ID');
    const ios = String.fromEnvironment('ADMOB_HOME_IOS_AD_UNIT_ID');
    return _platformUnit(android, ios);
  }

  static String? searchAdUnitId() {
    const android = String.fromEnvironment('ADMOB_SEARCH_ANDROID_AD_UNIT_ID');
    const ios = String.fromEnvironment('ADMOB_SEARCH_IOS_AD_UNIT_ID');
    return _platformUnit(android, ios);
  }

  /// Android SDK, or null when this is not Android or the read fails.
  static Future<int?> readAndroidSdk() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } on Object {
      return null;
    }
  }

  /// False on Android 10 and older. Call this before any search ad request.
  static Future<bool> searchRequestAllowed() async {
    if (kIsWeb || !supported) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final sdk = androidSdkInt ?? await readAndroidSdk();
    androidSdkInt = sdk;
    return searchNativeAdAllowed(
      platform: TargetPlatform.android,
      androidSdk: sdk,
      androidSdkResolved: true,
    );
  }

  /// Play internal / closed testing: pass `--dart-define=ADMOB_USE_SAMPLE_UNITS=true`
  /// so release builds load Google sample units instead of silently skipping ads
  /// when production unit dart-defines were omitted.
  static bool get useSampleUnits =>
      !kReleaseMode ||
      const String.fromEnvironment('ADMOB_USE_SAMPLE_UNITS') == 'true' ||
      const String.fromEnvironment('ADMOB_USE_SAMPLE_UNITS') == '1';

  static String? _platformUnit(String android, String ios) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (useSampleUnits) return _androidTestUnit;
      return android.isEmpty ? null : android;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (useSampleUnits) return _iosTestUnit;
      return ios.isEmpty ? null : ios;
    }
    return null;
  }
}

/// Cached Android SDK. Search ads stay off until this resolves, and stay off
/// on Android 10 and older.
final androidSdkIntProvider = FutureProvider<int?>((ref) async {
  final sdk = await FeedNativeAds.readAndroidSdk();
  FeedNativeAds.androidSdkInt = sdk;
  return sdk;
});

/// Search ads are omitted on Android 10 (API 29) and older. Other platforms
/// that can show a native ad are unchanged. An unresolved Android SDK stays
/// hidden so the platform view is never created.
bool searchNativeAdAllowed({
  required TargetPlatform platform,
  required int? androidSdk,
  required bool androidSdkResolved,
}) {
  if (platform != TargetPlatform.android) return true;
  if (!androidSdkResolved || androidSdk == null) return false;
  return androidSdk >= FeedNativeAds.searchMinAndroidSdk;
}

/// True only for a confirmed free listener or creator on a platform that can
/// load this placement. Pelevo Plus, preview fixtures, and unresolved
/// entitlement never reserve space.
bool feedNativeAdVisible({
  required bool catalogPreview,
  required bool platformSupported,
  required bool hasAdUnit,
  required bool entitlementReady,
  required bool premiumActive,
}) {
  if (catalogPreview || !platformSupported || !hasAdUnit) return false;
  return entitlementReady && !premiumActive;
}

/// Third row of a vertical list (index 2). Shorter lists keep the ad at the
/// end. An empty list stays empty so a missing catalog does not show a lone ad.
int searchNativeAdSlotIndex(int itemCount) {
  if (itemCount <= 0) return -1;
  if (itemCount >= 2) return 2;
  return itemCount;
}

List<T> insertAtSearchAdSlot<T>(List<T> items, T ad) {
  final index = searchNativeAdSlotIndex(items.length);
  if (index < 0) return items;
  return [...items.take(index), ad, ...items.skip(index)];
}

/// Card between Continue Listening and Made For You.
class HomeFeedNativeAd extends StatelessWidget {
  const HomeFeedNativeAd({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FreeTierNativeAd(
      placement: _NativePlacement.home,
      height: FeedNativeAds.homeHeight,
      borderRadius: 12,
      placeholderColor: Color(0xFF121212),
      margin: EdgeInsets.only(bottom: PelevoSpacing.xl),
    );
  }
}

/// Compact row used as search result position 3.
class SearchFeedNativeAd extends StatelessWidget {
  const SearchFeedNativeAd({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FreeTierNativeAd(
      placement: _NativePlacement.search,
      height: FeedNativeAds.searchHeight,
      borderRadius: 0,
      placeholderColor: Colors.transparent,
    );
  }
}

enum _NativePlacement { home, search }

class _FreeTierNativeAd extends ConsumerWidget {
  const _FreeTierNativeAd({
    required this.placement,
    required this.height,
    required this.borderRadius,
    required this.placeholderColor,
    this.margin = EdgeInsets.zero,
  });

  final _NativePlacement placement;
  final double height;
  final double borderRadius;
  final Color placeholderColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(catalogPreviewProvider);
    final adUnitId = switch (placement) {
      _NativePlacement.home => FeedNativeAds.homeAdUnitId(),
      _NativePlacement.search => FeedNativeAds.searchAdUnitId(),
    };
    if (preview || !FeedNativeAds.supported || adUnitId == null) {
      return const SizedBox.shrink();
    }

    final account = ref.watch(premiumAccountProvider);
    final confirmed = ref.watch(premiumAccountSeedProvider);
    final androidSdk = ref.watch(androidSdkIntProvider);
    if (placement == _NativePlacement.search &&
        !searchNativeAdAllowed(
          platform: defaultTargetPlatform,
          androidSdk: androidSdk.asData?.value,
          androidSdkResolved: androidSdk.hasValue,
        )) {
      return const SizedBox.shrink();
    }
    final visible = feedNativeAdVisible(
      catalogPreview: preview,
      platformSupported: FeedNativeAds.supported,
      hasAdUnit: true,
      entitlementReady: account.hasValue,
      premiumActive: pelevoPlusIsActive(
        account: account.asData?.value,
        confirmedPurchase: confirmed,
      ),
    );
    if (!visible) return const SizedBox.shrink();

    return _PlatformNativeAd(
      adUnitId: adUnitId,
      factoryId: switch (placement) {
        _NativePlacement.home => FeedNativeAds.homeFactoryId,
        _NativePlacement.search => FeedNativeAds.searchFactoryId,
      },
      height: height,
      borderRadius: borderRadius,
      placeholderColor: placeholderColor,
      margin: margin,
    );
  }
}

class _PlatformNativeAd extends StatefulWidget {
  const _PlatformNativeAd({
    required this.adUnitId,
    required this.factoryId,
    required this.height,
    required this.borderRadius,
    required this.placeholderColor,
    required this.margin,
  });

  final String adUnitId;
  final String factoryId;
  final double height;
  final double borderRadius;
  final Color placeholderColor;
  final EdgeInsetsGeometry margin;

  @override
  State<_PlatformNativeAd> createState() => _PlatformNativeAdState();
}

class _PlatformNativeAdState extends State<_PlatformNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _failed = false;
  bool _closed = false;
  bool _slotReady = false;

  bool get _hybridSearchAd =>
      widget.factoryId == FeedNativeAds.searchFactoryId &&
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closed) return;
      setState(() => _slotReady = true);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.factoryId == FeedNativeAds.searchFactoryId) {
      final allowed = await FeedNativeAds.searchRequestAllowed();
      if (!allowed || !mounted || _closed) {
        _ad = null;
        _failed = true;
        if (mounted && !_closed) setState(() {});
        return;
      }
    }
    final ready = await ReelAds.initialize();
    if (!mounted || _closed) return;
    if (!ready) {
      _failed = true;
      if (mounted) setState(() {});
      return;
    }

    final ad = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (_closed || !mounted) {
            _close();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          _failed = true;
          _close();
          if (mounted) setState(() {});
        },
      ),
    );
    if (_closed || !mounted) {
      unawaited(_disposeQuietly(ad));
      return;
    }
    _ad = ad;
    try {
      await ad.load();
    } catch (_) {
      _failed = true;
      _close();
      if (mounted) setState(() {});
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _loaded = false;
    final ad = _ad;
    _ad = null;
    if (ad != null) unawaited(_disposeQuietly(ad));
  }

  Future<void> _disposeQuietly(Ad ad) async {
    try {
      await ad.dispose();
    } catch (error) {
      debugPrint('AdMob nativeAd.dispose failed: $error');
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _closed) return const SizedBox.shrink();
    final ad = _ad;
    final radius = BorderRadius.circular(widget.borderRadius);
    final showAd = _slotReady && _loaded && ad != null;
    return Padding(
      padding: widget.margin,
      child: Semantics(
        label: 'Sponsored advertisement',
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.placeholderColor,
              borderRadius: radius,
            ),
            child: showAd ? _hostedAd(ad, radius) : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _hostedAd(NativeAd ad, BorderRadius radius) {
    final view = _hybridSearchAd
        ? _HybridAndroidNativeAd(key: ObjectKey(ad), ad: ad)
        : AdWidget(key: ObjectKey(ad), ad: ad);
    if (widget.borderRadius <= 0) return view;
    return ClipRRect(borderRadius: radius, child: view);
  }
}

class _HybridAndroidNativeAd extends StatefulWidget {
  const _HybridAndroidNativeAd({super.key, required this.ad});

  final NativeAd ad;

  @override
  State<_HybridAndroidNativeAd> createState() => _HybridAndroidNativeAdState();
}

class _HybridAndroidNativeAdState extends State<_HybridAndroidNativeAd> {
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    final adId = instanceManager.adIdFor(widget.ad);
    if (adId == null || instanceManager.isWidgetAdIdMounted(adId)) {
      _unavailable = true;
      return;
    }
    instanceManager.mountWidgetAdId(adId);
  }

  @override
  void dispose() {
    final adId = instanceManager.adIdFor(widget.ad);
    if (adId != null) instanceManager.unmountWidgetAdId(adId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) return const SizedBox.expand();
    final adId = instanceManager.adIdFor(widget.ad);
    if (adId == null) return const SizedBox.expand();
    final viewType = '${instanceManager.channel.name}/ad_widget';
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: adId,
            creationParamsCodec: const StandardMessageCodec(),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
