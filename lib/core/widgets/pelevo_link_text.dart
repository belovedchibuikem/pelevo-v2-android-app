import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlPattern = RegExp(
  r'''(?:https?:\/\/|www\.)[^\s<>]+''',
  caseSensitive: false,
);

final _trailingPunctuation = RegExp(r'''[.,;:!?)\]]+$''');

class PelevoTextRun {
  const PelevoTextRun(this.text, {this.url});

  final String text;
  final Uri? url;
}

/// Splits [text] into plain runs and tappable http(s) / www links.
List<PelevoTextRun> pelevoLinkRuns(String text) {
  final runs = <PelevoTextRun>[];
  var cursor = 0;
  for (final match in _urlPattern.allMatches(text)) {
    if (match.start > cursor) {
      runs.add(PelevoTextRun(text.substring(cursor, match.start)));
    }
    final raw = match.group(0)!;
    final trimmed = raw.replaceFirst(_trailingPunctuation, '');
    final suffix = raw.substring(trimmed.length);
    final uri = pelevoLinkUri(trimmed);
    if (uri == null) {
      runs.add(PelevoTextRun(raw));
    } else {
      runs.add(PelevoTextRun(trimmed, url: uri));
      if (suffix.isNotEmpty) runs.add(PelevoTextRun(suffix));
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    runs.add(PelevoTextRun(text.substring(cursor)));
  }
  if (runs.isEmpty) runs.add(PelevoTextRun(text));
  return runs;
}

Uri? pelevoLinkUri(String value) {
  final withScheme =
      value.toLowerCase().startsWith('www.') ? 'https://$value' : value;
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

Future<bool> openPelevoExternalLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Bio and other posted copy, with http(s) and www links the reader can open.
class PelevoLinkedText extends StatefulWidget {
  const PelevoLinkedText(
    this.text, {
    super.key,
    this.style,
    this.linkColor = PelevoColors.green,
    this.openLink,
  });

  final String text;
  final TextStyle? style;
  final Color linkColor;
  final Future<bool> Function(Uri uri)? openLink;

  @override
  State<PelevoLinkedText> createState() => _PelevoLinkedTextState();
}

class _PelevoLinkedTextState extends State<PelevoLinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _releaseRecognizers();
    super.dispose();
  }

  void _releaseRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _releaseRecognizers();
    final base =
        widget.style ??
        DefaultTextStyle.of(context).style.copyWith(height: 1.4);
    final linkStyle = base.copyWith(
      color: widget.linkColor,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor,
    );
    final spans = <InlineSpan>[];
    for (final run in pelevoLinkRuns(widget.text)) {
      final uri = run.url;
      if (uri == null) {
        spans.add(TextSpan(text: run.text));
        continue;
      }
      final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: run.text, style: linkStyle, recognizer: recognizer),
      );
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }

  Future<void> _open(Uri uri) async {
    final opener = widget.openLink ?? openPelevoExternalLink;
    try {
      final opened = await opener(uri);
      if (!opened && mounted) {
        context.showPelevoMessage('Could not open that link.');
      }
    } on Object {
      if (!mounted) return;
      context.showPelevoMessage('Could not open that link.');
    }
  }
}
