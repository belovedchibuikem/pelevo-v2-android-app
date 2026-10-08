Map<String, dynamic> browseCategoryFixture({
  String id = '1',
  String name = 'Technology',
  String slug = 'technology',
}) => {'id': id, 'name': name, 'slug': slug};

List<Map<String, dynamic>> browseCategoriesFixture() => [
  browseCategoryFixture(),
  browseCategoryFixture(id: '2', name: 'Music', slug: 'music'),
];

Map<String, dynamic> browseShowFixture({
  String id = 'show-1',
  String title = 'Owned Show',
  String? author = 'Ada',
}) => {
  'id': id,
  'title': title,
  'author': author,
  'artwork_url': null,
};

Map<String, dynamic> browseCategoryPageFixture({
  String id = '1',
  String name = 'Technology',
  String slug = 'technology',
  List<Map<String, dynamic>>? shows,
}) => {
  'category': browseCategoryFixture(id: id, name: name, slug: slug),
  'shows': shows ?? [browseShowFixture()],
};
