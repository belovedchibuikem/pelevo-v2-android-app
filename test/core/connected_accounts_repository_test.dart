import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/profile/connected_accounts_data.dart';
import '../support/api_adapter.dart';
import '../support/profile_fixture.dart';

void main() {
  test('list parses public fields and rejects another owner', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = ApiAdapter((request) {
      expect(request.path, '/me/connected-accounts');
      return jsonResponse(
        [connectedAccountFixture()],
        meta: {'user_id': 'test-user'},
      );
    });
    final page = await ConnectedAccountsRepository(dio).list(
      'test-user',
      CancelToken(),
    );
    expect(page.accounts.single.provider, 'google');
    expect(page.accounts.single.email, 'google@example.invalid');
    expect(page.forProvider('apple'), isNull);

    dio.httpClientAdapter = ApiAdapter(
      (request) => jsonResponse(
        [connectedAccountFixture()],
        meta: {'user_id': 'other-user'},
      ),
    );
    await expectLater(
      ConnectedAccountsRepository(dio).list('test-user', CancelToken()),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('facebook and missing fields cannot be parsed as linked accounts', () {
    expect(
      () => ConnectedAccount.parse({
        ...connectedAccountFixture(),
        'provider': 'facebook',
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => ConnectedAccount.parse({
        ...connectedAccountFixture(),
        'id': '',
      }),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('link and disconnect stay on public receipts', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.invalid/api/v1'));
    addTearDown(() => dio.close(force: true));
    late RequestOptions seen;
    dio.httpClientAdapter = ApiAdapter((request) {
      seen = request;
      if (request.method == 'POST') {
        expect(request.data, {
          'provider': 'apple',
          'token': 'provider-token',
        });
        return jsonResponse(
          connectedAccountFixture(id: 'acct-apple', provider: 'apple'),
          status: 201,
        );
      }
      return jsonResponse({'disconnected': true});
    });
    final repository = ConnectedAccountsRepository(dio);
    final linked = await repository.link(
      provider: 'apple',
      token: 'provider-token',
    );
    expect(linked.provider, 'apple');
    await repository.disconnect('acct-google');
    expect(seen.method, 'DELETE');
    expect(seen.path, '/me/connected-accounts/acct-google');
  });
}
