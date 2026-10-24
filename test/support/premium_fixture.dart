Map<String, dynamic> premiumPlanFixture({
  String id = 'plan-monthly',
  String slug = 'monthly',
  String name = 'Pelevo Plus Monthly',
  int priceMinor = 2500,
  String currency = 'NGN',
  String interval = 'month',
  int? trialMonths,
}) => {
  'id': id,
  'slug': slug,
  'name': name,
  'price_minor': priceMinor,
  'currency': currency,
  'interval': interval,
  if (trialMonths != null) 'trial_months': trialMonths,
};

Map<String, dynamic> premiumAccountFixture({
  Map<String, dynamic>? entitlement,
  Map<String, dynamic>? subscription,
}) => {'entitlement': entitlement, 'subscription': subscription};

Map<String, dynamic> premiumEntitlementFixture({
  String state = 'active',
  String planId = 'plan-monthly',
}) => {
  'state': state,
  'starts_at': '2026-08-10T00:00:00Z',
  'ends_at': '2026-10-10T00:00:00Z',
  'plan_id': planId,
};

Map<String, dynamic> premiumInvoiceFixture({
  String id = 'invoice-1',
  int totalMinor = 2500,
  String currency = 'NGN',
  String state = 'paid',
  String? receiptUrl,
}) => {
  'id': id,
  'total_minor': totalMinor,
  'currency': currency,
  'state': state,
  'receipt_url': receiptUrl,
  'paid_at': '2026-09-10T09:00:00Z',
  'created_at': '2026-09-10T09:00:00Z',
};

Map<String, dynamic> premiumCheckoutFixture({
  String id = 'checkout-1',
  String state = 'pending',
  String? checkoutUrl = 'https://flutterwave.test/pay',
  int amountMinor = 2500,
  String currency = 'NGN',
  String provider = 'flutterwave',
}) => {
  'id': id,
  'state': state,
  'checkout_url': checkoutUrl,
  'expires_at': '2026-09-10T13:00:00Z',
  'amount_minor': amountMinor,
  'currency': currency,
  'provider': provider,
};

Map<String, dynamic> premiumExclusiveFixture({
  String id = 'catalog-episode-1',
  String showId = 'catalog-show-1',
  String title = 'Plus Episode',
}) => {
  'id': id,
  'show_id': showId,
  'title': title,
  'show_title': 'Plus Show',
  'artwork_url': null,
  'duration_seconds': 120,
  'published_at': '2026-09-10T00:00:00Z',
};
