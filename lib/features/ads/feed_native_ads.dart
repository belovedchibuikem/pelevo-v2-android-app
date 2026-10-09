import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  static const searchHeight = 76.0;

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

  static String? _platformUnit(String android, String ios) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (kReleaseMode) return android.isEmpty ? null : android;
      return _androidTestUnit;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (kReleaseMode) return ios.isEmpty ? null : ios;
      return _iosTestUnit;
    }
    return null;
  }
}

/// True only for a confirmed Free-tier listener on a platform that can load
/// this placement. Premium subscribers, preview fixtures, and unresolved
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
    final visible = feedNativeAdVisible(
      catalogPreview: preview,
      platformSupported: FeedNativeAds.supported,
      hasAdUnit: true,
      entitlementReady: account.hasValue,
      premiumActive: account.asData?.value.entitlement?.active == true,
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
  bool _released = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final ready = await ReelAds.initialize();
    if (!mounted) return;
    if (!ready) {
      setState(() => _failed = true);
      return;
    }

    final ad = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            _release(ad);
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          _release(ad);
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
    _ad = ad;
    try {
      await ad.load();
    } catch (_) {
      _release(ad);
      if (mounted) setState(() => _failed = true);
    }
  }

  void _release(Ad ad) {
    if (_released) return;
    _released = true;
    if (identical(_ad, ad)) _ad = null;
    unawaited(ad.dispose());
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final ad = _ad;
    final radius = BorderRadius.circular(widget.borderRadius);
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
            child:
                _loaded && ad != null
                    ? ClipRRect(borderRadius: radius, child: AdWidget(ad: ad))
                    : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
