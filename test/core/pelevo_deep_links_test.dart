import 'package:flutter_test/flutter_test.dart';
import 'package:pelevo/core/deep_links/pelevo_deep_links.dart';

void main() {
  test('creator profile links open the public profile', () async {
    expect(
      await PelevoDeepLinks.locationFor(
        Uri.parse('https://pelevo.com/creators/creator-1'),
      ),
      '/creators/creator-1',
    );
    expect(
      await PelevoDeepLinks.locationFor(
        Uri.parse('pelevo://creator/creator-1'),
      ),
      '/creators/creator-1',
    );
    expect(
      await PelevoDeepLinks.locationFor(
        Uri.parse('https://pelevo.com/creator/ada_creator'),
      ),
      '/creators/ada_creator',
    );
    expect(
      PelevoDeepLinks.routeLocation(Uri.parse('pelevo://playlist/playlist-1')),
      '/playlists/playlist-1',
    );
    expect(
      PelevoDeepLinks.routeLocation(Uri.parse('pelevo://reel/reel-1')),
      '/reels/reel-1',
    );
    expect(
      PelevoDeepLinks.routeLocation(Uri.parse('pelevo://episode/episode-1')),
      '/episodes/episode-1',
    );
  });
}
