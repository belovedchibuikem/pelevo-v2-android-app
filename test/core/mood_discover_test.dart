import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/home/mood_discover_screens.dart';

void main() {
  test('money and business uses a short business query and browse slug', () {
    final byLabel = moodDiscoverTargetFor('Money & Business');
    expect(byLabel.query, 'business');
    expect(byLabel.category, 'Business');
    expect(byLabel.browseSlug, 'business');

    final bySlug = moodDiscoverTargetFor('Money & Business', slug: 'business');
    expect(bySlug.query, 'business');
    expect(bySlug.browseSlug, 'business');
  });
}
