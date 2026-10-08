import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/earn/earn_screens.dart';
import 'package:pelevo/features/earn/earn_wallet_data.dart';
import 'package:pelevo/features/earn/withdrawal_screens.dart';
import 'support/api_adapter.dart';

Map<String, dynamic> wallet() => {
  'user_id': 'owner',
  'unit': 'ECN',
  'balance': '9007199254740993',
  'minimum_withdrawal': '2000',
  'withdrawals_enabled': false,
};
Map<String, dynamic> row(String id) => {
  'id': id,
  'coins': '1500',
  'state': 'queued',
  'created_at': '2026-09-10T09:00:00Z',
};
ResponseBody page(List<Map<String, dynamic>> rows, {String? cursor}) =>
    ResponseBody.fromString(
      jsonEncode({
        'ok': true,
        'data': rows,
        'meta': {
          'user_id': 'owner',
          'cursor': cursor,
          'has_more': cursor != null,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  Future<void> mount(
    WidgetTester tester,
    ApiAdapter adapter,
    Widget screen,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          initialAuthSessionProvider.overrideWithValue(
            const AuthSession(
              accessToken: 'test',
              refreshToken: 'test',
              deviceId: 'test',
              user: {'id': 'owner'},
            ),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('wallet rejects owner mismatch, floats and wrong currency', () {
    expect(
      EarnWallet.parse(wallet(), 'owner').balance,
      BigInt.parse('9007199254740993'),
    );
    for (final patch in [
      {'user_id': 'other'},
      {'balance': 1.5},
      {'unit': 'PCN'},
      {'minimum_withdrawal': '0'},
    ]) {
      expect(
        () => EarnWallet.parse({...wallet(), ...patch}, 'owner'),
        throwsException,
      );
    }
  });

  testWidgets('wallet binds exact balance and blocks unconnected payout', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) => jsonResponse(wallet())),
      const EarnWalletScreen(),
    );
    expect(find.text('9007199254740993 coins'), findsOneWidget);
    expect(
      find.textContaining('Minimum withdrawal: 2000 coins'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Request Payout'));
    await tester.tap(find.text('Request Payout'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No withdrawal has been submitted.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed wallet never renders a fabricated zero balance and retries',
    (tester) async {
      var failed = true;
      await mount(
        tester,
        ApiAdapter((request) {
          if (failed) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            );
          }
          return jsonResponse(wallet());
        }),
        const EarnWalletScreen(),
      );
      expect(find.text('0 coins'), findsNothing);
      expect(find.text('Request Payout'), findsNothing);
      failed = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('9007199254740993 coins'), findsOneWidget);
    },
  );

  testWidgets(
    'history keeps rows after pagination failure and retries same cursor',
    (tester) async {
      var tries = 0;
      await mount(
        tester,
        ApiAdapter((request) {
          if (request.queryParameters['cursor'] == null) {
            return page([row('first')], cursor: 'next');
          }
          expect(request.queryParameters['cursor'], 'next');
          if (++tries == 1) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            );
          }
          return page([row('second')]);
        }),
        const WithdrawHistoryScreen(),
      );
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.textContaining('first'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('second'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    },
  );

  testWidgets('empty history contains no fabricated paid withdrawal', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) => page([])),
      const WithdrawHistoryScreen(),
    );
    expect(find.text('No withdrawals yet'), findsOneWidget);
    expect(find.textContaining('Paid'), findsNothing);
  });

  test('legacy Earn methods cannot credit or submit a withdrawal', () {
    final before = EarnPlaybackSession.instance.walletCoins;
    EarnPlaybackSession.instance.togglePlay();
    expect(EarnPlaybackSession.instance.playing, false);
    expect(EarnPlaybackSession.instance.walletCoins, before);
    expect(EarnWalletService.instance.submitDraft(), isNull);
    expect(EarnWalletService.instance.history, isEmpty);
    const method = PayoutMethodConfig(
      gateway: PayoutGateway.paystack,
      destination: 'test destination',
      accountName: 'Test',
    );
    EarnWalletService.instance.linkMethod(method);
    expect(EarnWalletService.instance.isLinked(PayoutGateway.paystack), false);
  });

  testWidgets('direct success route does not invent a confirmed withdrawal', (
    tester,
  ) async {
    await mount(
      tester,
      ApiAdapter((request) => page([])),
      const WithdrawSuccessScreen(),
    );
    expect(find.text('No withdrawal confirmation'), findsOneWidget);
    expect(find.text('Your payout request was submitted.'), findsNothing);
  });
}
