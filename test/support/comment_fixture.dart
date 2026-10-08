Map<String, dynamic> commentFixture({
  String id = 'comment-1',
  String body = 'This episode is worth a second listen.',
  String authorName = 'Listener Ada',
  String authorHandle = 'ada_listener',
  String? parentId,
  int likeCount = 2,
  bool likedByMe = false,
  bool isMine = false,
  bool isCreator = false,
  bool isPinned = false,
  int repliesCount = 0,
}) => {
  'id': id,
  'body': body,
  'created_at': '2026-09-10T00:00:00Z',
  'edited_at': null,
  'parent_id': parentId,
  'is_pinned': isPinned,
  'author_name': authorName,
  'author_handle': authorHandle,
  'like_count': likeCount,
  'liked_by_me': likedByMe,
  'is_mine': isMine,
  'is_creator': isCreator,
  'replies_count': repliesCount,
};

List<Map<String, dynamic>> episodeCommentsFixture() => [
  commentFixture(repliesCount: 1),
  commentFixture(
    id: 'comment-2',
    parentId: 'comment-1',
    body: 'Same here.',
    authorName: 'Jay',
    authorHandle: 'jay',
  ),
];

List<Map<String, dynamic>> reelCommentsFixture() => [
  commentFixture(
    id: 'reel-comment-1',
    body: 'This reel is worth saving.',
    authorName: 'Listener Ada',
    authorHandle: 'ada_listener',
    likeCount: 4,
  ),
];
