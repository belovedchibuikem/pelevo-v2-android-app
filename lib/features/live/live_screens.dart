import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

class LiveSessionSummary {
  const LiveSessionSummary({
    required this.id,
    required this.title,
    required this.state,
    this.showId,
    this.viewerCount,
    this.scheduledAt,
    this.startedAt,
  });

  factory LiveSessionSummary.fromApi(Map<String, dynamic> data) {
    final id = data['id'];
    final title = data['title'];
    final state = data['state'];
    if (id is! String || title is! String || state is! String) {
      throw const ApiFailure(
        code: 'INVALID_RESPONSE',
        message: 'Live session data was incomplete.',
      );
    }
    return LiveSessionSummary(
      id: id,
      title: title,
      state: state,
      showId: data['show_id']?.toString(),
      viewerCount: data['viewer_count'] is int ? data['viewer_count'] as int : null,
      scheduledAt: data['scheduled_at'] as String?,
      startedAt: data['started_at'] as String?,
    );
  }

  final String id;
  final String title;
  final String state;
  final String? showId;
  final int? viewerCount;
  final String? scheduledAt;
  final String? startedAt;
}

class LiveSessionDetail extends LiveSessionSummary {
  const LiveSessionDetail({
    required super.id,
    required super.title,
    required super.state,
    super.showId,
    super.viewerCount,
    super.scheduledAt,
    super.startedAt,
    this.events = const [],
  });

  factory LiveSessionDetail.fromApi(Map<String, dynamic> data) {
    final base = LiveSessionSummary.fromApi(data);
    final events = <Map<String, dynamic>>[];
    final raw = data['events'];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map<String, dynamic>) events.add(row);
      }
    }
    return LiveSessionDetail(
      id: base.id,
      title: base.title,
      state: base.state,
      showId: base.showId,
      viewerCount: base.viewerCount,
      scheduledAt: base.scheduledAt,
      startedAt: base.startedAt,
      events: events,
    );
  }

  final List<Map<String, dynamic>> events;
}

class LiveRepository {
  LiveRepository(this._dio);
  final Dio _dio;

  Future<List<LiveSessionSummary>> list() async {
    try {
      final body = (await _dio.get<Map<String, dynamic>>('/live')).data;
      if (body == null || body['ok'] != true || body['data'] is! List) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Live sessions could not be read.',
        );
      }
      return [
        for (final row in body['data'] as List)
          if (row is Map<String, dynamic>) LiveSessionSummary.fromApi(row),
      ];
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<LiveSessionDetail> get(String id) async {
    try {
      return LiveSessionDetail.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/live/$id')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final liveRepositoryProvider = Provider(
  (ref) => LiveRepository(ref.watch(dioProvider)),
);

final liveSessionsProvider =
    FutureProvider.autoDispose<List<LiveSessionSummary>>((ref) async {
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return ref.watch(liveRepositoryProvider).list();
    }, retry: (_, _) => null);

final liveSessionProvider =
    FutureProvider.autoDispose.family<LiveSessionDetail, String>((ref, id) async {
      return ref.watch(liveRepositoryProvider).get(id);
    }, retry: (_, _) => null);

final selectedLiveSessionIdProvider =
    NotifierProvider<SelectedLiveSessionIdNotifier, String?>(
      SelectedLiveSessionIdNotifier.new,
    );

class SelectedLiveSessionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

class LiveNowScreen extends ConsumerWidget {
  const LiveNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveSessionsProvider);
    return PelevoPage(
      appBar: AppBar(
        title: const Text('Live Now'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/screen/home-feed'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is ApiFailure ? error.message : 'Live sessions unavailable.',
                style: TextStyle(color: context.pelevo.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              PelevoButton(
                label: 'Retry',
                color: PelevoColors.green,
                onPressed: () => ref.invalidate(liveSessionsProvider),
              ),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Text(
                'No live sessions are on now.',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
            );
          }
          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: context.pelevo.surfaceHigh,
                title: Text(session.title),
                subtitle: Text(
                  [
                    session.state.toUpperCase(),
                    if (session.viewerCount != null)
                      '${session.viewerCount} listening',
                  ].join(' · '),
                  style: TextStyle(color: context.pelevo.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ref.read(selectedLiveSessionIdProvider.notifier).select(
                    session.id,
                  );
                  context.push('/live/${session.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}

class LiveSessionScreen extends ConsumerWidget {
  const LiveSessionScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = sessionId ?? ref.watch(selectedLiveSessionIdProvider);
    if (id == null || id.isEmpty) {
      return PelevoPage(
        appBar: AppBar(title: const Text('Live')),
        child: Center(
          child: PelevoButton(
            label: 'Browse live sessions',
            color: PelevoColors.green,
            onPressed: () => context.go('/live'),
          ),
        ),
      );
    }
    final async = ref.watch(liveSessionProvider(id));
    return PelevoPage(
      appBar: AppBar(
        title: const Text('Live session'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/live'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ApiFailure ? error.message : 'Live session unavailable.',
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ),
        data: (session) => ListView(
          children: [
            Text(
              session.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              session.state == 'live'
                  ? 'On air now'
                  : session.state == 'scheduled'
                  ? 'Scheduled'
                  : 'Ended',
              style: TextStyle(
                color:
                    session.state == 'live'
                        ? PelevoColors.green
                        : context.pelevo.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (session.viewerCount != null) ...[
              const SizedBox(height: 8),
              Text('${session.viewerCount} listeners'),
            ],
            if (session.startedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Started ${session.startedAt}',
                style: TextStyle(color: context.pelevo.textMuted),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Recent events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (session.events.isEmpty)
              Text(
                'No events yet.',
                style: TextStyle(color: context.pelevo.textMuted),
              )
            else
              for (final event in session.events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${event['type'] ?? 'event'}'),
                  subtitle: Text(
                    '${event['created_at'] ?? ''}',
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                ),
            const SizedBox(height: 24),
            Text(
              'Audio/video streaming transport is host-operated. This screen shows the public live session state from Pelevo.',
              style: TextStyle(color: context.pelevo.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

final liveListenerScreens = <PelevoScreenSpec>[
  PelevoScreenSpec(
    id: 'live',
    title: 'Live Now',
    section: 'Live',
    builder: (_) => const LiveNowScreen(),
  ),
  PelevoScreenSpec(
    id: 'live-session',
    title: 'Live Session',
    section: 'Live',
    builder: (_) => const LiveSessionScreen(),
  ),
];
