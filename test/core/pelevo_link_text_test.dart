import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/widgets/pelevo_link_text.dart';

void main() {
  test('bio text keeps wording and marks http links', () {
    const bio = 'follow my YouTube link here\nhttps://pelevo.com/';
    final runs = pelevoLinkRuns(bio);
    expect(runs.map((run) => run.text).join(), bio);
    expect(
      runs.where((run) => run.url != null).single.url,
      Uri.parse('https://pelevo.com/'),
    );
    expect(
      pelevoLinkUri('www.youtube.com/watch'),
      Uri.parse('https://www.youtube.com/watch'),
    );
  });

  testWidgets('a posted bio link can be tapped', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PelevoLinkedText(
            'https://pelevo.com/',
            openLink: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('https://pelevo.com/'));
    await tester.pump();
    expect(opened, Uri.parse('https://pelevo.com/'));
  });
}
