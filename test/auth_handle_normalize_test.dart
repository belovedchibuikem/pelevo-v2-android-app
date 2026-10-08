import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/features/authentication/auth_session.dart';

void main() {
  test('normalizeHandle strips @, spaces, and lowercases', () {
    expect(normalizeHandle('@ beloved'), 'beloved');
    expect(normalizeHandle('  @Beloved_1 '), 'beloved_1');
    expect(normalizeHandle(''), null);
    expect(normalizeHandle('   '), null);
    expect(normalizeHandle(null), null);
  });
}
