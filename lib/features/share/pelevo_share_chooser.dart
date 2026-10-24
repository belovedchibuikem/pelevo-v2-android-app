import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';
import 'package:pelevo/features/share_cards/share_card_data.dart';
import 'package:url_launcher/url_launcher.dart';

/// The share chooser: system share, copy link, share card, or a specific app.
class PelevoShareChooser extends StatelessWidget {
  const PelevoShareChooser({
    super.key,
    required this.title,
    required this.link,
    required this.onShareCard,
    required this.onCancel,
    this.subtitle,
    this.artworkUrl,
    this.assetPath = 'assets/player/player_thumb.png',
    this.shareTitle,
  });

  final String title;
  final String? subtitle;
  final String? artworkUrl;
  final String assetPath;
  final String link;
  final String? shareTitle;
  final VoidCallback onShareCard;
  final VoidCallback onCancel;

  String get _message {
    final label = (shareTitle ?? title).trim();
    if (label.isEmpty) return link;
    return '$label\n$link';
  }

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, IconData icon, Color color, VoidCallback onTap})>[
      (
        label: 'Share',
        icon: Icons.share_rounded,
        color: PelevoColors.blue,
        onTap: () => _systemShare(context),
      ),
      (
        label: 'Copy Link',
        icon: Icons.link_rounded,
        color: PelevoColors.orange,
        onTap: () => _copy(context),
      ),
      (
        label: 'Share Card',
        icon: Icons.image_outlined,
        color: PelevoColors.purple,
        onTap: onShareCard,
      ),
      (
        label: 'WhatsApp',
        icon: Icons.chat_rounded,
        color: PelevoColors.green,
        onTap: () => _openApp(
          context,
          Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_message)}'),
        ),
      ),
      (
        label: 'Messages',
        icon: Icons.sms_rounded,
        color: PelevoColors.yellow,
        onTap: () => _openApp(
          context,
          Uri(scheme: 'sms', queryParameters: {'body': _message}),
        ),
      ),
      (
        label: 'More',
        icon: Icons.more_horiz_rounded,
        color: context.pelevo.textMuted,
        onTap: () => _systemShare(context, text: _message),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: context.pelevo.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        Card(
          color: context.pelevo.surface,
          child: ListTile(
            leading: CatalogArtwork(
              url: artworkUrl,
              width: 52,
              height: 52,
              assetPath: assetPath,
            ),
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: subtitle == null || subtitle!.trim().isEmpty
                ? null
                : Text(subtitle!),
          ),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: PelevoSpacing.md,
          runSpacing: PelevoSpacing.lg,
          children: [
            for (final action in actions)
              SizedBox(
                width: 76,
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(action.icon, color: action.color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: PelevoColors.red,
            side: const BorderSide(color: PelevoColors.red, width: 1.4),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _systemShare(BuildContext context, {String? text}) async {
    try {
      if (text == null) {
        await pelevoShareEpisodeLink(
          context: context,
          url: link,
          title: shareTitle ?? title,
        );
      } else {
        await pelevoShare(
          context: context,
          text: text,
          title: shareTitle ?? title,
          subject: shareTitle ?? title,
        );
      }
    } on Object {
      if (context.mounted) {
        context.showPelevoMessage('Sharing is not available on this device.');
      }
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    context.showPelevoMessage('Link copied');
  }

  Future<void> _openApp(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !context.mounted) return;
    } on Object {
      // Fall through to the system share sheet.
    }
    if (!context.mounted) return;
    await _systemShare(context, text: _message);
  }
}

void openPelevoShareCard(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required String id,
  required String title,
  String? subtitle,
  String? artworkUrl,
  String? showId,
}) {
  ref.read(selectedShareSubjectProvider.notifier).select(
    ShareCardSubject(
      type: type,
      id: id,
      title: title,
      subtitle: subtitle,
      artworkUrl: artworkUrl,
      showId: showId,
    ),
  );
  context.go('/screen/share-card-preview');
}

Future<void> showPelevoShareChooser({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String link,
  required String subjectType,
  required String subjectId,
  String? subtitle,
  String? artworkUrl,
  String? assetPath,
  String? showId,
  String? shareTitle,
}) {
  return showPelevoSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: PelevoShareChooser(
        title: title,
        subtitle: subtitle,
        artworkUrl: artworkUrl,
        assetPath: assetPath ?? 'assets/player/player_thumb.png',
        link: link,
        shareTitle: shareTitle ?? title,
        onShareCard: () {
          Navigator.pop(sheetContext);
          if (!context.mounted) return;
          openPelevoShareCard(
            context,
            ref,
            type: subjectType,
            id: subjectId,
            title: title,
            subtitle: subtitle,
            artworkUrl: artworkUrl,
            showId: showId,
          );
        },
        onCancel: () => Navigator.pop(sheetContext),
      ),
    ),
  );
}
