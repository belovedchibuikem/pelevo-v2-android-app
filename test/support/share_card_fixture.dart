import 'package:pelevo/features/share_cards/share_card_data.dart';
import 'catalog_fixture.dart';

const shareCardTemplateId = 'share-template-1';
const shareCardId = 'share-card-1';
const shareCardUrl = 'https://api.invalid/s/test-token';

class CatalogHarnessShareCardId extends SelectedShareCardIdNotifier {
  @override
  String? build() => shareCardId;
}

Map<String, dynamic> shareCardTemplateFixture({
  String id = shareCardTemplateId,
  String name = 'Pelevo Standard',
  int version = 1,
}) => {'id': id, 'name': name, 'version': version};

Map<String, dynamic> shareCardFixture({
  String id = shareCardId,
  String templateId = shareCardTemplateId,
  String templateName = 'Pelevo Standard',
  String subjectType = 'episode',
  String subjectId = catalogEpisodeId,
  String state = 'ready',
  String createdAt = '2026-09-10T12:00:00Z',
  String? scheduledAt,
  String url = shareCardUrl,
  String variant = 'qr',
  String quote = 'Ep. 124 - The Shift Life',
  String layout = 'portrait',
}) => {
  'id': id,
  'template_id': templateId,
  'template_name': templateName,
  'subject_type': subjectType,
  'subject_id': subjectId,
  'state': state,
  'created_at': createdAt,
  'scheduled_at': scheduledAt,
  'url': url,
  'variant': variant,
  'quote': quote,
  'layout': layout,
};

Map<String, dynamic> shareCardEventFixture({
  String event = 'share',
  String? channel = 'link',
  String createdAt = '2026-09-10T12:05:00Z',
}) => {'event': event, 'channel': channel, 'created_at': createdAt};

Map<String, dynamic> shareCardDetailFixture({
  String id = shareCardId,
  List<Map<String, dynamic>>? events,
}) => {
  ...shareCardFixture(id: id),
  'events': events ?? const <Map<String, dynamic>>[],
};
