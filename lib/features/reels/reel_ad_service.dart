import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pelevo/features/ads/feed_native_ads.dart';
import 'package:pelevo/features/reels/reel_data.dart';

abstract final class ReelAds {
  static const factoryId = 'pelevoReelsNative';
  static Future<bool>? _initializing;

  static Future<bool> initialize() {
    return _initializing ??= _initialize();
  }

  static Future<bool> _initialize() async {
    if (kIsWeb ||
        !const {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return false;
    }
    // Build without AdMob: no production unit ids and release mode → skip SDK init
    // (unless ADMOB_USE_SAMPLE_UNITS forces Google sample units for internal testing).
    if (kReleaseMode &&
        !FeedNativeAds.useSampleUnits &&
        adUnitId() == null &&
        const String.fromEnvironment('ADMOB_HOME_ANDROID_AD_UNIT_ID').isEmpty &&
        const String.fromEnvironment('ADMOB_SEARCH_ANDROID_AD_UNIT_ID').isEmpty &&
        const String.fromEnvironment('ADMOB_HOME_IOS_AD_UNIT_ID').isEmpty &&
        const String.fromEnvironment('ADMOB_SEARCH_IOS_AD_UNIT_ID').isEmpty) {
      return false;
    }

    try {
      final consentUpdated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        consentUpdated.complete,
        (_) => consentUpdated.complete(),
      );
      try {
        await consentUpdated.future.timeout(const Duration(seconds: 8));
      } on Object {
        return false;
      }

      final formDismissed = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired(
        (_) => formDismissed.complete(),
      );
      try {
        await formDismissed.future.timeout(const Duration(seconds: 20));
      } on Object {
        // Continue; canRequestAds below decides whether ads may load.
      }

      if (!await ConsentInformation.instance.canRequestAds()) return false;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await AppTrackingTransparency.requestTrackingAuthorization().timeout(
            const Duration(seconds: 8),
          );
        }
      }
      await MobileAds.instance.initialize().timeout(const Duration(seconds: 10));
      // Pelevo is 13+ generally; Earn/gifts/cashout are 18+. Not child-directed.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.pg,
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
        ),
      );
      return true;
    } on Object {
      // Ads must never take down cold start for Play review devices.
      return false;
    }
  }

  static String? adUnitId([String? serverKey]) {
    const androidProduction = String.fromEnvironment(
      'ADMOB_REELS_ANDROID_AD_UNIT_ID',
    );
    const iosProduction = String.fromEnvironment('ADMOB_REELS_IOS_AD_UNIT_ID');
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (serverKey != null && serverKey != 'reels-native-android') return null;
      if (FeedNativeAds.useSampleUnits) {
        return 'ca-app-pub-3940256099942544/2247696110';
      }
      return androidProduction.isEmpty ? null : androidProduction;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (serverKey != null && serverKey != 'reels-native-ios') return null;
      if (FeedNativeAds.useSampleUnits) {
        return 'ca-app-pub-3940256099942544/3986624511';
      }
      return iosProduction.isEmpty ? null : iosProduction;
    }
    return null;
  }

  static Future<void> showPrivacyOptions() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => completer.complete());
    await completer.future;
  }

  static Future<bool> privacyOptionsRequired() async {
    if (kIsWeb) return false;
    await initialize();
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }
}

abstract interface class ReelAdPageFactory {
  Widget build({
    required Key key,
    required ReelAdDue due,
    required String feedSessionId,
    required bool isActive,
    required VoidCallback onUnavailable,
  });
}

final class GoogleReelAdPageFactory implements ReelAdPageFactory {
  const GoogleReelAdPageFactory();

  @override
  Widget build({
    required Key key,
    required ReelAdDue due,
    required String feedSessionId,
    required bool isActive,
    required VoidCallback onUnavailable,
  }) {
    return ReelNativeAdPage(
      key: key,
      due: due,
      feedSessionId: feedSessionId,
      isActive: isActive,
      onUnavailable: onUnavailable,
    );
  }
}

final reelAdPageFactoryProvider = Provider<ReelAdPageFactory>(
  (ref) => const GoogleReelAdPageFactory(),
);

class ReelNativeAdPage extends ConsumerStatefulWidget {
  const ReelNativeAdPage({
    super.key,
    required this.due,
    required this.feedSessionId,
    required this.isActive,
    this.onUnavailable,
  });

  final ReelAdDue due;
  final String feedSessionId;
  final bool isActive;
  final VoidCallback? onUnavailable;

  @override
  ConsumerState<ReelNativeAdPage> createState() => _ReelNativeAdPageState();
}

class _ReelNativeAdPageState extends ConsumerState<ReelNativeAdPage> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _failed = false;
  bool _impressionConfirmed = false;
  bool _bounceSent = false;
  late final String _clientEventId;
  late bool _wasActive;

  @override
  void initState() {
    super.initState();
    _clientEventId = newReelViewSessionId();
    _wasActive = widget.isActive;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ReelNativeAdPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) _wasActive = true;
    if (oldWidget.isActive &&
        !widget.isActive &&
        !_impressionConfirmed &&
        !_failed) {
      unawaited(_bounce('skipped'));
    }
  }

  Future<void> _load() async {
    if (DateTime.now().isAfter(widget.due.expiresAt)) {
      _failed = true;
      await _bounce('skipped');
      if (mounted) setState(() {});
      widget.onUnavailable?.call();
      return;
    }
    final ready = await ReelAds.initialize();
    final adUnitId = ReelAds.adUnitId(widget.due.adUnitKey);
    if (!ready || adUnitId == null) {
      _failed = true;
      await _bounce('load_failed');
      if (mounted) setState(() {});
      widget.onUnavailable?.call();
      return;
    }

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: ReelAds.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          unawaited(ad.dispose());
          unawaited(_bounce('load_failed'));
          if (mounted) {
            setState(() => _failed = true);
            widget.onUnavailable?.call();
          }
        },
        onAdImpression: (_) {
          if (_impressionConfirmed) return;
          _impressionConfirmed = true;
          unawaited(
            ref
                .read(reelRepositoryProvider)
                .confirmAdImpression(
                  widget.due,
                  feedSessionId: widget.feedSessionId,
                  clientEventId: _clientEventId,
                ),
          );
        },
        onPaidEvent: (_, valueMicros, precision, currencyCode) {
          unawaited(
            ref
                .read(reelRepositoryProvider)
                .recordAdPaidEstimate(
                  widget.due,
                  valueMicros: valueMicros.round(),
                  currencyCode: currencyCode,
                  precision: precision.name,
                ),
          );
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  Future<void> _bounce(String reason) {
    if (_bounceSent || _impressionConfirmed) return Future<void>.value();
    _bounceSent = true;
    return ref
        .read(reelRepositoryProvider)
        .bounceAdImpression(
          widget.due,
          feedSessionId: widget.feedSessionId,
          reason: reason,
        );
  }

  @override
  void dispose() {
    if (_wasActive && !_impressionConfirmed && !_failed) {
      unawaited(_bounce('session_closed'));
    }
    unawaited(_ad?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Ad unavailable',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (!_loaded || ad == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Semantics(
          label: 'Sponsored advertisement',
          child: SizedBox.expand(child: AdWidget(ad: ad)),
        ),
      ),
    );
  }
}
