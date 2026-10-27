import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/authentication/signup_country.dart';

const _invalidProfile = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Your account information could not be read. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidProfile;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidProfile;
  return value as String?;
}

int _count(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! int || value < 0) throw _invalidProfile;
  return value;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.creatorAccess,
    required this.following,
    required this.followers,
    required this.podcasts,
    required this.playlists,
    required this.unreadNotifications,
    this.handle,
    this.phone,
    this.countryCode,
    this.bio,
    this.avatarUrl,
    this.locale,
    this.timezone,
  });

  factory UserProfile.fromApi(Map<String, dynamic> data) {
    final details = data['profile'];
    final stats = data['stats'];
    final capabilities = data['capabilities'];
    if ((details != null && details is! Map<String, dynamic>) ||
        stats is! Map<String, dynamic> ||
        capabilities is! Map<String, dynamic> ||
        capabilities['creator_access'] is! bool) {
      throw _invalidProfile;
    }
    final profile =
        details as Map<String, dynamic>? ?? const <String, dynamic>{};
    return UserProfile(
      id: _text(data, 'id'),
      name: _text(data, 'name'),
      email: _text(data, 'email'),
      handle: _optionalText(data, 'handle'),
      phone: _optionalText(data, 'phone'),
      countryCode: _optionalText(data, 'country_code'),
      bio: _optionalText(profile, 'bio'),
      avatarUrl: _optionalText(profile, 'avatar_url'),
      locale: _optionalText(profile, 'locale'),
      timezone: _optionalText(profile, 'timezone'),
      creatorAccess: capabilities['creator_access'] as bool,
      following: _count(stats, 'following'),
      followers: _count(stats, 'followers'),
      podcasts: _count(stats, 'podcasts'),
      playlists: _count(stats, 'playlists'),
      unreadNotifications: _count(data, 'unread_notifications'),
    );
  }

  final String id, name, email;
  final String? handle, phone, countryCode, bio, avatarUrl, locale, timezone;
  final bool creatorAccess;
  final int following, followers, podcasts, playlists, unreadNotifications;

  Map<String, dynamic> toApi() => {
    'id': id,
    'name': name,
    'email': email,
    'handle': handle,
    'phone': phone,
    'country_code': countryCode,
    'profile': {
      'bio': bio,
      'avatar_url': avatarUrl,
      'locale': locale,
      'timezone': timezone,
    },
    'capabilities': {'creator_access': creatorAccess},
    'stats': {
      'following': following,
      'followers': followers,
      'podcasts': podcasts,
      'playlists': playlists,
    },
    'unread_notifications': unreadNotifications,
  };
}

class EarnBalance {
  const EarnBalance(this.coins);
  final BigInt coins;

  factory EarnBalance.fromApi(Map<String, dynamic> data) {
    final raw = data['balance'];
    if (data['unit'] != 'ECN' ||
        (raw is! int && raw is! String) ||
        !RegExp(r'^\d+$').hasMatch('$raw')) {
      throw _invalidProfile;
    }
    return EarnBalance(BigInt.parse('$raw'));
  }
}

class ProfileRepository {
  const ProfileRepository(this.dio);
  final Dio dio;

  Future<void> confirmAgeMajority() async {
    requireApiData(
      (await dio.post<Map<String, dynamic>>(
        '/me/age-majority',
        data: const {'confirmed': true},
      )).data,
    );
  }

  Future<UserProfile> fetch({CancelToken? cancelToken}) async =>
      UserProfile.fromApi(
        requireApiData(
          (await dio.get<Map<String, dynamic>>(
            '/me',
            cancelToken: cancelToken,
          )).data,
        ),
      );

  Future<UserProfile> update(
    UserProfile previous, {
    required String name,
    required String handle,
    required String bio,
  }) async {
    final data = requireApiData(
      (await dio.patch<Map<String, dynamic>>(
        '/me',
        data: {
          'name': name.trim(),
          'handle': handle.trim().isEmpty ? null : handle.trim(),
          'bio': bio.trim().isEmpty ? null : bio.trim(),
        },
      )).data,
    );
    final user = data['user'];
    if (user is! Map<String, dynamic> ||
        user['id'] != previous.id ||
        !data.containsKey('profile')) {
      throw _invalidProfile;
    }
    return UserProfile.fromApi({
      ...previous.toApi(),
      ...user,
      'profile': data['profile'],
    });
  }

  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ApiFailure(
        code: 'VALIDATION',
        message: 'Choose a photo smaller than 5 MB.',
      );
    }
    final data = requireApiData(
      (await dio.post<Map<String, dynamic>>(
        '/me/avatar',
        data: FormData.fromMap({
          'avatar': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      )).data,
    );
    return _text(data, 'avatar_url');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    requireApiData(
      (await dio.patch<Map<String, dynamic>>(
        '/me/password',
        data: {
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': confirmation,
        },
      )).data,
    );
  }

  Future<UserProfile> saveCountry(UserProfile previous, String countryCode) async {
    requireApiData(
      (await dio.patch<Map<String, dynamic>>(
        '/me',
        data: {'country_code': countryCode},
      )).data,
    );
    return UserProfile.fromApi({
      ...previous.toApi(),
      'country_code': countryCode,
    });
  }

  Future<EarnBalance> balance({CancelToken? cancelToken}) async =>
      EarnBalance.fromApi(
        requireApiData(
          (await dio.get<Map<String, dynamic>>(
            '/earn/wallet',
            cancelToken: cancelToken,
          )).data,
        ),
      );
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

class ProfileController extends AsyncNotifier<UserProfile> {
  bool _saving = false;

  @override
  Future<UserProfile> build() async {
    ref.watch(authSessionProvider.select((session) => session.userId));
    final token = CancelToken();
    ref.onDispose(() => token.cancel());
    final loaded = await ref.read(profileRepositoryProvider).fetch(cancelToken: token);
    final country = loaded.countryCode?.trim();
    if (country != null && country.isNotEmpty) return loaded;
    final detected = await detectSignupCountry();
    if (detected == null || !ref.mounted) return loaded;
    try {
      return await ref.read(profileRepositoryProvider).saveCountry(loaded, detected);
    } on ApiFailure {
      return loaded;
    }
  }

  Future<void> saveProfile({
    required String name,
    required String handle,
    required String bio,
  }) async {
    final previous = state.asData?.value;
    if (_saving || previous == null) {
      throw const ApiFailure(
        code: 'BUSY',
        message: 'Please wait for your profile to load.',
      );
    }
    _saving = true;
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .update(previous, name: name, handle: handle, bio: bio);
      if (!ref.mounted || state.asData?.value.id != previous.id) {
        throw const ApiFailure(
          code: 'SESSION_CHANGED',
          message: 'Your account changed. Please sign in again.',
        );
      }
      state = AsyncData(updated);
      final session = ref.read(authSessionProvider);
      if (session.userId == updated.id) {
        await ref
            .read(authSessionProvider.notifier)
            .save(session.withUser({...?session.user, ...updated.toApi()}));
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> uploadAvatar(List<int> bytes, String filename) async {
    final previous = state.asData?.value;
    if (_saving || previous == null) {
      throw const ApiFailure(
        code: 'BUSY',
        message: 'Please wait for your profile to load.',
      );
    }
    _saving = true;
    try {
      final url = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(bytes, filename);
      if (!ref.mounted || state.asData?.value.id != previous.id) {
        throw const ApiFailure(
          code: 'SESSION_CHANGED',
          message: 'Your account changed. Please sign in again.',
        );
      }
      final data = previous.toApi();
      data['profile'] = {
        ...data['profile'] as Map<String, dynamic>,
        'avatar_url': url,
      };
      state = AsyncData(UserProfile.fromApi(data));
    } finally {
      _saving = false;
    }
  }
}

final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, UserProfile>(
      ProfileController.new,
      retry: (retryCount, error) => null,
    );
final earnBalanceProvider = FutureProvider.autoDispose<EarnBalance>((ref) {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.read(profileRepositoryProvider).balance(cancelToken: token);
}, retry: (retryCount, error) => null);

ApiFailure profileFailure(Object error) => switch (error) {
  ApiFailure failure => failure,
  DioException failure => apiFailureFromDio(failure),
  _ => const ApiFailure(
    code: 'UNEXPECTED',
    message: 'Something went wrong. Please try again.',
  ),
};
