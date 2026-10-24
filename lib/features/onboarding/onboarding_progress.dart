import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/onboarding/onboarding_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingProgressStore {
  Future<bool> hasSeenIntroduction();
  Future<void> markIntroductionSeen();
  Future<OnboardingDraft?> readDraft();
  Future<void> saveDraft(OnboardingDraft draft);
  Future<void> clearDraft();
  Future<bool> hasCompletedPermissions();
  Future<void> markPermissionsComplete();
}

class SharedPreferencesOnboardingProgressStore
    implements OnboardingProgressStore {
  const SharedPreferencesOnboardingProgressStore(this._preferences);

  static const _seenKey = 'pelevo.onboarding.introduction_seen';
  static const _draftKey = 'pelevo.onboarding.draft.v1';
  static const _permissionsKey = 'pelevo.onboarding.permissions_complete';
  final SharedPreferences _preferences;

  @override
  Future<bool> hasSeenIntroduction() async =>
      _preferences.getBool(_seenKey) ?? false;

  @override
  Future<void> markIntroductionSeen() => _preferences.setBool(_seenKey, true);

  @override
  Future<OnboardingDraft?> readDraft() async {
    final raw = _preferences.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await _preferences.remove(_draftKey);
      return null;
    }
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) =>
      _preferences.setString(_draftKey, jsonEncode(draft.toJson()));

  @override
  Future<void> clearDraft() => _preferences.remove(_draftKey);

  @override
  Future<bool> hasCompletedPermissions() async =>
      _preferences.getBool(_permissionsKey) ?? false;

  @override
  Future<void> markPermissionsComplete() =>
      _preferences.setBool(_permissionsKey, true);
}

class MemoryOnboardingProgressStore implements OnboardingProgressStore {
  bool _seen = false;
  bool _permissionsComplete = false;
  OnboardingDraft? _draft;

  @override
  Future<bool> hasSeenIntroduction() async => _seen;

  @override
  Future<void> markIntroductionSeen() async {
    _seen = true;
  }

  @override
  Future<OnboardingDraft?> readDraft() async => _draft;

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _draft = draft;
  }

  @override
  Future<void> clearDraft() async {
    _draft = null;
  }

  @override
  Future<bool> hasCompletedPermissions() async => _permissionsComplete;

  @override
  Future<void> markPermissionsComplete() async {
    _permissionsComplete = true;
  }
}

final onboardingProgressStoreProvider = Provider<OnboardingProgressStore>(
  (ref) => MemoryOnboardingProgressStore(),
);

String startupDestination({
  required bool hadStoredSession,
  required bool authenticated,
  required bool introductionSeen,
}) {
  if (authenticated) return '/screen/home-feed';
  if (hadStoredSession || introductionSeen) return '/screen/auth-sign-in';
  return '/screen/onboarding-personalized';
}

/// True only when the account payload explicitly says onboarding is unfinished.
///
/// Missing keys stay false so older cached sessions and test fixtures are not
/// sent back through setup.
bool sessionNeedsOnboarding(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (user['onboarded'] == true) return false;
  if (user['onboarded'] == false) return true;
  if (user.containsKey('onboarded_at')) return user['onboarded_at'] == null;
  return false;
}

/// Where a signed-in listener goes once a pending draft has been applied.
String postAuthDestination({
  required bool onboardingApplied,
  required bool needsOnboarding,
  required bool permissionsComplete,
  String? preferredPath,
}) {
  if (!onboardingApplied && needsOnboarding) {
    return '/screen/onboarding-interests';
  }
  if (onboardingApplied && !permissionsComplete) {
    return '/screen/permissions-intro';
  }
  if (preferredPath != null && preferredPath.isNotEmpty) return preferredPath;
  return '/screen/home-feed';
}

Future<bool> applyPendingOnboardingDraft(WidgetRef ref) =>
    applyPendingOnboardingDraftFor(
      store: ref.read(onboardingProgressStoreProvider),
      repository: ref.read(onboardingRepositoryProvider),
      userId: ref.read(authSessionProvider).userId,
    );

Future<String> resolveSetupDestination(
  WidgetRef ref, {
  String? preferredPath,
}) async {
  final applied = await applyPendingOnboardingDraft(ref);
  final permissionsComplete =
      await ref.read(onboardingProgressStoreProvider).hasCompletedPermissions();
  return postAuthDestination(
    onboardingApplied: applied,
    needsOnboarding: sessionNeedsOnboarding(ref.read(authSessionProvider).user),
    permissionsComplete: permissionsComplete,
    preferredPath: preferredPath,
  );
}

Future<bool> applyPendingOnboardingDraftFor({
  required OnboardingProgressStore store,
  required OnboardingRepository repository,
  required String? userId,
}) async {
  if (userId == null) return false;
  final draft = await store.readDraft();
  if (draft == null) return false;
  try {
    final result = await repository.submit(draft);
    if (result.userId != userId) return false;
    await store.clearDraft();
    return true;
  } on Object {
    return false;
  }
}
