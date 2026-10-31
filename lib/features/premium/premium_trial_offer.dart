import 'dart:math';

import 'package:pelevo/core/network/api_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Introductory Pelevo Plus offer: one month free, then the selected plan.
abstract final class PremiumTrialOffer {
  static const slug = 'plus-1-month-trial';

  /// Older deep links / local promo keys still resolve to this campaign.
  static const legacySlug = 'plus-3-month-trial';

  static const trialMonths = 1;
  static const legacyTrialMonths = 3;
  static const cooldownDays = 8;
  static const sessionInterval = 8;

  static const promoHeadline = 'Try 1 Month Free';
  static const promoBadge = 'Try 1 Month Free';
  static const promoSubtitle =
      'Enjoy ad-free and offline podcast listening on Pelevo Plus.';
  static const claimCta = 'Claim Offer';
  static const renewCta = 'Resubscribe to Pelevo Plus';
  static const renewHeadline = 'Renew Subscription';

  /// Google Play Console offer IDs on `pelevo_plus_individual` base plans.
  static const playMonthlyOfferId = 'one-month-free-trial-monthly';
  static const playYearlyOfferId = 'one-month-free-trial-yearly';

  static bool matchesSlug(String? value) =>
      value == slug || value == legacySlug;

  static String playOfferIdFor({required bool yearly}) =>
      yearly ? playYearlyOfferId : playMonthlyOfferId;

  static String? playOfferIdForProduct(String productId, {bool? yearly}) {
    if (productId == 'pelevo_plus_monthly') return playMonthlyOfferId;
    if (productId == 'pelevo_plus_yearly') return playYearlyOfferId;
    if (productId == 'pelevo_plus_individual' && yearly != null) {
      return playOfferIdFor(yearly: yearly);
    }
    return null;
  }
}

class PremiumTrialEvaluation {
  const PremiumTrialEvaluation({
    required this.premium,
    required this.eligible,
    required this.sessionCount,
    required this.lastShownAt,
    required this.planId,
  });

  factory PremiumTrialEvaluation.parse(Map<String, dynamic> data) {
    const invalid = ApiFailure(
      code: 'INVALID_RESPONSE',
      message: 'The Premium offer could not be read. Please retry.',
    );
    final premium = data['premium'];
    final eligible = data['eligible'];
    final count = data['session_count'];
    final shown = data['last_shown_at'];
    final planId = data['plan_id'];
    if (premium is! bool || eligible is! bool) throw invalid;
    if (count is! int || count < 0) throw invalid;
    if (planId != null && (planId is! String || planId.isEmpty)) throw invalid;
    DateTime? lastShownAt;
    if (shown != null) {
      if (shown is! String) throw invalid;
      lastShownAt = DateTime.tryParse(shown)?.toUtc();
      if (lastShownAt == null) throw invalid;
    }
    return PremiumTrialEvaluation(
      premium: premium,
      eligible: eligible,
      sessionCount: count,
      lastShownAt: lastShownAt,
      planId: planId as String?,
    );
  }

  final bool premium;
  final bool eligible;
  final int sessionCount;
  final DateTime? lastShownAt;
  final String? planId;
}

/// Show on every 8th session, and never again until 8 days have passed.
bool premiumTrialShouldShow({
  required bool premium,
  required int sessionCount,
  required DateTime? lastShownAt,
  required DateTime now,
}) {
  if (premium) return false;
  if (sessionCount < PremiumTrialOffer.sessionInterval ||
      sessionCount % PremiumTrialOffer.sessionInterval != 0) {
    return false;
  }
  if (lastShownAt == null) return true;
  final eligibleAt = lastShownAt.toUtc().add(
    const Duration(days: PremiumTrialOffer.cooldownDays),
  );
  return !now.toUtc().isBefore(eligibleAt);
}

class PremiumTrialLocalState {
  const PremiumTrialLocalState({
    required this.sessionCount,
    required this.lastShownAt,
  });

  final int sessionCount;
  final DateTime? lastShownAt;
}

class PremiumTrialLocalStore {
  const PremiumTrialLocalStore(this._preferences);

  final SharedPreferences _preferences;

  String _countKey(String userId) =>
      'pelevo.promo.${PremiumTrialOffer.slug}.$userId.sessions';

  String _shownKey(String userId) =>
      'pelevo.promo.${PremiumTrialOffer.slug}.$userId.shown';

  String _sessionKey(String userId) =>
      'pelevo.promo.${PremiumTrialOffer.slug}.$userId.session';

  PremiumTrialLocalState read(String userId) {
    final shown = _preferences.getString(_shownKey(userId));
    return PremiumTrialLocalState(
      sessionCount: _preferences.getInt(_countKey(userId)) ?? 0,
      lastShownAt: shown == null ? null : DateTime.tryParse(shown)?.toUtc(),
    );
  }

  Future<PremiumTrialLocalState> recordSession(
    String userId,
    String sessionId,
  ) async {
    if (_preferences.getString(_sessionKey(userId)) == sessionId) {
      return read(userId);
    }
    final count = (_preferences.getInt(_countKey(userId)) ?? 0) + 1;
    await _preferences.setInt(_countKey(userId), count);
    await _preferences.setString(_sessionKey(userId), sessionId);
    return read(userId);
  }

  Future<void> adopt(String userId, PremiumTrialEvaluation remote) async {
    await _preferences.setInt(_countKey(userId), remote.sessionCount);
    final shown = remote.lastShownAt;
    if (shown == null) {
      await _preferences.remove(_shownKey(userId));
    } else {
      await _preferences.setString(_shownKey(userId), shown.toIso8601String());
    }
  }

  Future<void> markShown(String userId, DateTime at) =>
      _preferences.setString(_shownKey(userId), at.toUtc().toIso8601String());
}

abstract interface class PremiumTrialRemote {
  Future<PremiumTrialEvaluation> recordSession(String sessionId);
  Future<void> markShown();

  /// Null when Premium status could not be confirmed.
  Future<bool?> readPremiumActive();
}

class PremiumTrialCoordinator {
  PremiumTrialCoordinator({
    required PremiumTrialLocalStore store,
    required PremiumTrialRemote remote,
    DateTime Function()? clock,
    String Function()? sessionId,
  }) : _store = store,
       _remote = remote,
       _clock = clock ?? DateTime.now,
       _sessionId = sessionId ?? _randomId;

  final PremiumTrialLocalStore _store;
  final PremiumTrialRemote _remote;
  final DateTime Function() _clock;
  final String Function() _sessionId;
  final Map<String, String> _sessions = {};

  String _idFor(String userId) => _sessions.putIfAbsent(userId, _sessionId);

  Future<bool> shouldPresent(String userId) async {
    final local = await _store.recordSession(userId, _idFor(userId));
    try {
      final remote = await _remote.recordSession(_idFor(userId));
      await _store.adopt(userId, remote);
      return remote.eligible && !remote.premium;
    } on Object {
      final premium = await _remote.readPremiumActive();
      if (premium != false) return false;
      return premiumTrialShouldShow(
        premium: false,
        sessionCount: local.sessionCount,
        lastShownAt: local.lastShownAt,
        now: _clock(),
      );
    }
  }

  Future<void> markShown(String userId) async {
    await _store.markShown(userId, _clock());
    try {
      await _remote.markShown();
    } on Object {
      // The local timestamp still enforces the cap if the account sync fails.
    }
  }
}

String _randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
