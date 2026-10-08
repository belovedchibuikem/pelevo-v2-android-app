import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

const _invalidGift = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Gift data could not be verified. Please retry.',
);

int _coins(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw _invalidGift;
}

int _signed(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw _invalidGift;
}

String _text(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.isEmpty) throw _invalidGift;
  return value;
}

String? _optionalText(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value != null && value is! String) throw _invalidGift;
  return value as String?;
}

DateTime _date(Object? value) {
  if (value is! String) throw _invalidGift;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw _invalidGift;
  return parsed;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
  if (body == null || body['ok'] != true) {
    requireApiData(body);
    throw _invalidGift;
  }
  final data = body['data'];
  if (data is! List || data.any((row) => row is! Map<String, dynamic>)) {
    throw _invalidGift;
  }
  return data.whereType<Map<String, dynamic>>().toList(growable: false);
}

class GiftWallet {
  const GiftWallet({required this.unit, required this.balance});

  factory GiftWallet.fromApi(Map<String, dynamic> data) {
    if (data['unit'] != 'PCN') throw _invalidGift;
    return GiftWallet(unit: 'PCN', balance: _coins(data['balance']));
  }

  final String unit;
  final int balance;
}

class GiftPack {
  const GiftPack({
    required this.id,
    required this.store,
    required this.productId,
    required this.coins,
    required this.unit,
  });

  factory GiftPack.fromApi(Map<String, dynamic> data) {
    final store = _text(data, 'store');
    if (store != 'apple' && store != 'google') throw _invalidGift;
    if (data['unit'] != 'PCN') throw _invalidGift;
    return GiftPack(
      id: _text(data, 'id'),
      store: store,
      productId: _text(data, 'product_id'),
      coins: _coins(data['coins']),
      unit: 'PCN',
    );
  }

  final String id;
  final String store;
  final String productId;
  final int coins;
  final String unit;
}

class GiftTypeOption {
  const GiftTypeOption({
    required this.id,
    required this.slug,
    required this.name,
    required this.coins,
  });

  factory GiftTypeOption.fromApi(Map<String, dynamic> data) {
    return GiftTypeOption(
      id: _text(data, 'id'),
      slug: _text(data, 'slug'),
      name: _text(data, 'name'),
      coins: _coins(data['coins']),
    );
  }

  final String id;
  final String slug;
  final String name;
  final int coins;
}

class GiftActivity {
  const GiftActivity({
    required this.id,
    required this.eventType,
    required this.amount,
    required this.unit,
    required this.createdAt,
  });

  factory GiftActivity.fromApi(Map<String, dynamic> data) {
    if (data['unit'] != 'PCN') throw _invalidGift;
    return GiftActivity(
      id: _text(data, 'id'),
      eventType: _text(data, 'event_type'),
      amount: _signed(data['amount']),
      unit: 'PCN',
      createdAt: _date(data['created_at']),
    );
  }

  final String id;
  final String eventType;
  final int amount;
  final String unit;
  final DateTime createdAt;

  bool get isCredit => amount > 0;
}

class GiftReceipt {
  const GiftReceipt({
    required this.id,
    required this.giftTypeName,
    required this.coins,
    required this.creatorDisplayName,
    required this.remainingBalance,
    required this.createdAt,
    this.creatorHandle,
    this.message,
  });

  factory GiftReceipt.fromApi(Map<String, dynamic> data) {
    return GiftReceipt(
      id: _text(data, 'id'),
      giftTypeName: _text(data, 'gift_type_name'),
      coins: _coins(data['coins']),
      creatorDisplayName: _text(data, 'creator_display_name'),
      creatorHandle: _optionalText(data, 'creator_handle'),
      message: _optionalText(data, 'message'),
      remainingBalance: _coins(data['remaining_balance']),
      createdAt: _date(data['created_at']),
    );
  }

  final String id;
  final String giftTypeName;
  final int coins;
  final String creatorDisplayName;
  final String? creatorHandle;
  final String? message;
  final int remainingBalance;
  final DateTime createdAt;
}

class VerifiedGiftPurchase {
  const VerifiedGiftPurchase({
    required this.id,
    required this.coins,
    required this.remainingBalance,
  });

  factory VerifiedGiftPurchase.fromApi(Map<String, dynamic> data) {
    if (data['unit'] != 'PCN') throw _invalidGift;
    return VerifiedGiftPurchase(
      id: _text(data, 'id'),
      coins: _coins(data['coins']),
      remainingBalance: _coins(data['remaining_balance']),
    );
  }

  final String id;
  final int coins;
  final int remainingBalance;
}

class GiftRepository {
  const GiftRepository(this._dio);

  final Dio _dio;

  Future<GiftWallet> wallet() async {
    try {
      return GiftWallet.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/gifts/wallet')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<GiftPack>> packs() async {
    try {
      final items =
          _maps(
            (await _dio.get<Map<String, dynamic>>('/gifts/packs')).data,
          ).map(GiftPack.fromApi).toList(growable: false);
      final seen = <String>{};
      return [
        for (final pack in items)
          if (seen.add(pack.productId)) pack,
      ];
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<GiftTypeOption>> catalog() async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>('/gifts/catalog')).data,
      ).map(GiftTypeOption.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<List<GiftActivity>> activity() async {
    try {
      return _maps(
        (await _dio.get<Map<String, dynamic>>('/gifts/wallet/activity')).data,
      ).map(GiftActivity.fromApi).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<GiftReceipt> receipt(String id) async {
    try {
      return GiftReceipt.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/gifts/$id')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<GiftReceipt> send({
    required String giftTypeId,
    required String creatorProfileId,
    required String idempotencyKey,
    String? message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/gifts/send',
        data: {
          'gift_type_id': giftTypeId,
          'creator_profile_id': creatorProfileId,
          if (message != null && message.isNotEmpty) 'message': message,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return GiftReceipt.fromApi(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<VerifiedGiftPurchase> verifyIap({
    required String store,
    required String receipt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/iap/verify',
        data: {'store': store, 'receipt': receipt},
      );
      return VerifiedGiftPurchase.fromApi(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }
}

final giftRepositoryProvider = Provider<GiftRepository>(
  (ref) => GiftRepository(ref.watch(dioProvider)),
);

final giftWalletProvider = FutureProvider.autoDispose<GiftWallet>((ref) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(giftRepositoryProvider).wallet();
}, retry: (count, error) => null);

final giftPacksProvider = FutureProvider.autoDispose<List<GiftPack>>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(giftRepositoryProvider).packs();
}, retry: (count, error) => null);

final giftCatalogProvider = FutureProvider.autoDispose<List<GiftTypeOption>>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(giftRepositoryProvider).catalog();
}, retry: (count, error) => null);

final giftActivityProvider = FutureProvider.autoDispose<List<GiftActivity>>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(giftRepositoryProvider).activity();
}, retry: (count, error) => null);

class SelectedGiftIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedGiftIdProvider =
    NotifierProvider<SelectedGiftIdNotifier, String?>(SelectedGiftIdNotifier.new);

final giftReceiptProvider = FutureProvider.autoDispose<GiftReceipt?>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final id = ref.watch(selectedGiftIdProvider);
  if (id == null || id.isEmpty) return null;
  return ref.watch(giftRepositoryProvider).receipt(id);
}, retry: (count, error) => null);

class LastVerifiedGiftPurchaseNotifier extends Notifier<VerifiedGiftPurchase?> {
  @override
  VerifiedGiftPurchase? build() => null;

  void select(VerifiedGiftPurchase? value) => state = value;
}

final lastVerifiedGiftPurchaseProvider =
    NotifierProvider<LastVerifiedGiftPurchaseNotifier, VerifiedGiftPurchase?>(
      LastVerifiedGiftPurchaseNotifier.new,
    );

class LastGiftPurchaseErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? value) => state = value;
}

final lastGiftPurchaseErrorProvider =
    NotifierProvider<LastGiftPurchaseErrorNotifier, String?>(
      LastGiftPurchaseErrorNotifier.new,
    );

ApiFailure giftFailure(Object error) => profileFailure(error);
