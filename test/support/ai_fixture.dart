import 'catalog_fixture.dart';

const aiJobId = 'ai-job-1';

Map<String, dynamic> aiRecommendationsFixture({
  String id = catalogShowId,
  String title = 'The Honest Bunch',
  String? reason = 'From your listening history',
}) => {
  'version': 1,
  'items': [
    {
      'id': id,
      'show_id': catalogShowId,
      'title': title,
      'reason': reason,
    },
  ],
};

Map<String, dynamic> aiJobFixture({
  String id = aiJobId,
  String type = 'summary',
  String state = 'queued',
  String? outputText,
}) => {
  'id': id,
  'type': type,
  'state': state,
  'output': outputText == null ? null : {'text': outputText},
};
