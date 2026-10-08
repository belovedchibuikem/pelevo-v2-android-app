import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidComment = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Comments could not be verified. Please retry.',
);

const reportReasonCodes = {
  'Spam': 'spam',
  'Harassment': 'harassment',
  'Spoiler': 'other',
  'Hate or abuse': 'abuse',
  'Other': 'other',
};

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw _invalidComment;
}

bool _flag(Object? value) {
  if (value is bool) return value;
  if (value == 1 || value == '1') return true;
  if (value == 0 || value == '0') return false;
  throw _invalidComment;
}

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidComment;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidComment;
  return value as String?;
}

DateTime _date(Object? value) {
  if (value is! String) throw _invalidComment;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw _invalidComment;
  return parsed;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidComment;
  }
  final data = body['data'];
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidComment;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

PelevoComment commentFromApi(Map<String, dynamic> data, CommentTarget target) {
  final handle = data['author_handle'];
  if (handle != null && handle is! String) throw _invalidComment;
  return PelevoComment(
    id: _text(data, 'id'),
    targetKey: target.key,
    parentId: _optionalText(data, 'parent_id'),
    authorName: _text(data, 'author_name'),
    authorHandle: handle is String ? handle : '',
    body: _text(data, 'body'),
    createdAt: _date(data['created_at']),
    editedAt:
        data['edited_at'] == null ? null : _date(data['edited_at']),
    likeCount: _count(data['like_count']),
    likedByMe: _flag(data['liked_by_me']),
    isCreator: _flag(data['is_creator']),
    isMine: _flag(data['is_mine']),
    pinned: _flag(data['is_pinned']),
    repliesCount: _count(data['replies_count']),
  );
}

class CommentThreadArgs {
  const CommentThreadArgs({
    required this.target,
    required this.sort,
    this.parentId,
  });

  final CommentTarget target;
  final CommentSort sort;
  final String? parentId;

  @override
  bool operator ==(Object other) =>
      other is CommentThreadArgs &&
      other.target.key == target.key &&
      other.sort == sort &&
      other.parentId == parentId;

  @override
  int get hashCode => Object.hash(target.key, sort, parentId);
}

class CommentRepository {
  const CommentRepository(this._dio);

  final Dio _dio;

  Future<List<PelevoComment>> list(CommentThreadArgs args) async {
    try {
      final query = <String, dynamic>{
        'commentable_type': args.target.type.name,
        'commentable_id': args.target.id,
        'sort': args.sort.name,
      };
      if (args.parentId != null) {
        query['parent_id'] = args.parentId;
      }
      return _maps(
        (await _dio.get<Map<String, dynamic>>(
          '/comments',
          queryParameters: query,
        )).data,
      ).map((row) => commentFromApi(row, args.target)).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PelevoComment> post({
    required CommentTarget target,
    required String body,
    String? parentId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/comments',
        data: {
          'commentable_type': target.type.name,
          'commentable_id': target.id,
          'body': body,
          if (parentId != null) 'parent_id': parentId,
        },
      );
      return commentFromApi(requireApiData(response.data), target);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<PelevoComment> edit(String id, CommentTarget target, String body) async {
    try {
      return commentFromApi(
        requireApiData(
          (await _dio.patch<Map<String, dynamic>>(
            '/comments/$id',
            data: {'body': body},
          )).data,
        ),
        target,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> delete(String id) async {
    try {
      requireApiData(
        (await _dio.delete<Map<String, dynamic>>('/comments/$id')).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> like(String id, {required bool liked}) async {
    try {
      requireApiData(
        (await (liked
                ? _dio.post<Map<String, dynamic>>('/comments/$id/like')
                : _dio.delete<Map<String, dynamic>>('/comments/$id/like')))
            .data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> pin(String id, {required bool pinned}) async {
    try {
      requireApiData(
        (await (pinned
                ? _dio.put<Map<String, dynamic>>('/comments/$id/pin')
                : _dio.delete<Map<String, dynamic>>('/comments/$id/pin')))
            .data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> hide(String id) async {
    try {
      requireApiData(
        (await _dio.put<Map<String, dynamic>>('/comments/$id/hide')).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> report({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'reportable_type': 'comment',
            'reportable_id': commentId,
            'reason': reason,
            if (details != null && details.isNotEmpty) 'details': details,
          },
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

class CommentThreadController extends AsyncNotifier<List<PelevoComment>> {
  CommentThreadController(this.args);
  final CommentThreadArgs args;

  @override
  Future<List<PelevoComment>> build() {
    ref.watch(authSessionProvider.select((session) => session.userId));
    return ref.watch(commentRepositoryProvider).list(args);
  }

  List<PelevoComment> get _items => state.asData?.value ?? const [];

  void _set(List<PelevoComment> items) => state = AsyncData(items);

  Future<PelevoComment> post(String body, {String? parentId}) async {
    final created = await ref.read(commentRepositoryProvider).post(
      target: args.target,
      body: body,
      parentId: parentId,
    );
    _set([..._items, created]);
    ref.read(commentCountDeltaProvider.notifier).add(args.target.key, 1);
    return created;
  }

  Future<void> edit(String id, String body) async {
    final updated = await ref
        .read(commentRepositoryProvider)
        .edit(id, args.target, body);
    _set([
      for (final item in _items)
        if (item.id == id) updated else item,
    ]);
  }

  Future<void> delete(String id) async {
    await ref.read(commentRepositoryProvider).delete(id);
    _set(_items.where((item) => item.id != id).toList(growable: false));
    ref.read(commentCountDeltaProvider.notifier).add(args.target.key, -1);
  }

  Future<void> toggleLike(PelevoComment comment) async {
    final liked = !comment.likedByMe;
    _set([
      for (final item in _items)
        if (item.id == comment.id)
          item.copyWith(
            likedByMe: liked,
            likeCount: item.likeCount + (liked ? 1 : -1),
          )
        else
          item,
    ]);
    try {
      await ref.read(commentRepositoryProvider).like(comment.id, liked: liked);
    } catch (_) {
      _set([
        for (final item in _items)
          if (item.id == comment.id) comment else item,
      ]);
      rethrow;
    }
  }

  Future<void> togglePin(PelevoComment comment) async {
    final pinned = !comment.pinned;
    await ref.read(commentRepositoryProvider).pin(comment.id, pinned: pinned);
    _set([
      for (final item in _items)
        if (item.id == comment.id)
          item.copyWith(pinned: pinned)
        else if (pinned)
          item.copyWith(pinned: false)
        else
          item,
    ]);
  }

  Future<void> hide(PelevoComment comment) async {
    await ref.read(commentRepositoryProvider).hide(comment.id);
    _set(_items.where((item) => item.id != comment.id).toList(growable: false));
    ref.read(commentCountDeltaProvider.notifier).add(args.target.key, -1);
  }
}

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(ref.watch(dioProvider)),
);

final commentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentThreadController, List<PelevoComment>, CommentThreadArgs>(
      CommentThreadController.new,
    );

class CommentCountDeltaNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void add(String targetKey, int delta) {
    if (delta == 0) {
      return;
    }
    final next = Map<String, int>.from(state);
    next[targetKey] = (next[targetKey] ?? 0) + delta;
    state = next;
  }
}

final commentCountDeltaProvider =
    NotifierProvider<CommentCountDeltaNotifier, Map<String, int>>(
      CommentCountDeltaNotifier.new,
    );

class SelectedCommentTargetNotifier extends Notifier<CommentTarget?> {
  @override
  CommentTarget? build() => null;

  void select(CommentTarget? target) => state = target;
}

final selectedCommentTargetProvider =
    NotifierProvider<SelectedCommentTargetNotifier, CommentTarget?>(
      SelectedCommentTargetNotifier.new,
    );

class SelectedCommentIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedCommentIdProvider =
    NotifierProvider<SelectedCommentIdNotifier, String?>(
      SelectedCommentIdNotifier.new,
    );

class ReportingCommentNotifier extends Notifier<PelevoComment?> {
  @override
  PelevoComment? build() => null;

  void select(PelevoComment? comment) => state = comment;
}

final reportingCommentProvider =
    NotifierProvider<ReportingCommentNotifier, PelevoComment?>(
      ReportingCommentNotifier.new,
    );

ApiFailure commentFailure(Object error) => profileFailure(error);
