import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';

const _invalidStats = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Listening stats could not be verified. Please retry.',
);

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is num) return '$value';
  throw _invalidStats;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return '$value';
  throw _invalidStats;
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed >= 0) return parsed;
  }
  throw _invalidStats;
}

List<Map<String, dynamic>> _maps(Object? data) {
  if (data == null) return const [];
  if (data is! List) throw _invalidStats;
  final rows = <Map<String, dynamic>>[];
  for (final row in data) {
    if (row is Map<String, dynamic>) {
      rows.add(row);
    } else if (row is Map) {
      rows.add(Map<String, dynamic>.from(row));
    } else {
      throw _invalidStats;
    }
  }
  return rows;
}

DateTime _day(Object? value) {
  final raw = switch (value) {
    String s => s,
    DateTime d => d.toIso8601String(),
    _ => value == null ? '' : '$value',
  };
  final date = DateTime.tryParse(raw);
  if (date == null) throw _invalidStats;
  return DateTime(date.year, date.month, date.day);
}

class ListenerDailyStat {
  const ListenerDailyStat(
    this.date,
    this.listeningSeconds,
    this.episodesStarted,
    this.episodesCompleted,
  );

  factory ListenerDailyStat.parse(Map<String, dynamic> data) =>
      ListenerDailyStat(
        _day(data['date']),
        _count(data['listening_seconds']),
        _count(data['episodes_started']),
        _count(data['episodes_completed']),
      );

  final DateTime date;
  final int listeningSeconds, episodesStarted, episodesCompleted;
}

class ListenerStreak {
  const ListenerStreak(this.currentDays, this.longestDays, this.lastQualifiedDate);

  factory ListenerStreak.parse(Map<String, dynamic> data) {
    final last = data['last_qualified_date'];
    return ListenerStreak(
      _count(data['current_days']),
      _count(data['longest_days']),
      last == null || (last is String && last.isEmpty) ? null : _day(last),
    );
  }

  final int currentDays, longestDays;
  final DateTime? lastQualifiedDate;
}

class ListenerAchievement {
  const ListenerAchievement(this.slug, this.name, this.description, this.earnedAt);

  factory ListenerAchievement.parse(Map<String, dynamic> data) {
    final earned = _text(data, 'earned_at');
    final at = DateTime.tryParse(earned);
    if (at == null) throw _invalidStats;
    return ListenerAchievement(
      _text(data, 'slug'),
      _text(data, 'name'),
      _optionalText(data, 'description') ?? '',
      at,
    );
  }

  final String slug, name, description;
  final DateTime earnedAt;
}

class ListenerStatShow {
  const ListenerStatShow(
    this.id,
    this.title,
    this.artworkUrl,
    this.listeningSeconds,
    this.episodesCompleted,
  );

  factory ListenerStatShow.parse(Map<String, dynamic> data) => ListenerStatShow(
    _text(data, 'id'),
    _text(data, 'title'),
    _optionalText(data, 'artwork_url'),
    _count(data['listening_seconds']),
    _count(data['episodes_completed']),
  );

  final String id, title;
  final String? artworkUrl;
  final int listeningSeconds, episodesCompleted;
}

class ListenerStatCategory {
  const ListenerStatCategory(this.id, this.name, this.slug, this.listeningSeconds);

  factory ListenerStatCategory.parse(Map<String, dynamic> data) =>
      ListenerStatCategory(
        _text(data, 'id'),
        _text(data, 'name'),
        _text(data, 'slug'),
        _count(data['listening_seconds']),
      );

  final String id, name, slug;
  final int listeningSeconds;
}

class ListenerStats {
  const ListenerStats({
    required this.listeningSeconds,
    required this.episodesStarted,
    required this.episodesCompleted,
    required this.showsFollowed,
    required this.episodesSaved,
    required this.reviews,
    required this.downloadsCount,
    required this.daily,
    required this.streak,
    required this.achievements,
    required this.shows,
    required this.categories,
  });

  factory ListenerStats.parse(Map<String, dynamic> data) {
    final streak = data['streak'];
    Map<String, dynamic>? streakMap;
    if (streak is Map<String, dynamic>) {
      streakMap = streak;
    } else if (streak is Map) {
      streakMap = Map<String, dynamic>.from(streak);
    } else if (streak != null) {
      throw _invalidStats;
    }
    return ListenerStats(
      listeningSeconds: _count(data['listening_seconds']),
      episodesStarted: _count(data['episodes_started']),
      episodesCompleted: _count(data['episodes_completed']),
      showsFollowed: _count(data['shows_followed']),
      episodesSaved: _count(data['episodes_saved']),
      reviews: _count(data['reviews']),
      downloadsCount: _count(data['downloads_count']),
      daily: _maps(data['daily']).map(ListenerDailyStat.parse).toList(growable: false),
      streak: streakMap == null ? null : ListenerStreak.parse(streakMap),
      achievements:
          _maps(data['achievements']).map(ListenerAchievement.parse).toList(
            growable: false,
          ),
      shows: _maps(data['shows']).map(ListenerStatShow.parse).toList(growable: false),
      categories:
          _maps(data['categories']).map(ListenerStatCategory.parse).toList(
            growable: false,
          ),
    );
  }

  final int listeningSeconds,
      episodesStarted,
      episodesCompleted,
      showsFollowed,
      episodesSaved,
      reviews,
      downloadsCount;
  final List<ListenerDailyStat> daily;
  final ListenerStreak? streak;
  final List<ListenerAchievement> achievements;
  final List<ListenerStatShow> shows;
  final List<ListenerStatCategory> categories;

  int get inProgress =>
      episodesStarted < episodesCompleted ? 0 : episodesStarted - episodesCompleted;

  int get averageListenSeconds =>
      episodesStarted == 0 ? 0 : listeningSeconds ~/ episodesStarted;

  List<ListenerDailyStat> inRange(DateTime start, DateTime end) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    return daily
        .where((row) => !row.date.isBefore(from) && !row.date.isAfter(to))
        .toList(growable: false);
  }

  int listeningIn(Iterable<ListenerDailyStat> rows) =>
      rows.fold<int>(0, (sum, row) => sum + row.listeningSeconds);

  int startedIn(Iterable<ListenerDailyStat> rows) =>
      rows.fold<int>(0, (sum, row) => sum + row.episodesStarted);

  int completedIn(Iterable<ListenerDailyStat> rows) =>
      rows.fold<int>(0, (sum, row) => sum + row.episodesCompleted);
}

class ListenerStatsRepository {
  ListenerStatsRepository(this._dio);
  final Dio _dio;

  Future<ListenerStats> me(CancelToken token) async {
    try {
      return ListenerStats.parse(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/stats/me',
            cancelToken: token,
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final listenerStatsRepositoryProvider = Provider(
  (ref) => ListenerStatsRepository(ref.watch(dioProvider)),
);

final listenerStatsProvider = FutureProvider.autoDispose<ListenerStats>((
  ref,
) async {
  final token = CancelToken();
  ref.onDispose(() => token.cancel());
  return ref.watch(listenerStatsRepositoryProvider).me(token);
}, retry: (count, error) => null);

ApiFailure statsFailure(Object error) =>
    error is ApiFailure ? error : catalogFailure(error);

String formatStatsDuration(int seconds) => formatCatalogDuration(seconds);

String? formatStatsDelta(int current, int previous) {
  if (previous <= 0) return null;
  final change = (((current - previous) / previous) * 100).round();
  return '${change >= 0 ? '+' : ''}$change%';
}
