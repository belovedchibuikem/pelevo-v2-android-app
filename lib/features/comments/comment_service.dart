import 'package:flutter/foundation.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CommentTargetType { episode, reel }

enum CommentSort { newest, top, creator }

class CommentTarget {
  const CommentTarget(this.type, this.id);

  const CommentTarget.episode(this.id) : type = CommentTargetType.episode;
  const CommentTarget.reel(this.id) : type = CommentTargetType.reel;

  final CommentTargetType type;
  final String id;

  String get key => '${type.name}:$id';

  static const episode124 = CommentTarget.episode('episode-124');
  static const episode42 = CommentTarget.episode('episode-42');
  static const episodeEmpty = CommentTarget.episode('episode-empty');
  static const reelJay = CommentTarget.reel('reel-jay');
}

class PelevoComment {
  PelevoComment({
    required this.id,
    required this.targetKey,
    required this.authorName,
    required this.authorHandle,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.likedByMe = false,
    this.isCreator = false,
    this.isMine = false,
    this.hidden = false,
    this.pinned = false,
    this.repliesCount = 0,
    this.editedAt,
  });

  final String id;
  final String targetKey;
  final String? parentId;
  final String authorName;
  final String authorHandle;
  String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  int likeCount;
  bool likedByMe;
  final bool isCreator;
  final bool isMine;
  bool hidden;
  bool pinned;
  int repliesCount;

  String get initials => authorName.isEmpty ? '?' : authorName[0].toUpperCase();

  String get handleLabel {
    if (authorHandle.isEmpty) return '';
    return authorHandle.startsWith('@') ? authorHandle : '@$authorHandle';
  }

  String get relativeTime {
    final delta = DateTime.now().difference(createdAt);
    if (delta.inSeconds < 45) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    if (delta.inDays < 7) return '${delta.inDays}d';
    return '${createdAt.month}/${createdAt.day}';
  }

  bool get canEdit =>
      isMine &&
      DateTime.now().difference(createdAt) < const Duration(minutes: 15);

  PelevoComment copyWith({
    String? body,
    int? likeCount,
    bool? likedByMe,
    bool? hidden,
    bool? pinned,
    int? repliesCount,
    DateTime? editedAt,
  }) => PelevoComment(
    id: id,
    targetKey: targetKey,
    parentId: parentId,
    authorName: authorName,
    authorHandle: authorHandle,
    body: body ?? this.body,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    isCreator: isCreator,
    isMine: isMine,
    hidden: hidden ?? this.hidden,
    pinned: pinned ?? this.pinned,
    repliesCount: repliesCount ?? this.repliesCount,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'targetKey': targetKey,
    'parentId': parentId,
    'authorName': authorName,
    'authorHandle': authorHandle,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'likeCount': likeCount,
    'likedByMe': likedByMe,
    'isCreator': isCreator,
    'isMine': isMine,
    'hidden': hidden,
    'pinned': pinned,
    'repliesCount': repliesCount,
  };

  factory PelevoComment.fromJson(Map<String, Object?> json) => PelevoComment(
    id: json['id']! as String,
    targetKey: json['targetKey']! as String,
    parentId: json['parentId'] as String?,
    authorName: json['authorName']! as String,
    authorHandle: json['authorHandle']! as String,
    body: json['body']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    likeCount: json['likeCount'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    isCreator: json['isCreator'] as bool? ?? false,
    isMine: json['isMine'] as bool? ?? false,
    hidden: json['hidden'] as bool? ?? false,
    pinned: json['pinned'] as bool? ?? false,
    repliesCount: json['repliesCount'] as int? ?? 0,
  );
}

class CommentService extends ChangeNotifier {
  CommentService._() {
    _seed();
  }

  static final instance = CommentService._();

  static const _prefsKey = 'pelevo_user_comments';
  static const maxLength = 400;

  SharedPreferences? _preferences;
  final Map<String, int> _baseCounts = {};
  final List<PelevoComment> _comments = [];
  PelevoComment? reporting;
  PelevoComment? focused;

  List<PelevoComment> get comments => List.unmodifiable(_comments);

  Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    notifyListeners();
  }

  void _seed() {
    _comments.clear();
    _baseCounts
      ..clear()
      ..addAll({
        CommentTarget.episode124.key: 128,
        CommentTarget.episode42.key: 346,
        CommentTarget.reelJay.key: 346,
        CommentTarget.reel('reel-chude').key: 212,
        CommentTarget.reel('reel-tolu').key: 128,
      });

    _addSeed(
      CommentTarget.episode124,
      id: 'ep124-1',
      name: 'Kemi',
      handle: '@kemi',
      body: 'This episode landed at the right time. Saving it for later.',
      hoursAgo: 2,
      likes: 18,
    );
    _addSeed(
      CommentTarget.episode124,
      id: 'ep124-2',
      name: 'Tomi',
      handle: '@tomi',
      body: 'The part about starting again really stayed with me.',
      hoursAgo: 6,
      likes: 9,
    );
    _addSeed(
      CommentTarget.episode124,
      id: 'ep124-1r',
      name: 'Adesola Adeyemi',
      handle: '@adesola_podcaster',
      body: 'Glad it helped. That chapter is the heart of the episode.',
      hoursAgo: 1,
      likes: 7,
      parentId: 'ep124-1',
      creator: true,
    );

    _addSeed(
      CommentTarget.episode42,
      id: 'ep42-1',
      name: 'BlessedP',
      handle: '@blessedp',
      body:
          'This episode really hit deep. The story about forgiveness is beautiful.',
      hoursAgo: 2,
      likes: 24,
    );
    _addSeed(
      CommentTarget.episode42,
      id: 'ep42-2',
      name: 'Ada_king',
      handle: '@ada_king',
      body: 'Thank you for sharing this. I needed to hear this today.',
      hoursAgo: 5,
      likes: 18,
    );
    _addSeed(
      CommentTarget.episode42,
      id: 'ep42-3',
      name: 'TosinTalks',
      handle: '@tosintalks',
      body: 'Great conversation! More like this please.',
      hoursAgo: 26,
      likes: 12,
    );

    _addSeed(
      CommentTarget.reelJay,
      id: 'reel-jay-1',
      name: 'Adesola',
      handle: '@adesola_podlistener',
      body: 'This hit hard. Saving this for morning motivation.',
      hoursAgo: 2,
      likes: 41,
    );
    _addSeed(
      CommentTarget.reelJay,
      id: 'reel-jay-2',
      name: 'Kemi',
      handle: '@kemi',
      body: 'More of this energy on Pelevo Reels!',
      hoursAgo: 5,
      likes: 22,
    );
    _addSeed(
      CommentTarget.reelJay,
      id: 'reel-jay-3',
      name: 'Tomi',
      handle: '@tomi',
      body: 'Shared with my group chat already.',
      hoursAgo: 26,
      likes: 11,
    );
    _addSeed(
      CommentTarget.reel('reel-chude'),
      id: 'reel-chude-1',
      name: 'Ngozi',
      handle: '@ngozi',
      body: 'Chude always asks the question I was thinking.',
      hoursAgo: 4,
      likes: 14,
    );
  }

  void _addSeed(
    CommentTarget target, {
    required String id,
    required String name,
    required String handle,
    required String body,
    required int hoursAgo,
    required int likes,
    String? parentId,
    bool creator = false,
  }) {
    _comments.add(
      PelevoComment(
        id: id,
        targetKey: target.key,
        parentId: parentId,
        authorName: name,
        authorHandle: handle,
        body: body,
        createdAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
        likeCount: likes,
        isCreator: creator,
      ),
    );
  }

  int displayCount(CommentTarget target) {
    final extras =
        _comments
            .where(
              (comment) => comment.targetKey == target.key && comment.isMine,
            )
            .where((comment) => !comment.hidden)
            .length;
    return (_baseCounts[target.key] ?? visibleCount(target)) + extras;
  }

  int visibleCount(CommentTarget target) => visibleComments(target).length;

  List<PelevoComment> visibleComments(
    CommentTarget target, {
    bool creatorView = false,
  }) {
    return _comments
        .where((comment) => comment.targetKey == target.key)
        .where((comment) => creatorView || !comment.hidden)
        .toList();
  }

  List<PelevoComment> topLevel(
    CommentTarget target, {
    CommentSort sort = CommentSort.newest,
    bool creatorView = false,
  }) {
    final items =
        visibleComments(
          target,
          creatorView: creatorView,
        ).where((comment) => comment.parentId == null).toList();
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      switch (sort) {
        case CommentSort.top:
          return b.likeCount.compareTo(a.likeCount);
        case CommentSort.creator:
          if (a.isCreator != b.isCreator) return a.isCreator ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        case CommentSort.newest:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return items;
  }

  List<PelevoComment> replies(String parentId, {bool creatorView = false}) {
    return _comments
        .where((comment) => comment.parentId == parentId)
        .where((comment) => creatorView || !comment.hidden)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  PelevoComment? byId(String id) =>
      _comments.where((comment) => comment.id == id).firstOrNull;

  PelevoComment? post({
    required CommentTarget target,
    required String body,
    String? parentId,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) return null;
    if (parentId != null && byId(parentId) == null) return null;

    final claimed = PodcastCreatorService.instance.claimed;
    final comment = PelevoComment(
      id: 'c-${DateTime.now().microsecondsSinceEpoch}',
      targetKey: target.key,
      parentId: parentId,
      authorName: 'Adesola Adeyemi',
      authorHandle: claimed ? '@adesola_podcaster' : '@adesola_podlistener',
      body: trimmed,
      createdAt: DateTime.now(),
      isCreator: claimed,
      isMine: true,
    );
    _comments.add(comment);
    _persist();
    notifyListeners();
    return comment;
  }

  void toggleLike(String id) {
    final comment = byId(id);
    if (comment == null) return;
    comment.likedByMe = !comment.likedByMe;
    comment.likeCount += comment.likedByMe ? 1 : -1;
    notifyListeners();
  }

  bool edit(String id, String body) {
    final comment = byId(id);
    final trimmed = body.trim();
    if (comment == null || !comment.canEdit || trimmed.isEmpty) return false;
    comment.body = trimmed;
    _persist();
    notifyListeners();
    return true;
  }

  void delete(String id) {
    _comments.removeWhere(
      (comment) => comment.id == id || comment.parentId == id,
    );
    _persist();
    notifyListeners();
  }

  void toggleHidden(String id) {
    final comment = byId(id);
    if (comment == null) return;
    comment.hidden = !comment.hidden;
    notifyListeners();
  }

  void togglePinned(String id) {
    final comment = byId(id);
    if (comment == null || comment.parentId != null) return;
    final pinning = !comment.pinned;
    for (final item in _comments.where(
      (item) => item.targetKey == comment.targetKey,
    )) {
      item.pinned = pinning && item.id == id;
    }
    notifyListeners();
  }

  void startReport(PelevoComment comment) {
    reporting = comment;
    notifyListeners();
  }

  void focus(PelevoComment comment) {
    focused = comment;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    reporting = null;
    focused = null;
    _seed();
    notifyListeners();
  }

  void _persist() {
    final mine = _comments.where((comment) => comment.isMine).toList();
    _preferences?.setStringList(
      _prefsKey,
      mine.map((comment) => comment.id).toList(),
    );
  }
}
