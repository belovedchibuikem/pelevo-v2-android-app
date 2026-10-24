import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/profile/support_data.dart';

/// Opens the same Terms or Privacy document as the public website.
///
/// Uses the app router so the page is a real route. Back returns to Buy Coins,
/// signup, or whichever screen opened the document.
void openPublicLegalDocument(BuildContext context, CmsDocument document) {
  final path =
      document == CmsDocument.privacy ? '/legal/privacy' : '/legal/terms';
  context.push(path);
}

/// Purchase and signup notice whose links open the public legal pages.
class PelevoPublicLegalNotice extends StatelessWidget {
  const PelevoPublicLegalNotice({
    super.key,
    this.lead = 'By continuing, you agree to the',
    this.linkColor = PelevoColors.purple,
  });

  final String lead;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: context.pelevo.textDim,
      fontSize: 12,
      height: 1.45,
    );
    final link = base.copyWith(
      color: linkColor,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    Widget linkText(String label, CmsDocument document) {
      return GestureDetector(
        onTap: () => openPublicLegalDocument(context, document),
        child: Text(label, style: link),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$lead ', style: base),
        linkText('Terms and Conditions', CmsDocument.terms),
        Text(' and ', style: base),
        linkText('Privacy Policy', CmsDocument.privacy),
        Text('.', style: base),
      ],
    );
  }
}

/// Renders public legal copy, including [label](/terms) links from the website.
class PublicLegalText extends StatefulWidget {
  const PublicLegalText({super.key, required this.text});

  final String text;

  @override
  State<PublicLegalText> createState() => _PublicLegalTextState();
}

class _PublicLegalTextState extends State<PublicLegalText> {
  static final _link = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
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
    final spans = <InlineSpan>[];
    final source = widget.text;
    var cursor = 0;
    for (final match in _link.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }
      final label = match.group(1)!;
      final href = match.group(2)!;
      final document = _documentFor(href);
      if (document == null) {
        spans.add(TextSpan(text: label));
      } else {
        final recognizer =
            TapGestureRecognizer()
              ..onTap = () => openPublicLegalDocument(context, document);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: label,
            style: const TextStyle(
              color: PelevoColors.yellow,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
            recognizer: recognizer,
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(color: context.pelevo.text, height: 1.45),
        children: spans,
      ),
    );
  }

  CmsDocument? _documentFor(String href) {
    final path = href.toLowerCase();
    if (path == '/privacy' || path.endsWith('/legal/privacy')) {
      return CmsDocument.privacy;
    }
    if (path == '/terms' || path.endsWith('/legal/terms')) {
      return CmsDocument.terms;
    }
    return null;
  }
}
