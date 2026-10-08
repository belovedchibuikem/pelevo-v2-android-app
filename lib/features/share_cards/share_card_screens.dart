import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/library/library_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'package:pelevo/features/profile/support_data.dart';
import 'package:pelevo/features/share/pelevo_native_share.dart';
import 'package:pelevo/features/share_cards/share_card_data.dart';
import 'package:pelevo/features/share_cards/share_card_export.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';
import 'package:pelevo/features/stats/stats_data.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum _CardView {
  home,
  content,
  template,
  customize,
  preview,
  share,
  cards,
  qr,
  quote,
  minimal,
  show,
  playlist,
  stats,
  backgrounds,
  text,
  branding,
  scheduled,
  analytics,
  topCards,
  download,
  saved,
  export,
  guidelines,
}

const _inventory = <({String id, String title, String state, _CardView view})>[
  (
    id: 'share-card-home',
    title: 'Share Cards',
    state: 'Create and manage cards',
    view: _CardView.home,
  ),
  (
    id: 'share-card-content',
    title: 'Choose Content',
    state: 'Episodes, shows, playlists',
    view: _CardView.content,
  ),
  (
    id: 'share-card-template',
    title: 'Choose Template',
    state: 'Template gallery',
    view: _CardView.template,
  ),
  (
    id: 'share-card-customize',
    title: 'Customize Card',
    state: 'Visual editor',
    view: _CardView.customize,
  ),
  (
    id: 'share-card-preview',
    title: 'Preview Card',
    state: 'Final preview',
    view: _CardView.preview,
  ),
  (
    id: 'share-card-share-options',
    title: 'Share Options',
    state: 'Destinations',
    view: _CardView.share,
  ),
  (
    id: 'share-card-my-cards',
    title: 'My Share Cards',
    state: 'Cards and actions',
    view: _CardView.cards,
  ),
  (
    id: 'share-card-qr',
    title: 'QR Code Card',
    state: 'Scannable card',
    view: _CardView.qr,
  ),
  (
    id: 'share-card-quote',
    title: 'Quote Card',
    state: 'Quote template',
    view: _CardView.quote,
  ),
  (
    id: 'share-card-minimal',
    title: 'Minimal Card',
    state: 'Minimal template',
    view: _CardView.minimal,
  ),
  (
    id: 'share-card-show',
    title: 'Show Card',
    state: 'Podcast promotion',
    view: _CardView.show,
  ),
  (
    id: 'share-card-playlist',
    title: 'Playlist Card',
    state: 'Playlist promotion',
    view: _CardView.playlist,
  ),
  (
    id: 'share-card-stats',
    title: 'Stats Card',
    state: 'Listening milestone',
    view: _CardView.stats,
  ),
  (
    id: 'share-card-backgrounds',
    title: 'Card Backgrounds',
    state: 'Background picker',
    view: _CardView.backgrounds,
  ),
  (
    id: 'share-card-text',
    title: 'Text Customization',
    state: 'Typography',
    view: _CardView.text,
  ),
  (
    id: 'share-card-branding',
    title: 'Accent & Branding',
    state: 'Brand controls',
    view: _CardView.branding,
  ),
  (
    id: 'share-card-scheduled',
    title: 'Scheduled Share',
    state: 'Schedule post',
    view: _CardView.scheduled,
  ),
  (
    id: 'share-card-analytics',
    title: 'Share Analytics',
    state: 'Card performance',
    view: _CardView.analytics,
  ),
  (
    id: 'share-card-top',
    title: 'Top Performing Cards',
    state: 'Ranked cards',
    view: _CardView.topCards,
  ),
  (
    id: 'share-card-download',
    title: 'Download Card',
    state: 'Quality picker',
    view: _CardView.download,
  ),
  (
    id: 'share-card-saved',
    title: 'Save to Gallery',
    state: 'Gallery save result',
    view: _CardView.saved,
  ),
  (
    id: 'share-card-export',
    title: 'Export & Print',
    state: 'PNG export',
    view: _CardView.export,
  ),
  (
    id: 'share-card-guidelines',
    title: 'Card Guidelines',
    state: 'CMS guidelines',
    view: _CardView.guidelines,
  ),
];

final List<PelevoScreenSpec> shareCardScreens = List.unmodifiable(
  _inventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'Share Cards',
      title: item.title,
      state: item.state,
      builder: (_) => _ShareCardScreen(view: item.view, title: item.title),
    ),
  ),
);

class _ShareCardScreen extends ConsumerStatefulWidget {
  const _ShareCardScreen({required this.view, required this.title});

  final _CardView view;
  final String title;

  @override
  ConsumerState<_ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<_ShareCardScreen> {
  int _nav = 4;
  int _contentTab = 0;
  int _template = 0;
  int _background = 0;
  int _font = 1;
  int _layout = 0;
  int _quality = 0;
  int _analyticsTab = 0;
  int _color = 3;
  double _textSize = .55;
  double _opacity = .8;
  bool _branding = true;
  bool _repeat = false;
  bool _busy = false;
  final GlobalKey _previewKey = GlobalKey();
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  late DateTime _scheduleFirstDate;

  @override
  void initState() {
    super.initState();
    _scheduleFirstDate = DateTime.now();
    _scheduledDate = _scheduleFirstDate.add(const Duration(hours: 1));
    _scheduledTime = TimeOfDay.fromDateTime(_scheduledDate);
    final variant = _variantName(widget.view);
    if (variant != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedShareVariantProvider.notifier).select(variant);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go(_backRoute),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(widget.title),
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: _nav,
      onDestinationSelected: (value) {
        setState(() => _nav = value);
        context.openPelevoTab(value);
      },
    ),
    child: switch (widget.view) {
      _CardView.home => _home(context),
      _CardView.content => _content(context),
      _CardView.template => _templates(context),
      _CardView.customize => _customize(context),
      _CardView.preview => _preview(context),
      _CardView.share => _share(context),
      _CardView.cards => _cards(context),
      _CardView.qr => _specialCard(context, _CardView.qr),
      _CardView.quote => _specialCard(context, _CardView.quote),
      _CardView.minimal => _specialCard(context, _CardView.minimal),
      _CardView.show => _specialCard(context, _CardView.show),
      _CardView.playlist => _specialCard(context, _CardView.playlist),
      _CardView.stats => _specialCard(context, _CardView.stats),
      _CardView.backgrounds => _backgrounds(context),
      _CardView.text => _textEditor(context),
      _CardView.branding => _brandingEditor(context),
      _CardView.scheduled => _scheduledShare(context),
      _CardView.analytics => _analytics(context),
      _CardView.topCards => _topCards(context),
      _CardView.download => _download(context),
      _CardView.saved => _saved(context),
      _CardView.export => _export(context),
      _CardView.guidelines => _guidelines(context),
    },
  );

  String get _backRoute => switch (widget.view) {
    _CardView.home => '/screen/home-feed',
    _CardView.content || _CardView.cards => '/screen/share-card-home',
    _CardView.template => '/screen/share-card-content',
    _CardView.customize ||
    _CardView.qr ||
    _CardView.quote ||
    _CardView.minimal ||
    _CardView.show ||
    _CardView.playlist ||
    _CardView.stats => '/screen/share-card-template',
    _CardView.preview ||
    _CardView.backgrounds ||
    _CardView.text ||
    _CardView.branding => '/screen/share-card-customize',
    _CardView.share || _CardView.download => '/screen/share-card-preview',
    _CardView.saved || _CardView.export => '/screen/share-card-share-options',
    _CardView.scheduled => '/screen/share-card-share-options',
    _CardView.analytics || _CardView.topCards => '/screen/share-card-my-cards',
    _CardView.guidelines => '/screen/share-card-home',
  };

  Widget _home(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context, variant: _CardView.show),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Create New Card',
        icon: Icons.add_rounded,
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/share-card-content'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      OutlinedButton.icon(
        onPressed: () => context.go('/screen/share-card-my-cards'),
        icon: const Icon(Icons.collections_outlined),
        label: const Text('My Cards'),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      TextButton(
        onPressed: () => context.go('/screen/share-card-guidelines'),
        child: const Text('Card Guidelines'),
      ),
    ],
  );

  Widget _content(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _tabs(
        const ['Episodes', 'Shows', 'Playlists'],
        _contentTab,
        (value) => setState(() => _contentTab = value),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      if (_contentTab == 0) _episodePicker(context),
      if (_contentTab == 1) _showPicker(context),
      if (_contentTab == 2) _playlistPicker(context),
    ],
  );

  Widget _episodePicker(BuildContext context) {
    final showId = ref.watch(selectedShowIdProvider);
    if (showId != null && showId.isNotEmpty) {
      final async = ref.watch(catalogEpisodesProvider);
      return async.when(
        data: (page) {
          if (page.items.isEmpty) {
            return const Text('No episodes to share.');
          }
          return Column(
            children: [
              for (final episode in page.items)
                _contentRow(
                  episode.title,
                  episode.subtitle,
                  episode.artworkUrl,
                  () => _chooseSubject(
                    context,
                    ShareCardSubject(
                      type: 'episode',
                      id: episode.id,
                      title: episode.title,
                      subtitle: episode.subtitle,
                      artworkUrl: episode.artworkUrl,
                      showId: episode.showId,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const CatalogStatusBody(),
        error:
            (error, _) => CatalogStatusBody(
              error: error,
              retry: () => ref.invalidate(catalogEpisodesProvider),
            ),
      );
    }
    final async = ref.watch(libraryRecentProvider);
    return async.when(
      data: (episodes) {
        if (episodes.isEmpty) {
          return const Text('No episodes to share.');
        }
        return Column(
          children: [
            for (final episode in episodes)
              _contentRow(
                episode.title,
                episode.subtitle,
                episode.artworkUrl,
                () => _chooseSubject(
                  context,
                  ShareCardSubject(
                    type: 'episode',
                    id: episode.id,
                    title: episode.title,
                    subtitle: episode.subtitle,
                    artworkUrl: episode.artworkUrl,
                    showId: episode.showId,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const CatalogStatusBody(),
      error:
          (error, _) => CatalogStatusBody(
            error: error,
            retry: () => ref.invalidate(libraryRecentProvider),
          ),
    );
  }

  Widget _showPicker(BuildContext context) {
    final async = ref.watch(libraryShowsProvider);
    return async.when(
      data: (shows) {
        if (shows.isEmpty) {
          return const Text('No shows to share.');
        }
        return Column(
          children: [
            for (final show in shows)
              _contentRow(
                show.title,
                show.author ?? 'Show',
                show.artworkUrl,
                () => _chooseSubject(
                  context,
                  ShareCardSubject(
                    type: 'show',
                    id: show.id,
                    title: show.title,
                    subtitle: show.author,
                    artworkUrl: show.artworkUrl,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const CatalogStatusBody(),
      error:
          (error, _) => CatalogStatusBody(
            error: error,
            retry: () => ref.invalidate(libraryShowsProvider),
          ),
    );
  }

  Widget _playlistPicker(BuildContext context) {
    final async = ref.watch(libraryPlaylistsProvider);
    return async.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return const Text('No playlists to share.');
        }
        return Column(
          children: [
            for (final playlist in playlists)
              _contentRow(
                playlist.name,
                playlist.countLabel,
                null,
                () => _chooseSubject(
                  context,
                  ShareCardSubject(
                    type: 'playlist',
                    id: playlist.id,
                    title: playlist.name,
                    subtitle: playlist.countLabel,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const CatalogStatusBody(),
      error:
          (error, _) => CatalogStatusBody(
            error: error,
            retry: () => ref.invalidate(libraryPlaylistsProvider),
          ),
    );
  }

  Widget _templates(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _tabs(
        const ['All', 'Minimal', 'Bold', 'Modern', 'Quotes'],
        _template,
        (value) => setState(() => _template = value),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: PelevoSpacing.sm,
        mainAxisSpacing: PelevoSpacing.sm,
        childAspectRatio: .82,
        children: [
          _templateTile(
            context,
            'QR Code',
            _CardView.qr,
            '/screen/share-card-qr',
          ),
          _templateTile(
            context,
            'Quote',
            _CardView.quote,
            '/screen/share-card-quote',
          ),
          _templateTile(
            context,
            'Minimal',
            _CardView.minimal,
            '/screen/share-card-minimal',
          ),
          _templateTile(
            context,
            'Show',
            _CardView.show,
            '/screen/share-card-show',
          ),
          _templateTile(
            context,
            'Playlist',
            _CardView.playlist,
            '/screen/share-card-playlist',
          ),
          _templateTile(
            context,
            'Stats',
            _CardView.stats,
            '/screen/share-card-stats',
          ),
        ],
      ),
    ],
  );

  Widget _customize(BuildContext context) {
    ref.watch(shareCardTemplatesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardPreview(context),
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _editorButton(
              Icons.image_outlined,
              'Background',
              '/screen/share-card-backgrounds',
            ),
            _editorButton(
              Icons.text_fields_rounded,
              'Text',
              '/screen/share-card-text',
            ),
            _editorButton(
              Icons.verified_outlined,
              'Brand',
              '/screen/share-card-branding',
            ),
            _editorButton(
              Icons.dashboard_customize_outlined,
              'Layout',
              null,
              onTap: () => setState(() => _layout = (_layout + 1) % 2),
            ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.md),
        _choiceChips(
          const ['Portrait', 'Square'],
          _layout,
          (value) => setState(() => _layout = value),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Save Card',
          color: PelevoColors.green,
          onPressed: _busy ? null : () => _saveCard(context),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context),
      const SizedBox(height: PelevoSpacing.lg),
      _choiceChips(
        const ['Portrait', 'Square'],
        _layout,
        (value) => setState(() => _layout = value),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go('/screen/share-card-customize'),
              child: const Text('Edit'),
            ),
          ),
          const SizedBox(width: PelevoSpacing.sm),
          Expanded(
            child: PelevoButton(
              label: 'Share Card',
              color: PelevoColors.green,
              onPressed: () => context.go('/screen/share-card-share-options'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _share(BuildContext context) {
    final subject = _draftSubject();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardPreview(context),
        const SizedBox(height: PelevoSpacing.md),
        if (subject != null)
          _contentRow(
            subject.title,
            subject.subtitle ?? subject.type,
            subject.artworkUrl,
            () => _openSubject(context, subject),
          ),
        const _Section('Share to'),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: PelevoSpacing.md,
          runSpacing: PelevoSpacing.lg,
          children: [
            for (final item in const [
              (Icons.ios_share_rounded, 'AirDrop', PelevoColors.blue),
              (Icons.chat_rounded, 'WhatsApp', Color(0xFF25D366)),
              (Icons.camera_alt_outlined, 'Instagram', Color(0xFFE1306C)),
              (Icons.facebook_rounded, 'Facebook', Color(0xFF1877F2)),
              (Icons.alternate_email_rounded, 'Twitter', Color(0xFF1DA1F2)),
              (Icons.send_rounded, 'Telegram', Color(0xFF229ED9)),
              (Icons.music_note_rounded, 'TikTok', Colors.white),
              (Icons.link_rounded, 'Copy Link', PelevoColors.textMuted),
              (Icons.more_horiz_rounded, 'More', PelevoColors.textMuted),
            ])
              SizedBox(
                width: 72,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey('share-app-${item.$2}'),
                    onTap: () async {
                      if (item.$2 == 'Copy Link') {
                        await _copyShareLink(context);
                      } else {
                        await _shareNative(context, label: item.$2);
                      }
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: item.$3.withValues(alpha: .16),
                          child: Icon(item.$1, color: item.$3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Save to Gallery',
        outlined: true,
        onPressed: () => _savePreviewToGallery(context),
      ),
        const SizedBox(height: PelevoSpacing.sm),
        PelevoButton(
          label: 'Download or Export',
          color: PelevoColors.green,
          onPressed: () => context.go('/screen/share-card-export'),
        ),
      ],
    );
  }

  Widget _cards(BuildContext context) {
    final async = ref.watch(shareCardsProvider);
    return async.when(
      data: (cards) {
        final filtered = switch (_contentTab) {
          1 => cards.where((card) => card.subjectType == 'episode').toList(),
          2 => cards.where((card) => card.subjectType == 'show').toList(),
          3 => cards.where((card) => card.subjectType == 'playlist').toList(),
          _ => cards,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabs(
              const ['All', 'Episodes', 'Shows', 'Playlists'],
              _contentTab,
              (value) => setState(() => _contentTab = value),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            if (filtered.isEmpty) const Text('No share cards yet.'),
            for (final card in filtered)
              Dismissible(
                key: ValueKey(card.id),
                background: Container(color: PelevoColors.red),
                confirmDismiss: (_) async {
                  context.showPelevoMessage('Deleting cards is not offered.');
                  return false;
                },
                child: _contentRow(
                  card.title,
                  card.subtitle,
                  _draftSubject()?.artworkUrl,
                  () => _showCardActions(context, card),
                  trailing: const Icon(Icons.more_vert_rounded),
                ),
              ),
            const SizedBox(height: PelevoSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.go('/screen/share-card-analytics'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Share Analytics'),
            ),
          ],
        );
      },
      loading: () => const CatalogStatusBody(),
      error:
          (error, _) => CatalogStatusBody(
            error: error,
            retry: () => ref.invalidate(shareCardsProvider),
          ),
    );
  }

  Widget _specialCard(BuildContext context, _CardView variant) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context, variant: variant),
      const SizedBox(height: PelevoSpacing.lg),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(selectedShareVariantProvider.notifier)
                    .select(_variantName(variant)!);
                context.go('/screen/share-card-customize');
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Customize'),
            ),
          ),
          const SizedBox(width: PelevoSpacing.sm),
          Expanded(
            child: PelevoButton(
              label: 'Use Template',
              color: PelevoColors.green,
              onPressed: () {
                ref
                    .read(selectedShareVariantProvider.notifier)
                    .select(_variantName(variant)!);
                context.go('/screen/share-card-customize');
              },
            ),
          ),
        ],
      ),
    ],
  );

  Widget _backgrounds(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context),
      const _Section('Card Backgrounds'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: PelevoSpacing.xs,
        mainAxisSpacing: PelevoSpacing.xs,
        children: [
          for (var i = 0; i < 16; i++)
            InkWell(
              onTap: () => setState(() => _background = i),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PelevoRadii.small),
                  gradient: LinearGradient(
                    colors: [
                      Colors.primaries[i % Colors.primaries.length],
                      Colors.black,
                    ],
                  ),
                  border:
                      _background == i
                          ? Border.all(color: PelevoColors.green, width: 3)
                          : null,
                ),
                child:
                    _background == i ? const Icon(Icons.check_rounded) : null,
              ),
            ),
        ],
      ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Apply Background',
        onPressed: () => context.go('/screen/share-card-customize'),
      ),
    ],
  );

  Widget _textEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context),
      const _Section('Text Style'),
      _choiceChips(
        const ['Aa', 'Aa', 'Aa', 'Aa'],
        _font,
        (value) => setState(() => _font = value),
      ),
      const _Section('Font'),
      TextField(
        readOnly: true,
        onTap: () => setState(() => _font = (_font + 1) % 4),
        decoration: InputDecoration(
          hintText: const ['Inter', 'Poppins', 'Montserrat', 'Roboto'][_font],
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
      ),
      const _Section('Text Size'),
      Slider(
        value: _textSize,
        onChanged: (value) => setState(() => _textSize = value),
      ),
      const _Section('Text Color'),
      _colorDots(),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Apply Text',
        onPressed: () => context.go('/screen/share-card-customize'),
      ),
    ],
  );

  Widget _brandingEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Section('Accent Color'),
      _colorDots(),
      const _Section('Logo Position'),
      _choiceChips(
        const ['↖', '↗', '↙', '↘'],
        _layout,
        (value) => setState(() => _layout = value),
      ),
      _switch(
        'Show Pelevo Logo',
        'Add Pelevo branding to the card',
        _branding,
        (value) => setState(() => _branding = value),
      ),
      const _Section('Watermark'),
      const TextField(decoration: InputDecoration(hintText: '@PELEVO PODCAST')),
      const _Section('Opacity'),
      Slider(
        value: _opacity,
        onChanged: (value) => setState(() => _opacity = value),
      ),
      PelevoButton(
        label: 'Save Branding',
        onPressed: () => context.go('/screen/share-card-customize'),
      ),
    ],
  );

  Widget _scheduledShare(BuildContext context) {
    final firstDate = DateTime(
      _scheduleFirstDate.year,
      _scheduleFirstDate.month,
      _scheduleFirstDate.day,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarDatePicker(
          initialDate: _scheduledDate,
          firstDate: firstDate,
          lastDate: firstDate.add(const Duration(days: 730)),
          onDateChanged: (value) => setState(() => _scheduledDate = value),
        ),
        const _Section('Time'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_scheduledTime.format(context)),
          trailing: const Icon(Icons.schedule_rounded),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _scheduledTime,
            );
            if (picked != null) setState(() => _scheduledTime = picked);
          },
        ),
        _switch(
          'Repeat',
          'Once',
          _repeat,
          (value) => setState(() => _repeat = value),
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'Schedule Share',
          onPressed: _busy ? null : () => _scheduleShare(context),
        ),
      ],
    );
  }

  Widget _analytics(BuildContext context) {
    final cardId = ref.watch(selectedShareCardIdProvider);
    final cardAsync =
        cardId == null || cardId.isEmpty ? null : ref.watch(shareCardProvider);
    final subject = _draftSubject();
    final card = cardAsync?.asData?.value;
    final shares = card?.eventCount('share') ?? 0;
    final clicks = card?.eventCount('click') ?? 0;
    final saves = card?.eventCount('save') ?? 0;
    final scans = card?.eventCount('qr_scan') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _contentRow(
          card?.title ?? subject?.title ?? 'Share card',
          card?.subtitle ?? subject?.subtitle ?? 'No card selected',
          subject?.artworkUrl,
          () => context.go('/screen/share-card-preview'),
        ),
        if (cardAsync?.hasError == true)
          Padding(
            padding: const EdgeInsets.only(top: PelevoSpacing.sm),
            child: Text(catalogFailure(cardAsync!.error!).message),
          ),
        const SizedBox(height: PelevoSpacing.lg),
        Row(
          children: [
            Expanded(child: _Metric('$shares', 'Total Shares')),
            Expanded(child: _Metric('$clicks', 'Clicks')),
            Expanded(child: _Metric('$saves', 'Saves')),
            Expanded(child: _Metric('$scans', 'QR Scans')),
          ],
        ),
        const SizedBox(height: PelevoSpacing.xl),
        PelevoButton(
          label: 'View Detailed Analytics',
          onPressed: () => context.go('/screen/share-card-top'),
        ),
      ],
    );
  }

  Widget _topCards(BuildContext context) {
    final async = ref.watch(shareCardsProvider);
    return async.when(
      data: (cards) {
        final now = DateTime.now();
        final cutoff = switch (_analyticsTab) {
          0 => now.subtract(const Duration(days: 7)),
          1 => now.subtract(const Duration(days: 30)),
          _ => null,
        };
        final filtered =
            cutoff == null
                ? cards
                : cards
                    .where((card) => !card.createdAt.isBefore(cutoff))
                    .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabs(
              const ['This Week', 'This Month', 'All Time'],
              _analyticsTab,
              (value) => setState(() => _analyticsTab = value),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            if (filtered.isEmpty) const Text('No share cards yet.'),
            for (var i = 0; i < filtered.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Stack(
                  children: [
                    CatalogArtwork(
                      url: _draftSubject()?.artworkUrl,
                      width: 52,
                      height: 52,
                      radius: PelevoRadii.small,
                    ),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: PelevoColors.green,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                title: Text(filtered[i].title),
                subtitle: Text(filtered[i].subtitle),
                onTap: () {
                  ref
                      .read(selectedShareCardIdProvider.notifier)
                      .select(filtered[i].id);
                  ref
                      .read(latestShareCardProvider.notifier)
                      .select(filtered[i]);
                  context.go('/screen/share-card-analytics');
                },
              ),
          ],
        );
      },
      loading: () => const CatalogStatusBody(),
      error:
          (error, _) => CatalogStatusBody(
            error: error,
            retry: () => ref.invalidate(shareCardsProvider),
          ),
    );
  }

  Widget _download(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context),
      const _Section('Choose Quality'),
      for (var i = 0; i < 2; i++)
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: i,
          groupValue: _quality,
          activeColor: PelevoColors.green,
          title: Text(const ['High Quality', 'Ultra Quality'][i]),
          subtitle: Text(const ['1080 × 1350', '2160 × 2700'][i]),
          onChanged: (value) => setState(() => _quality = value!),
        ),
      PelevoButton(
        label: 'Download',
        icon: Icons.download_rounded,
        onPressed: () => _savePreviewToGallery(context),
      ),
    ],
  );

  Widget _saved(BuildContext context) {
    final save = ref.watch(shareCardGallerySaveProvider);
    final succeeded = save?.succeeded == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PelevoSpacing.xxl),
        if (succeeded) _successIcon() else _pendingIcon(),
        const SizedBox(height: PelevoSpacing.xl),
        Text(
          succeeded ? 'Saved Successfully!' : 'Save to Gallery',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          succeeded
              ? (save?.message ?? 'The share card image was saved to your gallery.')
              : (save?.message ??
                  'Save a share card image first to write it to your gallery.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.xxl),
        PelevoButton(
          label: 'View in Gallery',
          onPressed:
              succeeded
                  ? () => _openSystemGallery(context)
                  : () => context.go('/screen/share-card-my-cards'),
        ),
        const SizedBox(height: PelevoSpacing.sm),
        OutlinedButton(
          onPressed: () => context.go('/screen/share-card-share-options'),
          child: const Text('Share Again'),
        ),
      ],
    );
  }

  Widget _export(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _cardPreview(context),
      const _Section('Export Options'),
      for (final item in const [
        ('Print Ready (CMYK)', 'High resolution PNG export', Icons.print_outlined),
        ('Digital Use (RGB)', 'Web & social media PNG', Icons.image_outlined),
      ])
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: item.$1,
          groupValue:
              _quality == 0 ? 'Print Ready (CMYK)' : 'Digital Use (RGB)',
          title: Text(item.$1),
          subtitle: Text(item.$2),
          secondary: Icon(item.$3, color: PelevoColors.green),
          onChanged:
              (value) => setState(
                () => _quality = value == 'Print Ready (CMYK)' ? 0 : 1,
              ),
        ),
      const Text(
        'Exports are RGB PNG files. CMYK PDF is not offered.',
        style: TextStyle(color: PelevoColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: 'Export',
        icon: Icons.file_download_outlined,
        onPressed: () => _exportPreview(context),
      ),
    ],
  );

  Widget _guidelines(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CmsDocumentContent(document: CmsDocument.guidelines),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Create a Card',
        onPressed: () => context.go('/screen/share-card-content'),
      ),
    ],
  );

  Widget _cardPreview(
    BuildContext context, {
    _CardView? variant,
  }) {
    final selectedVariant = ref.watch(selectedShareVariantProvider);
    final view = variant ?? _viewFromVariant(selectedVariant);
    final subject = _draftSubject();
    final stats = ref.watch(listenerStatsProvider).asData?.value;
    final quote = _headline(view, subject, stats);
    final color = switch (view) {
      _CardView.minimal => PelevoColors.green,
      _CardView.quote || _CardView.playlist => PelevoColors.yellow,
      _CardView.stats => const Color(0xFF176B6B),
      _ => PelevoColors.red,
    };
    return AspectRatio(
      aspectRatio: _layout == 0 ? .9 : 1,
      child: RepaintBoundary(
        key: _previewKey,
        child: Container(
          padding: const EdgeInsets.all(PelevoSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: PelevoRadii.card,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, PelevoColors.surface, Colors.black],
            ),
            border: Border.all(color: color.withValues(alpha: .8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_branding)
                const Text(
                  'PELEVO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              const Spacer(),
              if (view == _CardView.qr)
                Center(child: _qrBitmap(_previewShareUrl(), size: 96))
              else
                Text(
                  quote,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 22 + (_textSize * 8),
                  ),
                ),
              const SizedBox(height: PelevoSpacing.sm),
              Text(subject?.subtitle ?? subject?.title ?? 'Pelevo'),
              const Spacer(),
              Row(
                children: [
                  CatalogArtwork(
                    url: subject?.artworkUrl,
                    width: 44,
                    height: 44,
                    radius: PelevoRadii.small,
                  ),
                  const Spacer(),
                  if (view != _CardView.qr)
                    _qrBitmap(_previewShareUrl(), size: 44),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateTile(
    BuildContext context,
    String label,
    _CardView variant,
    String route,
  ) => InkWell(
    onTap: () {
      ref
          .read(selectedShareVariantProvider.notifier)
          .select(_variantName(variant)!);
      context.go(route);
    },
    child: Column(
      children: [
        Expanded(child: _compactPreview(context, variant)),
        const SizedBox(height: 4),
        Text(label),
      ],
    ),
  );

  Widget _compactPreview(BuildContext context, _CardView variant) {
    final subject = _draftSubject();
    final stats = ref.watch(listenerStatsProvider).asData?.value;
    final text = _headline(variant, subject, stats);
    final color = switch (variant) {
      _CardView.minimal => PelevoColors.green,
      _CardView.quote || _CardView.playlist => PelevoColors.yellow,
      _CardView.stats => const Color(0xFF176B6B),
      _ => PelevoColors.red,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PelevoSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: PelevoRadii.card,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, PelevoColors.surface, Colors.black],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PELEVO',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Expanded(
            child: Center(
              child:
                  variant == _CardView.qr
                      ? _qrBitmap(_previewShareUrl(), size: 58)
                      : Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
            ),
          ),
          Text(
            subject?.title ?? 'Pelevo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: PelevoColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _contentRow(
    String title,
    String subtitle,
    String? artworkUrl,
    VoidCallback onTap, {
    Widget? trailing,
  }) => Card(
    color: PelevoColors.surface,
    margin: const EdgeInsets.only(bottom: PelevoSpacing.xs),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: PelevoSpacing.sm),
      minLeadingWidth: 54,
      leading: CatalogArtwork(
        url: artworkUrl,
        width: 50,
        height: 50,
        radius: PelevoRadii.small,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  Widget _editorButton(
    IconData icon,
    String label,
    String? route, {
    VoidCallback? onTap,
  }) => InkWell(
    onTap:
        onTap ??
        (route == null
            ? () => context.showPelevoMessage('$label options')
            : () => context.go(route)),
    child: SizedBox(
      width: 70,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: PelevoColors.surfaceHigh,
            child: Icon(icon, color: PelevoColors.green),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _tabs(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: PelevoSpacing.xs),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected == i,
              selectedColor: PelevoColors.green,
              onSelected: (_) => onSelected(i),
            ),
          ),
      ],
    ),
  );

  Widget _choiceChips(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) => Wrap(
    spacing: PelevoSpacing.xs,
    runSpacing: PelevoSpacing.xs,
    children: [
      for (var i = 0; i < labels.length; i++)
        ChoiceChip(
          label: Text(labels[i]),
          selected: selected == i,
          selectedColor: PelevoColors.green,
          onSelected: (_) => onSelected(i),
        ),
    ],
  );

  Widget _colorDots() => Wrap(
    spacing: PelevoSpacing.sm,
    children: [
      for (final (index, color)
          in const [
            Colors.white,
            PelevoColors.red,
            PelevoColors.yellow,
            PelevoColors.green,
            PelevoColors.blue,
            Color(0xFF9C6ADE),
          ].indexed)
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _color = index),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: _color == index ? PelevoColors.text : color,
            child: CircleAvatar(radius: 11, backgroundColor: color),
          ),
        ),
    ],
  );

  Widget _switch(
    String title,
    String? subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: value,
    activeColor: PelevoColors.green,
    onChanged: onChanged,
  );

  Widget _successIcon() => Center(
    child: Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PelevoColors.green.withValues(alpha: .15),
        border: Border.all(color: PelevoColors.green),
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 58,
        color: PelevoColors.green,
      ),
    ),
  );

  Widget _pendingIcon() => Center(
    child: Container(
      width: 112,
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PelevoColors.textMuted.withValues(alpha: .15),
        border: Border.all(color: PelevoColors.textMuted),
      ),
      child: const Icon(
        Icons.photo_library_outlined,
        size: 48,
        color: PelevoColors.textMuted,
      ),
    ),
  );

  Widget _qrBitmap(String data, {required double size}) => ColoredBox(
    color: Colors.white,
    child: QrImageView(
      data: data.isEmpty ? 'pelevo://' : data,
      size: size,
      padding: EdgeInsets.all(size < 50 ? 2 : 4),
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    ),
  );

  ShareCardSubject? _draftSubject() {
    final selected = ref.watch(selectedShareSubjectProvider);
    if (selected != null) return selected;
    final episodeId = ref.watch(selectedEpisodeIdProvider);
    if (episodeId == null || episodeId.isEmpty) return null;
    final episode = ref.watch(catalogEpisodeProvider).asData?.value;
    if (episode == null) return null;
    return ShareCardSubject(
      type: 'episode',
      id: episode.id,
      title: episode.title,
      subtitle: episode.subtitle,
      artworkUrl: episode.artworkUrl,
      showId: episode.showId,
    );
  }

  ShareCardSubject? _readSubject() {
    final selected = ref.read(selectedShareSubjectProvider);
    if (selected != null) return selected;
    final episodeId = ref.read(selectedEpisodeIdProvider);
    if (episodeId == null || episodeId.isEmpty) return null;
    final episode = ref.read(catalogEpisodeProvider).asData?.value;
    if (episode == null) return null;
    return ShareCardSubject(
      type: 'episode',
      id: episode.id,
      title: episode.title,
      subtitle: episode.subtitle,
      artworkUrl: episode.artworkUrl,
      showId: episode.showId,
    );
  }

  String _headline(
    _CardView variant,
    ShareCardSubject? subject,
    ListenerStats? stats,
  ) {
    final title = subject?.title ?? 'Pelevo';
    return switch (variant) {
      _CardView.minimal => title.toUpperCase(),
      _CardView.stats =>
        stats == null ? title : '${stats.episodesCompleted}\nEPISODES',
      _CardView.quote ||
      _CardView.playlist ||
      _CardView.show ||
      _ => title,
    };
  }

  String? _variantName(_CardView view) => switch (view) {
    _CardView.qr => 'qr',
    _CardView.quote => 'quote',
    _CardView.minimal => 'minimal',
    _CardView.show => 'show',
    _CardView.playlist => 'playlist',
    _CardView.stats => 'stats',
    _ => null,
  };

  _CardView _viewFromVariant(String variant) => switch (variant) {
    'qr' => _CardView.qr,
    'quote' => _CardView.quote,
    'minimal' => _CardView.minimal,
    'playlist' => _CardView.playlist,
    'stats' => _CardView.stats,
    _ => _CardView.show,
  };

  void _chooseSubject(BuildContext context, ShareCardSubject subject) {
    ref.read(selectedShareSubjectProvider.notifier).select(subject);
    if (subject.type == 'episode') {
      openCatalogEpisode(
        context,
        episodeId: subject.id,
        showId: subject.showId,
      );
    } else if (subject.type == 'show') {
      openCatalogShow(context, subject.id);
    }
    context.go('/screen/share-card-template');
  }

  void _openSubject(BuildContext context, ShareCardSubject subject) {
    if (subject.type == 'episode') {
      openCatalogEpisode(
        context,
        episodeId: subject.id,
        showId: subject.showId,
      );
      context.go('/screen/episode-details');
      return;
    }
    if (subject.type == 'show') {
      openCatalogShow(context, subject.id);
      context.go('/screen/podcast-details');
    }
  }

  Future<void> _copyShareLink(BuildContext context) async {
    final url = _shareUrl();
    if (url == null || url.isEmpty) {
      context.showPelevoMessage('No share link is available.');
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) context.showPelevoMessage('Share link copied');
    } catch (_) {
      if (context.mounted) {
        context.showPelevoMessage('Copying to the clipboard is not available.');
      }
    }
  }

  String? _shareUrl() {
    var url = ref.read(latestShareCardProvider)?.url;
    final cardId = ref.read(selectedShareCardIdProvider);
    if ((url == null || url.isEmpty) && cardId != null && cardId.isNotEmpty) {
      url = ref.read(shareCardProvider).asData?.value.url;
    }
    final subject = _readSubject();
    return url ??
        switch (subject?.type) {
          'episode' => catalogShareEpisodeLink(subject!.id),
          'show' => catalogShareShowLink(subject!.id),
          'reel' => catalogShareReelLink(subject!.id),
          _ => null,
        };
  }

  String _previewShareUrl() {
    var url = ref.watch(latestShareCardProvider)?.url;
    final cardId = ref.watch(selectedShareCardIdProvider);
    if ((url == null || url.isEmpty) && cardId != null && cardId.isNotEmpty) {
      url = ref.watch(shareCardProvider).asData?.value.url;
    }
    final subject = _draftSubject();
    return url ??
        switch (subject?.type) {
          'episode' => catalogShareEpisodeLink(subject!.id),
          'show' => catalogShareShowLink(subject!.id),
          'reel' => catalogShareReelLink(subject!.id),
          _ => 'pelevo://',
        };
  }

  double get _exportPixelRatio => _quality == 0 ? 2.5 : 4.0;

  Future<void> _shareNative(BuildContext context, {required String label}) async {
    if (_busy) return;
    final origin = pelevoShareOrigin(context);
    setState(() => _busy = true);
    try {
      final exporter = ref.read(shareCardExporterProvider);
      final bytes = await exporter.capturePng(
        _previewKey,
        pixelRatio: _exportPixelRatio,
      );
      final file = await exporter.writeTempPng(bytes);
      await exporter.shareImage(
        file,
        text: _shareUrl(),
        sharePositionOrigin: origin,
      );
    } on ShareCardExportFailure catch (error) {
      if (context.mounted) context.showPelevoMessage(error.message);
    } catch (_) {
      if (context.mounted) {
        context.showPelevoMessage(
          '$label sharing is not available on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePreviewToGallery(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final exporter = ref.read(shareCardExporterProvider);
      final bytes = await exporter.capturePng(
        _previewKey,
        pixelRatio: _exportPixelRatio,
      );
      await exporter.saveToGallery(bytes);
      ref.read(shareCardGallerySaveProvider.notifier).setResult(
            const ShareCardGallerySave(
              succeeded: true,
              message: 'The share card image was saved to your gallery.',
            ),
          );
      if (!context.mounted) return;
      context.go('/screen/share-card-saved');
    } on ShareCardExportFailure catch (error) {
      ref.read(shareCardGallerySaveProvider.notifier).setResult(
            ShareCardGallerySave(succeeded: false, message: error.message),
          );
      if (context.mounted) {
        context.showPelevoMessage(error.message);
        context.go('/screen/share-card-saved');
      }
    } catch (_) {
      const message = 'Saving to the gallery is not available on this device.';
      ref.read(shareCardGallerySaveProvider.notifier).setResult(
            const ShareCardGallerySave(succeeded: false, message: message),
          );
      if (context.mounted) {
        context.showPelevoMessage(message);
        context.go('/screen/share-card-saved');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPreview(BuildContext context) async {
    if (_busy) return;
    final origin = pelevoShareOrigin(context);
    setState(() => _busy = true);
    try {
      final exporter = ref.read(shareCardExporterProvider);
      final bytes = await exporter.capturePng(
        _previewKey,
        pixelRatio: _exportPixelRatio,
      );
      final file = await exporter.writeTempPng(bytes, prefix: 'pelevo-export');
      await exporter.shareImage(
        file,
        text: _shareUrl(),
        sharePositionOrigin: origin,
      );
      if (context.mounted) {
        context.showPelevoMessage('Share card PNG exported');
      }
    } on ShareCardExportFailure catch (error) {
      if (context.mounted) context.showPelevoMessage(error.message);
    } catch (_) {
      if (context.mounted) {
        context.showPelevoMessage(
          'Exporting the share card is not available on this device.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSystemGallery(BuildContext context) async {
    try {
      await ref.read(shareCardExporterProvider).openGallery();
    } catch (_) {
      if (context.mounted) {
        context.showPelevoMessage(
          'Opening the gallery is not available on this device.',
        );
      }
    }
  }

  Future<void> _saveCard(
    BuildContext context, {
    DateTime? scheduledAt,
    String successRoute = '/screen/share-card-preview',
  }) async {
    final subject = _readSubject();
    if (subject == null) {
      context.showPelevoMessage(missingShareSubject.message);
      return;
    }
    if (!subject.canPost) {
      context.showPelevoMessage('Playlists cannot be posted as share cards.');
      return;
    }
    final templates = await ref.read(shareCardTemplatesProvider.future);
    if (!context.mounted) return;
    if (templates.isEmpty) {
      context.showPelevoMessage('No share card template is available.');
      return;
    }
    final templateId = templates.first.id;
    setState(() => _busy = true);
    try {
      final card = await ref.read(shareCardRepositoryProvider).create(
        templateId: templateId,
        subjectType: subject.type,
        subjectId: subject.id,
        payload: {
          'variant': ref.read(selectedShareVariantProvider),
          'layout': _layout == 0 ? 'portrait' : 'square',
          'quote': subject.title,
        },
        scheduledAt: scheduledAt,
      );
      ref.read(selectedShareCardIdProvider.notifier).select(card.id);
      ref.read(latestShareCardProvider.notifier).select(card);
      ref.invalidate(shareCardsProvider);
      ref.invalidate(shareCardProvider);
      if (!context.mounted) return;
      if (scheduledAt != null) {
        context.showPelevoMessage('Share scheduled');
      }
      context.go(successRoute);
    } on ApiFailure catch (error) {
      if (!context.mounted) return;
      context.showPelevoMessage(error.message);
      context.go(successRoute);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scheduleShare(BuildContext context) async {
    final when = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );
    if (!when.isAfter(DateTime.now())) {
      context.showPelevoMessage('Pick a time after now.');
      return;
    }
    await _saveCard(
      context,
      scheduledAt: when,
      successRoute: '/screen/share-card-my-cards',
    );
  }

  void _showCardActions(BuildContext context, ShareCard card) {
    ref.read(selectedShareCardIdProvider.notifier).select(card.id);
    ref.read(latestShareCardProvider.notifier).select(card);
    showPelevoSheet<void>(
      context: context,
      builder:
          (sheetContext) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in const [
                (Icons.edit_outlined, 'Edit'),
                (Icons.share_outlined, 'Share'),
                (Icons.copy_rounded, 'Duplicate'),
                (Icons.analytics_outlined, 'Analytics'),
                (Icons.delete_outline_rounded, 'Delete'),
              ])
                ListTile(
                  leading: Icon(
                    item.$1,
                    color:
                        item.$2 == 'Delete'
                            ? PelevoColors.red
                            : PelevoColors.green,
                  ),
                  title: Text(item.$2),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (item.$2 == 'Edit') {
                      context.go('/screen/share-card-customize');
                    } else if (item.$2 == 'Share') {
                      context.go('/screen/share-card-share-options');
                    } else if (item.$2 == 'Analytics') {
                      context.go('/screen/share-card-analytics');
                    } else {
                      context.showPelevoMessage(
                        '${item.$2} is not offered.',
                      );
                    }
                  },
                ),
            ],
          ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: PelevoSpacing.xl,
      bottom: PelevoSpacing.xs,
    ),
    child: Text(
      title,
      style: const TextStyle(
        color: PelevoColors.textMuted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: PelevoColors.textMuted, fontSize: 12),
      ),
    ],
  );
}
