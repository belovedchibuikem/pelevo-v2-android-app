import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidBrowse = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Browse content could not be verified. Please retry.',
);

String _id(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is int) return '$value';
  if (value is num && value == value.roundToDouble()) return '${value.toInt()}';
  throw _invalidBrowse;
}

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidBrowse;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidBrowse;
  return value as String?;
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidBrowse;
  }
  return value.whereType<Map<String, dynamic>>().toList(growable: false);
}

List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidBrowse;
  }
  return _list(body['data']);
}

class BrowseCategory {
  const BrowseCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory BrowseCategory.fromApi(Map<String, dynamic> data) => BrowseCategory(
    id: _id(data['id']),
    name: _text(data, 'name'),
    slug: _text(data, 'slug'),
  );

  final String id;
  final String name;
  final String slug;

  bool get isMusic =>
      slug.toLowerCase() == 'music' || name.toLowerCase() == 'music';
}

class BrowseShow {
  const BrowseShow({
    required this.id,
    required this.title,
    this.author,
    this.artworkUrl,
  });

  factory BrowseShow.fromApi(Map<String, dynamic> data) => BrowseShow(
    id: _id(data['id']),
    title: _text(data, 'title'),
    author: _optionalText(data, 'author'),
    artworkUrl: _optionalText(data, 'artwork_url'),
  );

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;

  String get subtitle {
    final host = author?.trim();
    if (host == null || host.isEmpty) return 'Podcast';
    return host;
  }
}

class BrowseCategoryPage {
  const BrowseCategoryPage({required this.category, required this.shows});

  factory BrowseCategoryPage.fromApi(Map<String, dynamic> data) {
    final category = data['category'];
    if (category is! Map<String, dynamic>) throw _invalidBrowse;
    return BrowseCategoryPage(
      category: BrowseCategory.fromApi(category),
      shows: _list(data['shows']).map(BrowseShow.fromApi).toList(growable: false),
    );
  }

  final BrowseCategory category;
  final List<BrowseShow> shows;
}

class BrowseUiState {
  const BrowseUiState({
    this.slug,
    this.addedTitle,
    this.contentType = 0,
    this.chart = 0,
  });

  final String? slug;
  final String? addedTitle;
  final int contentType;
  final int chart;

  BrowseUiState copyWith({
    String? slug,
    bool clearSlug = false,
    String? addedTitle,
    bool clearAdded = false,
    int? contentType,
    int? chart,
  }) => BrowseUiState(
    slug: clearSlug ? null : (slug ?? this.slug),
    addedTitle: clearAdded ? null : (addedTitle ?? this.addedTitle),
    contentType: contentType ?? this.contentType,
    chart: chart ?? this.chart,
  );
}

class BrowseUiNotifier extends Notifier<BrowseUiState> {
  @override
  BrowseUiState build() => const BrowseUiState();

  void select(String slug) => state = state.copyWith(slug: slug);

  void rememberAdded(String title) => state = state.copyWith(addedTitle: title);

  void setContentType(int value) => state = state.copyWith(contentType: value);

  void setChart(int value) => state = state.copyWith(chart: value);
}

class BrowseRepository {
  const BrowseRepository(this._dio);

  final Dio _dio;

  Future<List<BrowseCategory>> categories({CancelToken? cancelToken}) async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>(
          '/browse',
          cancelToken: cancelToken,
        )).data,
      ).map(BrowseCategory.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<BrowseCategoryPage> category(
    String slug, {
    CancelToken? cancelToken,
  }) async {
    try {
      return BrowseCategoryPage.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/browse/${Uri.encodeComponent(slug)}',
            queryParameters: {'limit': 20},
            cancelToken: cancelToken,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<BrowseShow>> following({CancelToken? cancelToken}) async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>(
          '/me/following',
          queryParameters: {'limit': 20},
          cancelToken: cancelToken,
        )).data,
      ).map(BrowseShow.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> follow(String showId) async {
    try {
      final data = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/shows/${Uri.encodeComponent(showId)}/follow',
        )).data,
      );
      if (data['following'] != true) throw _invalidBrowse;
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final browseRepositoryProvider = Provider<BrowseRepository>(
  (ref) => BrowseRepository(ref.watch(dioProvider)),
);

final browseUiProvider = NotifierProvider<BrowseUiNotifier, BrowseUiState>(
  BrowseUiNotifier.new,
);

final browseCategoriesProvider = FutureProvider.autoDispose<List<BrowseCategory>>(
  (ref) {
    ref.watch(authSessionProvider.select((session) => session.userId));
    final token = CancelToken();
    ref.onDispose(token.cancel);
    return ref.watch(browseRepositoryProvider).categories(cancelToken: token);
  },
  retry: (count, error) => null,
);

final browseCategoryProvider = FutureProvider.autoDispose
    .family<BrowseCategoryPage, String>((ref, slug) {
      ref.watch(authSessionProvider.select((session) => session.userId));
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return ref.watch(browseRepositoryProvider).category(slug, cancelToken: token);
    }, retry: (count, error) => null);

final browseFollowingProvider = FutureProvider.autoDispose<List<BrowseShow>>((
  ref,
) {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(browseRepositoryProvider).following(cancelToken: token);
}, retry: (count, error) => null);

ApiFailure browseFailure(Object error) => profileFailure(error);
