import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/creator/claim_data.dart';
import '../support/api_adapter.dart';
import '../support/claim_fixture.dart';

void main() {
  test('search and show payloads reject invented list shapes', () {
    expect(
      () => ClaimShow.fromJson({'title': 'The Relationship Podcast'}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ClaimStart.fromApi({'accepted': true}, method: 'email'),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('start, verify and description confirm parse server envelopes', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      return jsonResponse(switch (request.path) {
        '/search' => {
          'shows': [claimShowFixture()],
        },
        '/shows/show-1/claims' => claimStartFixture(
          method: '${request.data['method']}',
        ),
        '/claims/claim-1/verify' => {'claim_id': 'claim-1', 'state': 'verified'},
        '/claims/claim-1/description/confirm' => {
          'claim_id': 'claim-1',
          'state': 'verifying',
        },
        _ => throw StateError(request.path),
      }, status: request.path.endsWith('/claims') ? 201 : 200);
    });
    final repository = ClaimRepository(dio);

    final shows = await repository.searchShows('Owned');
    expect(shows.single.title, 'Owned Show');
    expect(seen.queryParameters['q'], 'Owned');
    expect(seen.queryParameters['type'], 'show');

    final email = await repository.startClaim(
      showId: 'show-1',
      method: 'email',
    );
    expect(email.maskedDestination, 'o****@example.com');
    expect(email.challenge, isNull);

    final description = await repository.startClaim(
      showId: 'show-1',
      method: 'description',
    );
    expect(description.challenge, 'PELEVO-VERIFY-TESTTOKEN12');

    final verified = await repository.verify(
      claimId: 'claim-1',
      code: '123456',
    );
    expect(verified.state, 'verified');
    expect(seen.data, {'code': '123456'});

    final confirming = await repository.confirmDescription('claim-1');
    expect(confirming.state, 'verifying');
  });
}
