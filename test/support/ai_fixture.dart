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

Map<String, dynamic> aiAskFixture({
  String reply =
      'You asked for a show that fits your listening. These picks use that request and your history.',
}) => {
  'reply': reply,
  'items': [
    {
      'id': catalogShowId,
      'type': 'show',
      'title': 'The Honest Bunch',
      'show_id': catalogShowId,
      'show_title': 'The Honest Bunch',
      'reason': 'Worth listening to because it matches what you asked for.',
    },
  ],
};

Map<String, dynamic> aiLineupFixture() => {
  'title': 'Your Podcast Lineup',
  'week_label': 'Week of 13 October',
  'intro':
      'A personalised weekly audio guide. Each show includes why it is worth your time.',
  'items': [
    {
      'id': catalogShowId,
      'type': 'show',
      'title': 'The Honest Bunch',
      'show_id': catalogShowId,
      'reason': 'Worth listening to because it sits close to your recent plays.',
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
