import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';

const onboardingInterestCatalog = [
  'News',
  'True Crime',
  'Comedy',
  'Business',
  'Health',
  'History',
  'Technology',
  'Sports',
  'Music',
  'Culture',
  'Education',
  'Stories',
  'Lifestyle',
  'Politics',
  'Science',
];

const onboardingLanguageCatalog = {
  'en': 'English',
  'fr': 'French',
  'yo': 'Yorùbá',
  'sw': 'Swahili',
  'ha': 'Hausa',
};

const _invalidOnboarding = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Your listening preferences could not be confirmed. Please try again.',
);

class OnboardingDraft {
  const OnboardingDraft({
    required this.interests,
    required this.locale,
  });

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) {
    final interests = json['interests'];
    final locale = json['locale'];
    if (interests is! List ||
        interests.isEmpty ||
        locale is! String ||
        !onboardingLanguageCatalog.containsKey(locale)) {
      throw _invalidOnboarding;
    }
    final selected = <String>[];
    for (final interest in interests) {
      if (interest is! String) throw _invalidOnboarding;
      final canonical = canonicalizeOnboardingInterest(interest);
      if (canonical == null) throw _invalidOnboarding;
      if (!selected.contains(canonical)) selected.add(canonical);
    }
    if (selected.isEmpty) throw _invalidOnboarding;
    return OnboardingDraft(interests: List.unmodifiable(selected), locale: locale);
  }

  final List<String> interests;
  final String locale;

  String get language => onboardingLanguageCatalog[locale] ?? 'English';

  Map<String, dynamic> toJson() => {'interests': interests, 'locale': locale};

  OnboardingDraft copyWith({List<String>? interests, String? locale}) =>
      OnboardingDraft(
        interests: List.unmodifiable(interests ?? this.interests),
        locale: locale ?? this.locale,
      );
}

class OnboardingResult {
  const OnboardingResult({
    required this.userId,
    required this.interests,
    this.locale,
  });

  factory OnboardingResult.fromApi(Map<String, dynamic> data) {
    if (data['user_id'] is! String ||
        (data['user_id'] as String).isEmpty ||
        data['onboarded'] != true) {
      throw _invalidOnboarding;
    }
    final interests = data['interests'];
    if (interests is! List || interests.isEmpty) throw _invalidOnboarding;
    final selected = <String>[];
    for (final interest in interests) {
      if (interest is! String) throw _invalidOnboarding;
      final canonical = canonicalizeOnboardingInterest(interest);
      if (canonical == null) throw _invalidOnboarding;
      if (!selected.contains(canonical)) selected.add(canonical);
    }
    if (selected.isEmpty) throw _invalidOnboarding;
    final locale = data['locale'];
    if (locale != null &&
        (locale is! String || !onboardingLanguageCatalog.containsKey(locale))) {
      throw _invalidOnboarding;
    }
    return OnboardingResult(
      userId: data['user_id'] as String,
      interests: List.unmodifiable(selected),
      locale: locale as String?,
    );
  }

  final String userId;
  final List<String> interests;
  final String? locale;
}

String? canonicalizeOnboardingInterest(String value) {
  final needle = value.trim().toLowerCase();
  for (final interest in onboardingInterestCatalog) {
    if (interest.toLowerCase() == needle) return interest;
  }
  return null;
}

String? localeForOnboardingLanguage(String language) {
  for (final entry in onboardingLanguageCatalog.entries) {
    if (entry.value == language) return entry.key;
  }
  return null;
}

class OnboardingRepository {
  const OnboardingRepository(this._dio);

  final Dio _dio;

  Future<OnboardingResult> submit(OnboardingDraft draft) async {
    if (draft.interests.isEmpty ||
        !onboardingLanguageCatalog.containsKey(draft.locale)) {
      throw const ApiFailure(
        code: 'VALIDATION',
        message: 'Select at least one interest and a language.',
      );
    }
    final response = await _dio.put<Map<String, dynamic>>(
      '/me/onboarding',
      data: {'interests': draft.interests, 'locale': draft.locale},
    );
    return OnboardingResult.fromApi(requireApiData(response.data));
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(dioProvider)),
);
