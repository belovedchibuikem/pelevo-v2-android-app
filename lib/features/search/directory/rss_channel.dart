import 'package:xml/xml.dart';

class RssEpisode {
  const RssEpisode({
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.description,
    this.artworkUrl,
    this.publishedAt,
    this.durationSeconds,
  });

  final String guid;
  final String title;
  final String audioUrl;
  final String? description;
  final String? artworkUrl;
  final DateTime? publishedAt;
  final int? durationSeconds;
}

class RssChannel {
  const RssChannel({
    required this.title,
    required this.episodes,
    this.author,
    this.description,
    this.artworkUrl,
    this.language,
  });

  final String title;
  final String? author;
  final String? description;
  final String? artworkUrl;
  final String? language;
  final List<RssEpisode> episodes;
}

const _audioExtensions = {
  'mp3',
  'm4a',
  'm4b',
  'aac',
  'ogg',
  'oga',
  'wav',
  'opus',
  'mp4',
};

/// Parses a podcast RSS or Atom document. Items without an audio enclosure
/// are skipped. At most [limit] items are kept, in feed order.
RssChannel parseRssChannel(String raw, {int limit = 40}) {
  final source = _closeTruncatedRss(raw.trim().replaceFirst('\uFEFF', ''));
  final XmlDocument document;
  try {
    document = XmlDocument.parse(source);
  } on XmlException catch (error) {
    throw FormatException('Podcast feed could not be read. ${error.message}');
  }
  final channel =
      _firstLocal(document.descendantElements, const ['channel', 'feed']);
  if (channel == null) {
    throw const FormatException('Podcast feed has no channel.');
  }
  final title = _text(channel, const ['title']);
  if (title == null || title.isEmpty) {
    throw const FormatException('Podcast feed has no title.');
  }
  final episodes = <RssEpisode>[];
  for (final item in channel.childElements) {
    final local = item.name.local.toLowerCase();
    if (local != 'item' && local != 'entry') continue;
    final episode = _episode(item);
    if (episode == null) continue;
    episodes.add(episode);
    if (episodes.length >= limit) break;
  }
  return RssChannel(
    title: title,
    author: _text(channel, const ['author', 'name', 'managingEditor']),
    description: _clip(
      _text(channel, const ['summary', 'description', 'subtitle']),
      1500,
    ),
    artworkUrl: _image(channel),
    language: _text(channel, const ['language']),
    episodes: episodes,
  );
}

RssEpisode? _episode(XmlElement item) {
  final audio = _enclosure(item);
  if (audio == null) return null;
  final guid = _text(item, const ['guid', 'id']) ?? audio;
  final title = _text(item, const ['title']) ?? 'Untitled episode';
  return RssEpisode(
    guid: guid,
    title: title,
    audioUrl: audio,
    description: _clip(
      _text(item, const ['summary', 'description', 'subtitle']),
      500,
    ),
    artworkUrl: _image(item),
    publishedAt: _date(item),
    durationSeconds: _duration(item),
  );
}

String? _enclosure(XmlElement item) {
  for (final node in item.childElements) {
    final local = node.name.local.toLowerCase();
    if (local != 'enclosure' && local != 'link') continue;
    final type = (node.getAttribute('type') ?? '').toLowerCase();
    if (type.startsWith('video/')) continue;
    final href = node.getAttribute('url') ?? node.getAttribute('href');
    if (href == null || href.trim().isEmpty) continue;
    final url = href.trim();
    if (type.startsWith('audio/') || type.isEmpty || _looksLikeAudio(url)) {
      if (local == 'link' && type.isEmpty && !_looksLikeAudio(url)) continue;
      return url;
    }
  }
  return null;
}

bool _looksLikeAudio(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return _audioExtensions.contains(path.substring(dot + 1));
}

String? _image(XmlElement parent) {
  for (final node in parent.childElements) {
    if (node.name.local.toLowerCase() != 'image') continue;
    final href = node.getAttribute('href');
    if (href != null && href.trim().isNotEmpty) return href.trim();
    final nested = _text(node, const ['url']);
    if (nested != null) return nested;
  }
  return null;
}

String? _text(XmlElement parent, List<String> names) {
  final wanted = names.map((name) => name.toLowerCase()).toSet();
  for (final node in parent.childElements) {
    if (!wanted.contains(node.name.local.toLowerCase())) continue;
    final text = _plain(node.innerText);
    if (text.isNotEmpty) return text;
  }
  return null;
}

DateTime? _date(XmlElement item) {
  final raw = _text(item, const ['pubDate', 'published', 'updated', 'date']);
  if (raw == null) return null;
  return parseRssDate(raw);
}

int? _duration(XmlElement item) {
  final raw = _text(item, const ['duration']);
  if (raw == null) return null;
  return parsePodcastDuration(raw);
}

XmlElement? _firstLocal(Iterable<XmlElement> nodes, List<String> names) {
  final wanted = names.map((name) => name.toLowerCase()).toSet();
  for (final node in nodes) {
    if (wanted.contains(node.name.local.toLowerCase())) return node;
  }
  return null;
}

String _plain(String value) {
  final decoded = value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');
  return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _clip(String? value, int max) {
  if (value == null || value.isEmpty) return null;
  if (value.length <= max) return value;
  return value.substring(0, max);
}

String _closeTruncatedRss(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('</rss>') || lower.contains('</feed>')) return raw;
  final item = lower.lastIndexOf('</item>');
  final entry = lower.lastIndexOf('</entry>');
  final end = item > entry ? item : entry;
  if (end < 0) return raw;
  final tag = item > entry ? '</item>' : '</entry>';
  var sliced = raw.substring(0, end + tag.length);
  if (!sliced.toLowerCase().contains('</channel>') &&
      sliced.toLowerCase().contains('<channel')) {
    sliced = '$sliced</channel>';
  }
  if (sliced.toLowerCase().contains('<rss') &&
      !sliced.toLowerCase().contains('</rss>')) {
    sliced = '$sliced</rss>';
  }
  if (sliced.toLowerCase().contains('<feed') &&
      !sliced.toLowerCase().contains('</feed>')) {
    sliced = '$sliced</feed>';
  }
  return sliced;
}

DateTime? parseRssDate(String raw) {
  final direct = DateTime.tryParse(raw.trim());
  if (direct != null) return direct.toUtc();
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final match = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(raw);
  if (match == null) return null;
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  final day = int.parse(match.group(1)!);
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6) ?? '0');
  return DateTime.utc(year, month, day, hour, minute, second);
}

int? parsePodcastDuration(String raw) {
  final text = raw.trim();
  if (RegExp(r'^\d+$').hasMatch(text)) {
    final seconds = int.parse(text);
    return seconds >= 0 ? seconds : null;
  }
  final parts = text.split(':').map((part) => int.tryParse(part.trim())).toList();
  if (parts.isEmpty || parts.any((part) => part == null || part < 0)) return null;
  if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
  if (parts.length == 3) return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
  return null;
}
