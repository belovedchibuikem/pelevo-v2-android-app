// Published content fixtures are isolated to the test transport.
Map<String, dynamic> cmsFixture(String slug) => {
  'id': 'test-cms-$slug',
  'slug': slug,
  'title': 'CMS $slug',
  'body': 'Content supplied by the API.',
  'intro':
      slug == 'guidelines'
          ? 'Use high contrast colors for clarity.'
          : 'Content supplied by the API.',
  'body_format': 'plain_text',
  'version': 2,
  'published_at': '2026-09-01T00:00:00Z',
  'sections':
      slug == 'help'
          ? [
            {
              'title': 'How do earnings work?',
              'body': 'The server provides the current published answer.',
            },
          ]
          : slug == 'guidelines'
          ? [
            {
              'title': 'Keep text short',
              'body': 'Keep captions brief and impactful.',
            },
            {
              'title': 'Use QR codes',
              'body': 'Encode the share link so listeners can open the episode.',
            },
          ]
          : [],
};
