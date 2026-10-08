import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/comments/comment_data.dart';
import 'package:pelevo/features/comments/comment_service.dart';
import '../support/api_adapter.dart';
import '../support/comment_fixture.dart';

void main() {
  test('comment list and mutations parse presented fields', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.path == '/comments' && request.method == 'POST') {
        return jsonResponse(
          commentFixture(id: 'posted-1', body: '${request.data['body']}', isMine: true),
          status: 201,
        );
      }
      if (request.path == '/reports') {
        return jsonResponse({'id': 'report-1', 'state': 'open'}, status: 201);
      }
      return jsonResponse(episodeCommentsFixture());
    });
    final repository = CommentRepository(dio);
    final target = const CommentTarget.episode('ep-1');
    final items = await repository.list(
      CommentThreadArgs(target: target, sort: CommentSort.newest),
    );
    expect(items.first.authorName, 'Listener Ada');
    expect(items.first.body, 'This episode is worth a second listen.');
    expect(items.first.repliesCount, 1);
    expect(seen.queryParameters['sort'], 'newest');

    final posted = await repository.post(target: target, body: 'Listening again tonight.');
    expect(posted.body, 'Listening again tonight.');
    expect(posted.isMine, isTrue);

    await repository.report(commentId: 'comment-1', reason: 'spam');
    expect(seen.path, '/reports');
    expect(seen.data['reason'], 'spam');
  });

  test('comment presentation rejects missing author fields', () {
    expect(
      () => commentFromApi({
        'id': 'comment-1',
        'body': 'Hello',
        'created_at': '2026-09-10T00:00:00Z',
        'like_count': 0,
        'liked_by_me': false,
        'is_mine': false,
        'is_creator': false,
        'is_pinned': false,
        'replies_count': 0,
      }, const CommentTarget.episode('ep-1')),
      throwsA(isA<ApiFailure>()),
    );
  });
}
