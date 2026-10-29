import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

const _invalidStudio = ApiFailure(
  code: 'INVALID_RESPONSE',
  message: 'Creator Studio could not be loaded. Please try again.',
);

class StudioProfile {
  const StudioProfile({
    required this.id,
    required this.displayName,
    this.status,
  });

  factory StudioProfile.fromApi(Map<String, dynamic> data) {
    final id = data['id'];
    final name = data['display_name'];
    if (id == null || '$id'.isEmpty || name is! String || name.trim().isEmpty) {
      throw _invalidStudio;
    }
    return StudioProfile(
      id: '$id',
      displayName: name,
      status: data['status'] as String?,
    );
  }

  final String id;
  final String displayName;
  final String? status;
}

class StudioShow {
  const StudioShow({
    required this.id,
    required this.title,
    this.author,
    this.artworkUrl,
    this.episodeCount,
    this.followerCount,
    this.updatedAt,
  });

  factory StudioShow.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || '$id'.isEmpty) {
      throw _invalidStudio;
    }
    return StudioShow(
      id: '$id',
      title: '${json['title'] ?? ''}',
      author: json['author'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      episodeCount: (json['episodes_count'] as num?)?.toInt(),
      followerCount: (json['follower_count'] as num?)?.toInt(),
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String id;
  final String title;
  final String? author;
  final String? artworkUrl;
  final int? episodeCount;
  final int? followerCount;
  final String? updatedAt;
}

class StudioEpisode {
  const StudioEpisode({
    required this.id,
    required this.title,
    this.showId,
    this.showTitle,
    this.description,
    this.publishedAt,
    this.artworkUrl,
    this.audioUrl,
    this.durationSeconds,
    this.availability,
  });

  factory StudioEpisode.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || '$id'.isEmpty) {
      throw _invalidStudio;
    }
    return StudioEpisode(
      id: '$id',
      title: '${json['title'] ?? ''}',
      showId: json['show_id'] == null ? null : '${json['show_id']}',
      showTitle: json['show_title'] as String?,
      description: json['description'] as String?,
      publishedAt: json['published_at'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      availability: json['availability'] as String?,
    );
  }

  final String id;
  final String title;
  final String? showId;
  final String? showTitle;
  final String? description;
  final String? publishedAt;
  final String? artworkUrl;
  final String? audioUrl;
  final int? durationSeconds;
  final String? availability;

  String get publishedLabel {
    if (publishedAt == null || publishedAt!.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(publishedAt!);
    if (parsed == null) {
      return publishedAt!;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  String get durationLabel {
    final seconds = durationSeconds;
    if (seconds == null || seconds < 0) {
      return '';
    }
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  String get subtitle {
    final parts = [
      if (showTitle != null && showTitle!.isNotEmpty) showTitle!,
      if (publishedLabel.isNotEmpty) publishedLabel,
      if (durationLabel.isNotEmpty) durationLabel,
    ];
    return parts.join(' · ');
  }

  String get statusLabel {
    if (availability == 'available') {
      return 'Published';
    }
    if (availability == 'draft') {
      return 'Draft';
    }
    return availability ?? '';
  }
}

class StudioEpisodePage {
  const StudioEpisodePage({
    required this.items,
    this.cursor,
    this.hasMore = false,
  });

  factory StudioEpisodePage.fromEnvelope(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidStudio;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidStudio;
    }
    final meta = body['meta'];
    return StudioEpisodePage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(StudioEpisode.fromJson)
          .toList(growable: false),
      cursor: meta is Map ? meta['cursor'] as String? : null,
      hasMore: meta is Map && meta['has_more'] == true,
    );
  }

  final List<StudioEpisode> items;
  final String? cursor;
  final bool hasMore;
}

class StudioReel {
  const StudioReel({
    required this.id,
    this.caption,
    this.headline,
    this.state,
    this.episodeId,
    this.episodeTitle,
    this.publishedAt,
    this.thumbnailPath,
    this.mediaUrl,
    this.durationMs,
    this.linked = false,
  });

  factory StudioReel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || '$id'.isEmpty) {
      throw _invalidStudio;
    }
    final linked = json['linked'];
    return StudioReel(
      id: '$id',
      caption: json['caption'] as String?,
      headline: json['title'] as String?,
      state: json['state'] as String?,
      episodeId: json['episode_id'] == null ? null : '${json['episode_id']}',
      episodeTitle: json['episode_title'] as String?,
      publishedAt: json['published_at'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      mediaUrl: json['media_url'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      linked: linked == true || linked == 1 || linked == '1',
    );
  }

  final String id;
  final String? caption;
  final String? headline;
  final String? state;
  final String? episodeId;
  final String? episodeTitle;
  final String? publishedAt;
  final String? thumbnailPath;
  final String? mediaUrl;
  final int? durationMs;
  final bool linked;

  String get title {
    final named = headline?.trim();
    if (named != null && named.isNotEmpty) return named;
    final cap = caption?.trim();
    if (cap != null && cap.isNotEmpty) return cap;
    return '';
  }

  String? get artworkUrl {
    for (final value in [thumbnailPath, mediaUrl]) {
      if (value != null &&
          (value.startsWith('http://') || value.startsWith('https://'))) {
        return value;
      }
    }
    return null;
  }

  String get publishedLabel {
    if (publishedAt == null || publishedAt!.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(publishedAt!);
    if (parsed == null) {
      return publishedAt!;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  String get subtitle {
    final episode =
        episodeTitle == null || episodeTitle!.trim().isEmpty
            ? ''
            : 'Linked to ${episodeTitle!.trim()}';
    final parts = [
      if (episode.isNotEmpty) episode,
      if (publishedLabel.isNotEmpty) publishedLabel,
    ];
    return parts.join(' · ');
  }

  String get statusLabel {
    return switch (state) {
      'published' => 'Published',
      'draft' => 'Draft',
      'processing' => 'Processing',
      'pending_review' => 'In review',
      'failed' => 'Failed',
      'rejected' => 'Rejected',
      _ => state ?? '',
    };
  }
}

class StudioReelPage {
  const StudioReelPage({
    required this.items,
    this.cursor,
    this.hasMore = false,
  });

  factory StudioReelPage.fromEnvelope(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidStudio;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidStudio;
    }
    final meta = body['meta'];
    return StudioReelPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(StudioReel.fromJson)
          .toList(growable: false),
      cursor: meta is Map ? meta['cursor'] as String? : null,
      hasMore: meta is Map && meta['has_more'] == true,
    );
  }

  final List<StudioReel> items;
  final String? cursor;
  final bool hasMore;
}

enum StudioReelFilter { all, linked, drafts }

class StudioReelDraft {
  const StudioReelDraft({
    required this.id,
    this.caption,
    this.title,
    this.state,
    this.episodeId,
    this.showId,
  });

  factory StudioReelDraft.fromApi(Map<String, dynamic> data) {
    final id = data['id'];
    if (id == null || '$id'.isEmpty) {
      throw _invalidStudio;
    }
    return StudioReelDraft(
      id: '$id',
      caption: data['caption'] as String?,
      title: data['title'] as String?,
      state: data['state'] as String?,
      episodeId: data['episode_id'] == null ? null : '${data['episode_id']}',
      showId: data['show_id'] == null ? null : '${data['show_id']}',
    );
  }

  final String id;
  final String? caption;
  final String? title;
  final String? state;
  final String? episodeId;
  final String? showId;
}

class StudioAudience {
  const StudioAudience({
    required this.followers,
    required this.showFollowers,
    required this.listeners30d,
  });

  factory StudioAudience.fromApi(Map<String, dynamic> data) {
    final followers = data['followers'];
    final showFollowers = data['show_followers'];
    final listeners = data['listeners_30d'];
    if (followers is! num || showFollowers is! num || listeners is! num) {
      throw _invalidStudio;
    }
    return StudioAudience(
      followers: followers.toInt(),
      showFollowers: showFollowers.toInt(),
      listeners30d: listeners.toInt(),
    );
  }

  final int followers;
  final int showFollowers;
  final int listeners30d;
}

int _intOf(Object? value) => value is num ? value.toInt() : 0;

double _doubleOf(Object? value) => value is num ? value.toDouble() : 0;

List<Map<String, dynamic>> _mapList(Object? value) =>
    value is List
        ? value.whereType<Map<String, dynamic>>().toList(growable: false)
        : const [];

class StudioGrowthPoint {
  const StudioGrowthPoint({
    required this.label,
    required this.followers,
    required this.listeners,
    required this.newFollowers,
  });

  final String label;
  final int followers;
  final int listeners;
  final int newFollowers;
}

class StudioShare {
  const StudioShare({
    required this.label,
    required this.listeners,
    required this.share,
    this.code,
  });

  final String label;
  final String? code;
  final int listeners;
  final double share;
}

class StudioTopListener {
  const StudioTopListener({
    required this.id,
    required this.name,
    required this.episodes,
    required this.completed,
    this.handle,
  });

  final String id;
  final String name;
  final String? handle;
  final int episodes;
  final int completed;

  String get subtitle =>
      '$episodes episode${episodes == 1 ? '' : 's'} · $completed completed';
}

class StudioAudienceInsights {
  const StudioAudienceInsights({
    required this.followers,
    required this.showFollowers,
    required this.listeners,
    required this.plays,
    required this.completions,
    required this.newListeners,
    required this.returningListeners,
    required this.newFollowers,
    required this.growth,
    required this.platforms,
    required this.locations,
    required this.listeningHours,
    required this.listeningWeekdays,
    required this.topListeners,
  });

  factory StudioAudienceInsights.fromApi(Map<String, dynamic> data) {
    String platformLabel(String raw) => switch (raw) {
      'android' => 'Android',
      'ios' => 'iOS',
      'web' => 'Web',
      'macos' => 'macOS',
      'windows' => 'Windows',
      'unknown' || '' => 'Other',
      _ => raw[0].toUpperCase() + raw.substring(1),
    };
    final hours = data['listening_hours'];
    final weekdays = data['listening_weekdays'];
    return StudioAudienceInsights(
      followers: _intOf(data['followers']),
      showFollowers: _intOf(data['show_followers']),
      listeners: _intOf(data['listeners']),
      plays: _intOf(data['plays']),
      completions: _intOf(data['completions']),
      newListeners: _intOf(data['new_listeners']),
      returningListeners: _intOf(data['returning_listeners']),
      newFollowers: _intOf(data['new_followers']),
      growth: [
        for (final row in _mapList(data['growth']))
          StudioGrowthPoint(
            label: '${row['label'] ?? ''}',
            followers: _intOf(row['followers']),
            listeners: _intOf(row['listeners']),
            newFollowers: _intOf(row['new_followers']),
          ),
      ],
      platforms: [
        for (final row in _mapList(data['platforms']))
          StudioShare(
            label: platformLabel('${row['platform'] ?? ''}'),
            listeners: _intOf(row['listeners']),
            share: _doubleOf(row['share']),
          ),
      ],
      locations: [
        for (final row in _mapList(data['top_locations']))
          StudioShare(
            label: '${row['country'] ?? 'Location not shared'}',
            code: row['country_code'] as String?,
            listeners: _intOf(row['listeners']),
            share: _doubleOf(row['share']),
          ),
      ],
      listeningHours:
          hours is List
              ? [for (final value in hours) _intOf(value)]
              : List<int>.filled(24, 0),
      listeningWeekdays:
          weekdays is List
              ? [for (final value in weekdays) _intOf(value)]
              : List<int>.filled(7, 0),
      topListeners: [
        for (final row in _mapList(data['top_listeners']))
          StudioTopListener(
            id: '${row['id']}',
            name: '${row['name'] ?? 'Listener'}',
            handle: row['handle'] as String?,
            episodes: _intOf(row['episodes']),
            completed: _intOf(row['completed']),
          ),
      ],
    );
  }

  final int followers;
  final int showFollowers;
  final int listeners;
  final int plays;
  final int completions;
  final int newListeners;
  final int returningListeners;
  final int newFollowers;
  final List<StudioGrowthPoint> growth;
  final List<StudioShare> platforms;
  final List<StudioShare> locations;
  final List<int> listeningHours;
  final List<int> listeningWeekdays;
  final List<StudioTopListener> topListeners;
}

enum StudioAudiencePeriod {
  week('7d', 'Listeners (7d)'),
  month('30d', 'Listeners (30d)'),
  year('1y', 'Listeners (1y)');

  const StudioAudiencePeriod(this.apiValue, this.listenersLabel);
  final String apiValue;
  final String listenersLabel;
}

enum StudioEarningsPeriodKey {
  thisMonth('this_month', 'This Month'),
  lastMonth('last_month', 'Last Month'),
  thisYear('this_year', 'This Year');

  const StudioEarningsPeriodKey(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class StudioEarningsPoint {
  const StudioEarningsPoint({
    required this.label,
    required this.giftCoins,
    required this.adUsdMicros,
  });

  final String label;
  final int giftCoins;
  final int adUsdMicros;
}

String formatUsdMicros(int micros) {
  final dollars = micros / 1000000;
  if (micros == 0) return '\$0.00 USD';
  return '\$${dollars.toStringAsFixed(dollars >= 1 ? 2 : 4)} USD';
}

class StudioEarningsPeriod {
  const StudioEarningsPeriod({
    required this.giftCount,
    required this.giftCoins,
    required this.adAllocations,
    required this.adRevenueUsdMicros,
    required this.adStatusTotals,
    required this.payoutsCount,
    required this.payoutsAmount,
    required this.series,
    this.payoutsUnit,
  });

  factory StudioEarningsPeriod.fromApi(Map<String, dynamic> data) {
    final statuses = data['ad_status_totals'];
    return StudioEarningsPeriod(
      giftCount: _intOf(data['gift_count']),
      giftCoins: _intOf(data['gift_coins']),
      adAllocations: _intOf(data['ad_allocations']),
      adRevenueUsdMicros: _intOf(data['ad_revenue_usd_micros']),
      adStatusTotals: {
        if (statuses is Map)
          for (final entry in statuses.entries)
            '${entry.key}': _intOf(entry.value),
      },
      payoutsCount: _intOf(data['payouts_count']),
      payoutsAmount: _intOf(data['payouts_amount']),
      payoutsUnit: data['payouts_unit'] as String?,
      series: [
        for (final row in _mapList(data['series']))
          StudioEarningsPoint(
            label: '${row['label'] ?? ''}',
            giftCoins: _intOf(row['gift_coins']),
            adUsdMicros: _intOf(row['ad_usd_micros']),
          ),
      ],
    );
  }

  final int giftCount;
  final int giftCoins;
  final int adAllocations;
  final int adRevenueUsdMicros;
  final Map<String, int> adStatusTotals;
  final int payoutsCount;
  final int payoutsAmount;
  final String? payoutsUnit;
  final List<StudioEarningsPoint> series;

  String get adRevenueLabel => formatUsdMicros(adRevenueUsdMicros);

  bool get hasActivity =>
      giftCount > 0 || adAllocations > 0 || payoutsCount > 0;
}

class StudioAccount {
  const StudioAccount({
    required this.id,
    required this.type,
    required this.unit,
    required this.balance,
  });

  factory StudioAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final unit = json['unit'];
    final balance = json['balance'];
    if (id == null ||
        '$id'.isEmpty ||
        type is! String ||
        type.isEmpty ||
        unit is! String ||
        unit.isEmpty ||
        balance is! num) {
      throw _invalidStudio;
    }
    return StudioAccount(
      id: '$id',
      type: type,
      unit: unit,
      balance: balance.toInt(),
    );
  }

  final String id;
  final String type;
  final String unit;
  final int balance;

  String get balanceLabel {
    if (type.startsWith('reels_ad_') && unit == 'USD') {
      return '\$${(balance / 1000000).toStringAsFixed(4)} USD';
    }
    if (type.startsWith('reels_ad_') && unit == 'NGN') {
      return '₦${(balance / 100).toStringAsFixed(2)} NGN';
    }
    return '$balance $unit';
  }
}

class StudioAdAllocation {
  const StudioAdAllocation({
    required this.id,
    required this.status,
    required this.grossUsdMicros,
    required this.confirmedUsdMicros,
    required this.reserveUsdMicros,
    required this.clawbackUsdMicros,
    required this.availableAmountMinor,
    this.availableCurrency,
    this.heldUntil,
    this.releasedAt,
  });

  factory StudioAdAllocation.fromJson(Map<String, dynamic> json) {
    return StudioAdAllocation(
      id: '${json['id']}',
      status: '${json['status']}',
      grossUsdMicros: (json['gross_usd_micros'] as num?)?.toInt() ?? 0,
      confirmedUsdMicros: (json['confirmed_usd_micros'] as num?)?.toInt() ?? 0,
      reserveUsdMicros: (json['reserve_usd_micros'] as num?)?.toInt() ?? 0,
      clawbackUsdMicros: (json['clawback_usd_micros'] as num?)?.toInt() ?? 0,
      availableCurrency: json['available_currency'] as String?,
      availableAmountMinor:
          (json['available_amount_minor'] as num?)?.toInt() ?? 0,
      heldUntil: json['held_until'] as String?,
      releasedAt: json['released_at'] as String?,
    );
  }

  final String id;
  final String status;
  final int grossUsdMicros;
  final int confirmedUsdMicros;
  final int reserveUsdMicros;
  final int clawbackUsdMicros;
  final String? availableCurrency;
  final int availableAmountMinor;
  final String? heldUntil;
  final String? releasedAt;
}

class StudioCurrencyConversion {
  const StudioCurrencyConversion({
    required this.id,
    required this.sourceAmountMicros,
    required this.destinationAmountKobo,
    required this.grossRate,
    required this.netRate,
    required this.spreadBps,
    required this.rateSource,
    required this.quotedAt,
  });

  factory StudioCurrencyConversion.fromJson(Map<String, dynamic> json) {
    return StudioCurrencyConversion(
      id: '${json['id']}',
      sourceAmountMicros: (json['source_amount_minor'] as num?)?.toInt() ?? 0,
      destinationAmountKobo:
          (json['destination_amount_minor'] as num?)?.toInt() ?? 0,
      grossRate: '${json['gross_rate']}',
      netRate: '${json['net_rate']}',
      spreadBps: (json['spread_bps'] as num?)?.toInt() ?? 0,
      rateSource: '${json['rate_source']}',
      quotedAt: '${json['quoted_at']}',
    );
  }

  final String id;
  final int sourceAmountMicros;
  final int destinationAmountKobo;
  final String grossRate;
  final String netRate;
  final int spreadBps;
  final String rateSource;
  final String quotedAt;
}

class StudioTaxProfile {
  const StudioTaxProfile({
    required this.id,
    required this.countryCode,
    required this.state,
  });

  factory StudioTaxProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final country = json['country_code'];
    final state = json['state'];
    if (id == null ||
        '$id'.isEmpty ||
        country is! String ||
        country.isEmpty ||
        state is! String) {
      throw _invalidStudio;
    }
    return StudioTaxProfile(id: '$id', countryCode: country, state: state);
  }

  final String id;
  final String countryCode;
  final String state;

  bool get added => state.isNotEmpty && state != 'missing';
}

class StudioGiftMoney {
  const StudioGiftMoney({
    required this.balance,
    this.moneyLabel,
    this.usdLabel,
    this.currency,
  });

  factory StudioGiftMoney.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StudioGiftMoney(balance: 0);
    }
    final balance = (json['balance'] as num?)?.toInt() ?? 0;
    final display = json['display'];
    final quotes = json['quotes'];
    final usdQuote = quotes is Map ? quotes['USD'] : null;
    final money =
        display is Map && display['display_available'] is String
            ? display['display_available'] as String
            : usdQuote is Map && usdQuote['gross_minor'] is num
            ? '\$${((usdQuote['gross_minor'] as num) / 100).toStringAsFixed(2)} USD'
            : null;
    return StudioGiftMoney(
      balance: balance,
      moneyLabel: money,
      usdLabel:
          usdQuote is Map && usdQuote['gross_minor'] is num
              ? '\$${((usdQuote['gross_minor'] as num) / 100).toStringAsFixed(2)}'
              : null,
      currency: display is Map ? display['currency'] as String? : null,
    );
  }

  final int balance;
  final String? moneyLabel;
  final String? usdLabel;
  final String? currency;
}

class StudioMonetization {
  const StudioMonetization({
    required this.giftsReceived,
    required this.payoutsCount,
    required this.accounts,
    required this.adAllocations,
    required this.currencyConversions,
    required this.taxProfiles,
    this.gifts = const StudioGiftMoney(balance: 0),
    this.adAvailableUsd,
    this.adAvailableLabel,
  });

  factory StudioMonetization.fromApi(Map<String, dynamic> data) {
    final gifts = data['gifts_received'];
    final payouts = data['payouts_count'];
    final accounts = data['accounts'];
    final allocations = data['ad_revenue_allocations'];
    final conversions = data['currency_conversions'];
    final tax = data['tax_profiles'];
    if (gifts is! num ||
        payouts is! num ||
        accounts is! List ||
        allocations is! List ||
        conversions is! List ||
        tax is! List) {
      throw _invalidStudio;
    }
    final diamonds = data['diamonds'];
    final clearance = data['ad_clearance'];
    return StudioMonetization(
      giftsReceived: gifts.toInt(),
      payoutsCount: payouts.toInt(),
      accounts: accounts
          .whereType<Map<String, dynamic>>()
          .map(StudioAccount.fromJson)
          .toList(growable: false),
      adAllocations: allocations
          .whereType<Map<String, dynamic>>()
          .map(StudioAdAllocation.fromJson)
          .toList(growable: false),
      currencyConversions: conversions
          .whereType<Map<String, dynamic>>()
          .map(StudioCurrencyConversion.fromJson)
          .toList(growable: false),
      taxProfiles: tax
          .whereType<Map<String, dynamic>>()
          .map(StudioTaxProfile.fromJson)
          .toList(growable: false),
      gifts: StudioGiftMoney.fromJson(
        diamonds is Map<String, dynamic> ? diamonds : null,
      ),
      adAvailableUsd:
          clearance is Map ? clearance['available_usd'] as String? ?? clearance['cleared_ad_usd'] as String? : null,
      adAvailableLabel:
          clearance is Map ? clearance['display_available'] as String? : null,
    );
  }

  final int giftsReceived;
  final int payoutsCount;
  final List<StudioAccount> accounts;
  final List<StudioAdAllocation> adAllocations;
  final List<StudioCurrencyConversion> currencyConversions;
  final List<StudioTaxProfile> taxProfiles;
  final StudioGiftMoney gifts;
  final String? adAvailableUsd;
  final String? adAvailableLabel;

  StudioAccount? get primaryBalance {
    for (final account in accounts) {
      if (account.type == 'diamond_wallet') {
        return account;
      }
    }
    for (final account in accounts) {
      if (account.type == 'creator_balance') {
        return account;
      }
    }
    return null;
  }
}

enum StudioTransactionFilter { all, earnings, payouts, gifts, reels }

typedef StudioTransactionQuery =
    ({StudioTransactionFilter filter, StudioEarningsPeriodKey period});

typedef StudioAudienceQuery = ({StudioAudiencePeriod period, String? showId});

class StudioTransaction {
  const StudioTransaction({
    required this.id,
    required this.reference,
    required this.eventType,
    required this.amount,
    required this.unit,
    this.createdAt,
    this.counterpartName,
    this.counterpartHandle,
    this.message,
    this.giftTypeName,
    this.payoutState,
    this.payoutLabel,
    this.payoutLastFour,
  });

  factory StudioTransaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final reference = json['reference'];
    final eventType = json['event_type'];
    final amount = json['amount'];
    final unit = json['unit'];
    if (id == null ||
        '$id'.isEmpty ||
        reference is! String ||
        reference.isEmpty ||
        eventType is! String ||
        eventType.isEmpty ||
        amount is! num ||
        unit is! String ||
        unit.isEmpty) {
      throw _invalidStudio;
    }
    return StudioTransaction(
      id: '$id',
      reference: reference,
      eventType: eventType,
      amount: amount.toInt(),
      unit: unit,
      createdAt: json['created_at'] as String?,
      counterpartName: json['counterpart_name'] as String?,
      counterpartHandle: json['counterpart_handle'] as String?,
      message: json['message'] as String?,
      giftTypeName: json['gift_type_name'] as String?,
      payoutState: json['payout_state'] as String?,
      payoutLabel: json['payout_label'] as String?,
      payoutLastFour: json['payout_last_four'] as String?,
    );
  }

  final String id;
  final String reference;
  final String eventType;
  final int amount;
  final String unit;
  final String? createdAt;
  final String? counterpartName;
  final String? counterpartHandle;
  final String? message;
  final String? giftTypeName;
  final String? payoutState;
  final String? payoutLabel;
  final String? payoutLastFour;

  String get amountLabel {
    final sign = amount > 0 ? '+' : '';
    return '$sign$amount $unit';
  }

  String get createdLabel {
    if (createdAt == null || createdAt!.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(createdAt!);
    if (parsed == null) {
      return createdAt!;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day · $hour:$minute';
  }

  String get title {
    if (eventType == 'gift.sent') {
      final name = counterpartName?.trim();
      return name == null || name.isEmpty ? 'Gift' : 'Gift from $name';
    }
    if (eventType == 'reel.revenue') {
      return 'Reel performance';
    }
    if (eventType.startsWith('creator_payout')) {
      final label = payoutLabel?.trim();
      if (label != null && label.isNotEmpty) {
        return 'Payout to $label';
      }
      final lastFour = payoutLastFour?.trim();
      if (lastFour != null && lastFour.isNotEmpty) {
        return 'Payout •••• $lastFour';
      }
      return 'Payout';
    }
    return eventType;
  }

  String get subtitle {
    if (message != null && message!.trim().isNotEmpty) {
      return message!.trim();
    }
    if (giftTypeName != null && giftTypeName!.trim().isNotEmpty) {
      return giftTypeName!.trim();
    }
    if (payoutState != null && payoutState!.trim().isNotEmpty) {
      return payoutState!.trim();
    }
    return eventType;
  }

  String get typeLabel {
    if (eventType == 'gift.sent') {
      return 'Gift';
    }
    if (eventType == 'reel.revenue') {
      return 'Reel';
    }
    if (eventType.startsWith('creator_payout')) {
      return 'Payout';
    }
    return eventType;
  }
}

class StudioTransactionPage {
  const StudioTransactionPage({
    required this.items,
    this.cursor,
    this.hasMore = false,
  });

  factory StudioTransactionPage.fromEnvelope(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidStudio;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidStudio;
    }
    final meta = body['meta'];
    return StudioTransactionPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(StudioTransaction.fromJson)
          .toList(growable: false),
      cursor: meta is Map ? meta['cursor'] as String? : null,
      hasMore: meta is Map && meta['has_more'] == true,
    );
  }

  final List<StudioTransaction> items;
  final String? cursor;
  final bool hasMore;
}

class StudioPayoutMethod {
  const StudioPayoutMethod({
    required this.id,
    required this.provider,
    required this.kind,
    this.label,
    this.destinationLastFour,
    this.verifiedAt,
    this.proofStatus,
  });

  factory StudioPayoutMethod.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final provider = json['provider'];
    final kind = json['kind'];
    if (id == null ||
        '$id'.isEmpty ||
        provider is! String ||
        provider.isEmpty ||
        kind is! String ||
        kind.isEmpty) {
      throw _invalidStudio;
    }
    return StudioPayoutMethod(
      id: '$id',
      provider: provider,
      kind: kind,
      label: json['label'] as String?,
      destinationLastFour: json['destination_last_four'] as String?,
      verifiedAt: json['verified_at'] as String?,
      proofStatus: json['proof_status'] as String?,
    );
  }

  final String id;
  final String provider;
  final String kind;
  final String? label;
  final String? destinationLastFour;
  final String? verifiedAt;
  final String? proofStatus;

  bool get verified => verifiedAt != null && verifiedAt!.isNotEmpty;

  String get title {
    final value = label?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return switch (provider) {
      'paypal' => 'PayPal',
      'flutterwave' => 'Flutterwave',
      _ => kind == 'paypal' ? 'PayPal' : 'Bank transfer',
    };
  }

  String get subtitle {
    final lastFour = destinationLastFour;
    if (lastFour != null && lastFour.isNotEmpty) {
      return '•••• $lastFour';
    }
    return kind;
  }
}

class StudioPayoutConfig {
  const StudioPayoutConfig({
    this.payoutMethodId,
    this.currency,
    this.adPayoutCurrency,
    this.schedule,
    this.minimumAmount,
    this.complianceState,
  });

  factory StudioPayoutConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StudioPayoutConfig();
    }
    return StudioPayoutConfig(
      payoutMethodId:
          json['payout_method_id'] == null
              ? null
              : '${json['payout_method_id']}',
      currency: json['currency'] as String?,
      adPayoutCurrency: json['ad_payout_currency'] as String?,
      schedule: json['schedule'] as String?,
      minimumAmount: (json['minimum_amount'] as num?)?.toInt(),
      complianceState: json['compliance_state'] as String?,
    );
  }

  final String? payoutMethodId;
  final String? currency;
  final String? adPayoutCurrency;
  final String? schedule;
  final int? minimumAmount;
  final String? complianceState;
}

class StudioPayoutWorkspace {
  const StudioPayoutWorkspace({
    required this.config,
    required this.methods,
    required this.monetization,
    this.taxProfile,
  });

  final StudioPayoutConfig config;
  final List<StudioPayoutMethod> methods;
  final StudioMonetization monetization;
  final StudioTaxProfile? taxProfile;

  StudioPayoutMethod? get selectedMethod {
    final id = config.payoutMethodId;
    if (id == null || id.isEmpty) {
      return methods.isEmpty ? null : methods.first;
    }
    for (final method in methods) {
      if (method.id == id) {
        return method;
      }
    }
    return methods.isEmpty ? null : methods.first;
  }
}

class StudioFollower {
  const StudioFollower({
    required this.id,
    required this.name,
    this.handle,
    this.createdAt,
  });

  factory StudioFollower.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id == null || '$id'.isEmpty || name is! String || name.trim().isEmpty) {
      throw _invalidStudio;
    }
    return StudioFollower(
      id: '$id',
      name: name.trim(),
      handle: json['handle'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  final String id;
  final String name;
  final String? handle;
  final String? createdAt;

  String get handleLabel {
    final value = handle?.trim();
    if (value == null || value.isEmpty) {
      return '';
    }
    return value.startsWith('@') ? value : '@$value';
  }

  String get createdLabel {
    if (createdAt == null || createdAt!.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(createdAt!);
    if (parsed == null) {
      return createdAt!;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }
}

class StudioFollowerPage {
  const StudioFollowerPage({
    required this.items,
    this.cursor,
    this.hasMore = false,
  });

  factory StudioFollowerPage.fromEnvelope(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidStudio;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidStudio;
    }
    final meta = body['meta'];
    return StudioFollowerPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(StudioFollower.fromJson)
          .toList(growable: false),
      cursor: meta is Map ? meta['cursor'] as String? : null,
      hasMore: meta is Map && meta['has_more'] == true,
    );
  }

  final List<StudioFollower> items;
  final String? cursor;
  final bool hasMore;
}

class StudioSupporter {
  const StudioSupporter({
    required this.id,
    required this.name,
    required this.giftsCount,
    required this.coins,
    this.handle,
  });

  factory StudioSupporter.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final gifts = json['gifts_count'];
    final coins = json['coins'];
    if (id == null ||
        '$id'.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        gifts is! num ||
        coins is! num) {
      throw _invalidStudio;
    }
    return StudioSupporter(
      id: '$id',
      name: name.trim(),
      giftsCount: gifts.toInt(),
      coins: coins.toInt(),
      handle: json['handle'] as String?,
    );
  }

  final String id;
  final String name;
  final int giftsCount;
  final int coins;
  final String? handle;

  String get subtitle => '$coins coins · $giftsCount gifts';
}

class StudioSupporterPage {
  const StudioSupporterPage({
    required this.items,
    required this.supportersCount,
    required this.coinsReceived,
    this.cursor,
    this.hasMore = false,
  });

  factory StudioSupporterPage.fromEnvelope(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidStudio;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidStudio;
    }
    final meta = body['meta'];
    final items = data
        .whereType<Map<String, dynamic>>()
        .map(StudioSupporter.fromJson)
        .toList(growable: false);
    final supporters = meta is Map ? meta['supporters_count'] : null;
    final coins = meta is Map ? meta['coins_received'] : null;
    return StudioSupporterPage(
      items: items,
      supportersCount: supporters is num ? supporters.toInt() : items.length,
      coinsReceived:
          coins is num
              ? coins.toInt()
              : items.fold<int>(0, (sum, item) => sum + item.coins),
      cursor: meta is Map ? meta['cursor'] as String? : null,
      hasMore: meta is Map && meta['has_more'] == true,
    );
  }

  final List<StudioSupporter> items;
  final int supportersCount;
  final int coinsReceived;
  final String? cursor;
  final bool hasMore;
}

class StudioLiveSession {
  const StudioLiveSession({
    required this.id,
    required this.title,
    required this.state,
    this.showId,
    this.playbackUrl,
    this.ingestUrl,
    this.streamKey,
    this.commentsEnabled = true,
    this.notifyFollowers = true,
    this.muxReady = false,
    this.muxMessage,
  });

  factory StudioLiveSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final state = json['state'];
    if (id == null ||
        '$id'.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        state is! String ||
        state.isEmpty) {
      throw _invalidStudio;
    }
    return StudioLiveSession(
      id: '$id',
      title: title.trim(),
      state: state,
      showId: json['show_id'] == null ? null : '${json['show_id']}',
      playbackUrl: json['playback_url'] as String?,
      ingestUrl: json['ingest_url'] as String?,
      streamKey: json['stream_key'] as String?,
      commentsEnabled: json['comments_enabled'] != false,
      notifyFollowers: json['notify_followers'] != false,
      muxReady: json['mux_ready'] == true,
      muxMessage: json['mux_message'] as String?,
    );
  }

  final String id;
  final String title;
  final String state;
  final String? showId;
  final String? playbackUrl;
  final String? ingestUrl;
  final String? streamKey;
  final bool commentsEnabled;
  final bool notifyFollowers;
  final bool muxReady;
  final String? muxMessage;
}

class StudioWorkspace {
  const StudioWorkspace({
    required this.profile,
    required this.shows,
    required this.audience,
    required this.episodes,
    required this.teamStudioCount,
  });

  final StudioProfile profile;
  final List<StudioShow> shows;
  final StudioAudience audience;
  final List<StudioEpisode> episodes;
  final int teamStudioCount;

  StudioShow? get primaryShow => shows.isEmpty ? null : shows.first;

  StudioShow? showFor(String? id) {
    if (id != null && id.isNotEmpty) {
      for (final show in shows) {
        if (show.id == id) {
          return show;
        }
      }
    }
    return primaryShow;
  }
}

class StudioRepository {
  const StudioRepository(this._dio);

  final Dio _dio;

  Future<StudioWorkspace> workspace({String? showId}) async {
    try {
      return await _load(showId: showId);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioWorkspace> _load({String? showId}) async {
    final profile = StudioProfile.fromApi(
      requireApiData((await _dio.get<Map<String, dynamic>>('/studio')).data),
    );
    final showsResponse = await _dio.get<Map<String, dynamic>>(
      '/studio/shows',
      queryParameters: {'limit': 12},
    );
    final shows = _maps(showsResponse.data).map(StudioShow.fromJson).toList();
    final target =
        (showId != null && showId.isNotEmpty)
            ? showId
            : (shows.isEmpty ? null : shows.first.id);
    final episodesResponse = await _dio.get<Map<String, dynamic>>(
      '/studio/episodes',
      queryParameters: {'limit': 3, if (target != null) 'show_id': target},
    );
    final audience = StudioAudience.fromApi(
      requireApiData(
        (await _dio.get<Map<String, dynamic>>(
          '/studio/audience',
          queryParameters: {if (target != null) 'show_id': target},
        )).data,
      ),
    );
    final studiosResponse = await _dio.get<Map<String, dynamic>>('/studios');
    return StudioWorkspace(
      profile: profile,
      shows: shows,
      audience: audience,
      episodes:
          _maps(episodesResponse.data).map(StudioEpisode.fromJson).toList(),
      teamStudioCount: _maps(studiosResponse.data).length,
    );
  }

  Future<StudioEpisodePage> episodes({int limit = 50, String? showId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/studio/episodes',
        queryParameters: {
          'limit': limit,
          if (showId != null && showId.isNotEmpty) 'show_id': showId,
        },
      );
      return StudioEpisodePage.fromEnvelope(response.data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioReelPage> reels({
    StudioReelFilter filter = StudioReelFilter.all,
  }) async {
    try {
      final query = <String, dynamic>{'limit': 50};
      if (filter == StudioReelFilter.drafts) {
        query['state'] = 'draft';
      } else if (filter == StudioReelFilter.linked) {
        query['linked'] = 1;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/studio/reels',
        queryParameters: query,
      );
      return StudioReelPage.fromEnvelope(response.data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioReel> reel(String id) async {
    try {
      return StudioReel.fromJson(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/studio/reels/$id')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioReelDraft> saveReelDraft({
    String? title,
    String? caption,
    String? episodeId,
    String? showId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reels/drafts',
        data: {
          if (title != null) 'title': title,
          if (caption != null) 'caption': caption,
          if (episodeId != null) 'episode_id': episodeId,
          if (showId != null) 'show_id': showId,
        },
      );
      return StudioReelDraft.fromApi(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioEpisode> episode(String id) async {
    try {
      return StudioEpisode.fromJson(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/studio/episodes/$id')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioMonetization> monetization() async {
    try {
      return StudioMonetization.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>('/studio/monetization')).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioEarningsPeriod> earnings(StudioEarningsPeriodKey period) async {
    try {
      final data = requireApiData(
        (await _dio.get<Map<String, dynamic>>(
          '/studio/monetization',
          queryParameters: {'period': period.apiValue},
        )).data,
      );
      final block = data['period'];
      return StudioEarningsPeriod.fromApi(
        block is Map<String, dynamic> ? block : const {},
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioAudienceInsights> audienceInsights(
    StudioAudienceQuery query,
  ) async {
    try {
      return StudioAudienceInsights.fromApi(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/studio/audience',
            queryParameters: {
              'period': query.period.apiValue,
              if (query.showId != null && query.showId!.isNotEmpty)
                'show_id': query.showId,
            },
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioTransactionPage> transactions({
    StudioTransactionFilter filter = StudioTransactionFilter.all,
    StudioEarningsPeriodKey? period,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': 50,
        if (period != null) 'period': period.apiValue,
      };
      switch (filter) {
        case StudioTransactionFilter.earnings:
          query['kind'] = 'earnings';
        case StudioTransactionFilter.payouts:
          query['kind'] = 'payouts';
        case StudioTransactionFilter.gifts:
          query['kind'] = 'gifts';
        case StudioTransactionFilter.reels:
          query['kind'] = 'reels';
        case StudioTransactionFilter.all:
          break;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/studio/transactions',
        queryParameters: query,
      );
      return StudioTransactionPage.fromEnvelope(response.data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioTransaction> transaction(String id) async {
    try {
      return StudioTransaction.fromJson(
        requireApiData(
          (await _dio.get<Map<String, dynamic>>(
            '/studio/transactions/$id',
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioPayoutWorkspace> payoutWorkspace() async {
    try {
      final settings = requireApiData(
        (await _dio.get<Map<String, dynamic>>('/studio/payout-settings')).data,
      );
      final methodsResponse = await _dio.get<Map<String, dynamic>>(
        '/payout-methods',
      );
      final tax = settings['tax_profile'];
      return StudioPayoutWorkspace(
        config: StudioPayoutConfig.fromJson(
          settings['settings'] is Map<String, dynamic>
              ? settings['settings'] as Map<String, dynamic>
              : null,
        ),
        methods:
            _maps(
              methodsResponse.data,
            ).map(StudioPayoutMethod.fromJson).toList(),
        monetization: await monetization(),
        taxProfile:
            tax is Map<String, dynamic> ? StudioTaxProfile.fromJson(tax) : null,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioPayoutWorkspace> updatePayoutSettings({
    String? payoutMethodId,
    String? currency,
    String? adPayoutCurrency,
    String? schedule,
    int? minimumAmount,
    String? countryCode,
    Map<String, dynamic>? taxDetails,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (payoutMethodId != null) 'payout_method_id': payoutMethodId,
        if (currency != null) 'currency': currency,
        if (adPayoutCurrency != null) 'ad_payout_currency': adPayoutCurrency,
        if (schedule != null) 'schedule': schedule,
        if (minimumAmount != null) 'minimum_amount': minimumAmount,
        if (countryCode != null) 'country_code': countryCode,
        if (taxDetails != null) 'tax_details': taxDetails,
      };
      await _dio.put<Map<String, dynamic>>(
        '/studio/payout-settings',
        data: payload,
      );
      return payoutWorkspace();
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioEpisode> createEpisodeDraft({
    required String showId,
    required String title,
    String? description,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/studio/episodes',
        data: {
          'show_id': showId,
          'title': title,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      return StudioEpisode.fromJson(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioEpisode> uploadEpisodeAudio({
    required String episodeId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final form = FormData.fromMap({
        'audio': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/studio/episodes/$episodeId/audio',
        data: form,
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );
      return StudioEpisode.fromJson(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioEpisode> publishEpisode({
    required String episodeId,
    DateTime? scheduledAt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/studio/episodes/$episodeId/publish',
        data: {
          if (scheduledAt != null)
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        },
      );
      return StudioEpisode.fromJson(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioLiveSession> startLive({
    required String title,
    String? showId,
    bool notifyFollowers = true,
    bool commentsEnabled = true,
  }) async {
    try {
      final created = requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/studio/live',
          data: {
            'title': title,
            if (showId != null && showId.isNotEmpty) 'show_id': showId,
            'notify_followers': notifyFollowers,
            'comments_enabled': commentsEnabled,
          },
        )).data,
      );
      final id = created['id'];
      if (id == null || '$id'.isEmpty) {
        throw _invalidStudio;
      }
      return StudioLiveSession.fromJson(
        requireApiData(
          (await _dio.patch<Map<String, dynamic>>(
            '/studio/live/$id',
            data: {'state': 'live'},
          )).data,
        ),
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioPayoutMethod> createPayoutMethod({
    required String provider,
    required String kind,
    required Map<String, dynamic> destination,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/payout-methods',
        data: {'provider': provider, 'kind': kind, 'destination': destination},
      );
      return StudioPayoutMethod.fromJson(requireApiData(response.data));
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<void> uploadAccountProof({
    required String payoutMethodId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      requireApiData(
        (await _dio.post<Map<String, dynamic>>(
          '/payout-methods/$payoutMethodId/account-proof',
          data: FormData.fromMap({
            'account_proof': await MultipartFile.fromFile(
              filePath,
              filename: fileName,
            ),
          }),
        )).data,
      );
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioFollowerPage> followers({String? query}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/studio/audience/followers',
        queryParameters: {
          'limit': 50,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      return StudioFollowerPage.fromEnvelope(response.data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  Future<StudioSupporterPage> supporters() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/studio/audience/supporters',
        queryParameters: {'limit': 50},
      );
      return StudioSupporterPage.fromEnvelope(response.data);
    } on ApiFailure {
      rethrow;
    } on DioException catch (error) {
      throw apiFailureFromDio(error);
    }
  }

  List<Map<String, dynamic>> _maps(Map<String, dynamic>? body) {
    if (body == null || body['ok'] != true) {
      throw _invalidStudio;
    }
    final data = body['data'];
    if (data is! List) {
      throw _invalidStudio;
    }
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}

final studioRepositoryProvider = Provider<StudioRepository>(
  (ref) => StudioRepository(ref.watch(dioProvider)),
);

final studioWorkspaceProvider = FutureProvider.autoDispose<StudioWorkspace>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final selected = ref.watch(selectedStudioShowIdProvider);
  return ref.watch(studioRepositoryProvider).workspace(showId: selected);
});

class SelectedStudioShowNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedStudioShowIdProvider =
    NotifierProvider<SelectedStudioShowNotifier, String?>(
      SelectedStudioShowNotifier.new,
    );

StudioShow? selectedStudioShow(WidgetRef ref) {
  final workspace = ref.watch(studioWorkspaceProvider).asData?.value;
  return workspace?.showFor(ref.watch(selectedStudioShowIdProvider));
}

final studioEpisodesProvider = FutureProvider.autoDispose<StudioEpisodePage>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  var showId = ref.watch(selectedStudioShowIdProvider);
  if (showId == null || showId.isEmpty) {
    final workspace = await ref.watch(studioWorkspaceProvider.future);
    showId = workspace.primaryShow?.id;
  }
  return ref.watch(studioRepositoryProvider).episodes(showId: showId);
});

class SelectedStudioEpisodeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedStudioEpisodeIdProvider =
    NotifierProvider<SelectedStudioEpisodeNotifier, String?>(
      SelectedStudioEpisodeNotifier.new,
    );

final studioEpisodeDetailProvider = FutureProvider.autoDispose<StudioEpisode>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final id = ref.watch(selectedStudioEpisodeIdProvider);
  final repository = ref.watch(studioRepositoryProvider);
  if (id != null && id.isNotEmpty) {
    return repository.episode(id);
  }
  var showId = ref.watch(selectedStudioShowIdProvider);
  if (showId == null || showId.isEmpty) {
    final workspace = await ref.watch(studioWorkspaceProvider.future);
    showId = workspace.primaryShow?.id;
  }
  final page = await repository.episodes(limit: 1, showId: showId);
  if (page.items.isEmpty) {
    throw const ApiFailure(
      code: 'NOT_FOUND',
      message: 'No episodes are available yet.',
    );
  }
  return page.items.first;
});

final studioReelsProvider = FutureProvider.autoDispose
    .family<StudioReelPage, StudioReelFilter>((ref, filter) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(studioRepositoryProvider).reels(filter: filter);
    });

class SelectedStudioReelNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedStudioReelIdProvider =
    NotifierProvider<SelectedStudioReelNotifier, String?>(
      SelectedStudioReelNotifier.new,
    );

final studioReelDetailProvider = FutureProvider.autoDispose<StudioReel>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  final id = ref.watch(selectedStudioReelIdProvider);
  final repository = ref.watch(studioRepositoryProvider);
  if (id != null && id.isNotEmpty) {
    return repository.reel(id);
  }
  final page = await repository.reels();
  if (page.items.isEmpty) {
    throw const ApiFailure(
      code: 'NOT_FOUND',
      message: 'No reels are available yet.',
    );
  }
  return page.items.first;
});

final studioMonetizationProvider =
    FutureProvider.autoDispose<StudioMonetization>((ref) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(studioRepositoryProvider).monetization();
    });

final studioTransactionsProvider = FutureProvider.autoDispose
    .family<StudioTransactionPage, StudioTransactionQuery>((ref, query) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref
          .watch(studioRepositoryProvider)
          .transactions(filter: query.filter, period: query.period);
    });

final studioEarningsProvider = FutureProvider.autoDispose
    .family<StudioEarningsPeriod, StudioEarningsPeriodKey>((ref, period) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(studioRepositoryProvider).earnings(period);
    });

final studioAudienceInsightsProvider = FutureProvider.autoDispose
    .family<StudioAudienceInsights, StudioAudienceQuery>((ref, query) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(studioRepositoryProvider).audienceInsights(query);
    });

class SelectedStudioTransactionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedStudioTransactionIdProvider =
    NotifierProvider<SelectedStudioTransactionNotifier, String?>(
      SelectedStudioTransactionNotifier.new,
    );

final studioTransactionDetailProvider =
    FutureProvider.autoDispose<StudioTransaction>((ref) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      final id = ref.watch(selectedStudioTransactionIdProvider);
      final repository = ref.watch(studioRepositoryProvider);
      if (id != null && id.isNotEmpty) {
        return repository.transaction(id);
      }
      final page = await repository.transactions();
      if (page.items.isEmpty) {
        throw const ApiFailure(
          code: 'NOT_FOUND',
          message: 'No transactions are available yet.',
        );
      }
      return page.items.first;
    });

final studioPayoutWorkspaceProvider =
    FutureProvider.autoDispose<StudioPayoutWorkspace>((ref) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(studioRepositoryProvider).payoutWorkspace();
    });

final studioFollowersProvider = FutureProvider.autoDispose<StudioFollowerPage>((
  ref,
) async {
  ref.watch(authSessionProvider.select((session) => session.userId));
  return ref.watch(studioRepositoryProvider).followers();
});

final studioSupportersProvider =
    FutureProvider.autoDispose<StudioSupporterPage>((ref) async {
      ref.watch(authSessionProvider.select((session) => session.userId));
      return ref.watch(studioRepositoryProvider).supporters();
    });
