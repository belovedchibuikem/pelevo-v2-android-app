import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/ai/ai_data.dart';
import 'package:pelevo/features/podcast/catalog_chrome.dart';
import 'package:pelevo/features/podcast/catalog_data.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

enum _AiView {
  home,
  recommenderIntro,
  recommendations,
  summaryIntro,
  summaryResult,
  chaptersIntro,
  chaptersResult,
  highlightsIntro,
  highlightsResult,
  askIntro,
  askAnswer,
  lineup,
  settings,
}

const _aiInventory = <({String id, String title, String state, _AiView view})>[
  (id: 'ai-hub', title: 'AI Hub', state: 'Tool home', view: _AiView.home),
  (
    id: 'ai-discover',
    title: 'AI Podcast Recommender',
    state: 'Recommender intro',
    view: _AiView.recommenderIntro,
  ),
  (
    id: 'ai-generating',
    title: 'Your Recommendations',
    state: 'Recommendation results',
    view: _AiView.recommendations,
  ),
  (
    id: 'ai-summary',
    title: 'Smart Summary',
    state: 'Summary intro',
    view: _AiView.summaryIntro,
  ),
  (
    id: 'ai-transcript',
    title: 'Episode Summary',
    state: 'Summary result',
    view: _AiView.summaryResult,
  ),
  (
    id: 'ai-clips',
    title: 'Chapters Generator',
    state: 'Chapters intro',
    view: _AiView.chaptersIntro,
  ),
  (
    id: 'ai-notes',
    title: 'Generated Chapters',
    state: 'Chapters result',
    view: _AiView.chaptersResult,
  ),
  (
    id: 'ai-translate',
    title: 'Highlights Finder',
    state: 'Highlights intro',
    view: _AiView.highlightsIntro,
  ),
  (
    id: 'ai-history',
    title: 'Highlights Results',
    state: 'Highlights list',
    view: _AiView.highlightsResult,
  ),
  (id: 'ai-ask', title: 'Ask AI', state: 'Ask intro', view: _AiView.askIntro),
  (
    id: 'ai-result',
    title: 'Ask AI',
    state: 'AI answer',
    view: _AiView.askAnswer,
  ),
  (
    id: 'ai-lineup',
    title: 'Your Podcast Lineup',
    state: 'Weekly guide',
    view: _AiView.lineup,
  ),
  (
    id: 'ai-settings',
    title: 'AI Hub Settings',
    state: 'Preferences',
    view: _AiView.settings,
  ),
];

final List<PelevoScreenSpec> aiHubScreens = List.unmodifiable(
  _aiInventory.map(
    (item) => PelevoScreenSpec(
      id: item.id,
      section: 'AI Hub',
      title: item.title,
      state: item.state,
      builder: (_) => _AiHubScreen(view: item.view, title: item.title),
    ),
  ),
);

class _AiHubScreen extends ConsumerStatefulWidget {
  const _AiHubScreen({required this.view, required this.title});

  final _AiView view;
  final String title;

  @override
  ConsumerState<_AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends ConsumerState<_AiHubScreen> {
  int _nav = 2;
  int _summaryLength = 1;
  int _chapterStyle = 1;
  int _highlightType = 0;
  int _summaryTab = 0;
  bool _busy = false;
  final _askController = TextEditingController();

  static const _purple = Color(0xFF8B5CF6);
  static const _gold = Color(0xFFE8B923);

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          if (widget.view == _AiView.home) {
            context.pelevoBack(fallback: '/screen/library-1');
          } else if (widget.view == _AiView.recommendations) {
            context.pelevoBack(fallback: '/screen/ai-discover');
          } else if (widget.view == _AiView.summaryResult) {
            context.pelevoBack(fallback: '/screen/ai-summary');
          } else if (widget.view == _AiView.chaptersResult) {
            context.pelevoBack(fallback: '/screen/ai-clips');
          } else if (widget.view == _AiView.highlightsResult) {
            context.pelevoBack(fallback: '/screen/ai-translate');
          } else if (widget.view == _AiView.askAnswer) {
            context.pelevoBack(fallback: '/screen/ai-ask');
          } else {
            context.pelevoBack(fallback: '/screen/ai-hub');
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(widget.title)),
          if (widget.view == _AiView.home) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _purple),
              ),
              child: const Text(
                'Beta',
                style: TextStyle(
                  color: _purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.view == _AiView.home)
          IconButton(
            tooltip: 'AI Hub settings',
            onPressed: () => context.go('/screen/ai-settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: _nav,
      onDestinationSelected: (value) {
        setState(() => _nav = value);
        context.openPelevoTab(value);
      },
    ),
    child: switch (widget.view) {
      _AiView.home => _home(context),
      _AiView.recommenderIntro => _recommenderIntro(context),
      _AiView.recommendations => _recommendations(context),
      _AiView.summaryIntro => _summaryIntro(context),
      _AiView.summaryResult => _summaryResult(context),
      _AiView.chaptersIntro => _chaptersIntro(context),
      _AiView.chaptersResult => _chaptersResult(context),
      _AiView.highlightsIntro => _highlightsIntro(context),
      _AiView.highlightsResult => _highlightsResult(context),
      _AiView.askIntro => _askIntro(context),
      _AiView.askAnswer => _askAnswer(context),
      _AiView.lineup => _lineup(context),
      _AiView.settings => _settings(context),
    },
  );

  Widget _home(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PelevoSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PelevoRadii.large),
          gradient: LinearGradient(
            colors: [_purple.withValues(alpha: .35), PelevoColors.surface],
          ),
          border: Border.all(color: _purple.withValues(alpha: .45)),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/ai/hero_brain.png',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: PelevoSpacing.md),
            const Expanded(
              child: Text(
                'Smart tools for a better listening experience',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text('Discover with AI', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: PelevoSpacing.sm),
      _toolTile(
        Icons.chat_bubble_outline_rounded,
        PelevoColors.blue,
        'Ask Pelevo',
        'Describe what you want to hear',
        () => context.go('/screen/ai-ask'),
      ),
      _toolTile(
        Icons.queue_music_rounded,
        _gold,
        'Your Podcast Lineup',
        'A weekly guide that explains each pick',
        () => context.go('/screen/ai-lineup'),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text('Popular Tools', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: PelevoSpacing.sm),
      _toolTile(
        Icons.auto_awesome,
        _purple,
        'AI Podcast Recommender',
        'Personalized show matches',
        () => context.go('/screen/ai-discover'),
      ),
      _toolTile(
        Icons.description_outlined,
        PelevoColors.green,
        'Smart Summary',
        'Summarize any episode fast',
        () => context.go('/screen/ai-summary'),
      ),
      _toolTile(
        Icons.auto_stories_outlined,
        PelevoColors.orange,
        'Chapters Generator',
        'Create chapter markers',
        () => context.go('/screen/ai-clips'),
      ),
      _toolTile(
        Icons.star_rounded,
        _gold,
        'Highlights Finder',
        'Pull key quotes and tips',
        () => context.go('/screen/ai-translate'),
      ),
      _toolTile(
        Icons.chat_bubble_outline_rounded,
        PelevoColors.blue,
        'Ask AI',
        'Chat about this episode',
        () => context.go('/screen/ai-ask'),
      ),
    ],
  );

  Widget _recommenderIntro(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/ai/hero_recommender.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text(
        'AI Podcast Recommender',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'Get personalized podcast recommendations based on what you already love.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'What this uses',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      for (final item in const [
        ('Listening history', Icons.history_rounded),
        ('Favorite topics', Icons.favorite_outline_rounded),
        ('Similar listener patterns', Icons.people_outline_rounded),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(item.$2, color: _purple),
          title: Text(item.$1),
        ),
      const SizedBox(height: PelevoSpacing.xl),
      PelevoButton(
        label: 'Generate Recommendations',
        color: PelevoColors.green,
        onPressed: () => context.go('/screen/ai-generating'),
      ),
    ],
  );

  Widget _recommendations(BuildContext context) {
    final async = ref.watch(aiRecommendationsProvider);
    if (async.isLoading) return const CatalogStatusBody();
    if (async.hasError) {
      return CatalogStatusBody(
        error: async.error,
        retry: () => ref.invalidate(aiRecommendationsProvider),
      );
    }
    final items = async.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Based on your listening habits.',
          style: TextStyle(color: PelevoColors.textMuted),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (items.isEmpty)
          const Text(
            'No recommendations are available yet.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else
          for (final item in items)
            Card(
              color: PelevoColors.surface,
              margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
              child: ListTile(
                leading: CatalogArtwork(
                  url: null,
                  width: 52,
                  height: 52,
                  assetPath: 'assets/ai/rec_deep.png',
                ),
                title: Text(item.title),
                subtitle: Text(item.reason ?? ''),
                isThreeLine: item.reason != null && item.reason!.isNotEmpty,
                onTap: () {
                  if (item.showId != null && item.showId!.isNotEmpty) {
                    openCatalogShow(context, item.showId!);
                    context.go('/screen/podcast-details');
                  } else {
                    openCatalogEpisode(context, episodeId: item.id);
                    context.go('/screen/episode-details');
                  }
                },
              ),
            ),
      ],
    );
  }

  Widget _summaryIntro(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/ai/hero_summary.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text('Smart Summary', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'Turn a long episode into a clear summary you can skim in minutes.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Choose summary length',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      for (final option in const [
        (0, 'Short', 'A quick overview'),
        (1, 'Medium', 'Balanced detail'),
        (2, 'Detailed', 'Full context'),
      ])
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: option.$1,
          groupValue: _summaryLength,
          activeColor: PelevoColors.green,
          title: Text(option.$2),
          subtitle: Text(option.$3),
          onChanged: (value) => setState(() => _summaryLength = value ?? 1),
        ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Generate Summary',
        color: PelevoColors.green,
        onPressed: _busy
            ? null
            : () => _startJob(context, type: 'summary', resultRoute: '/screen/ai-transcript'),
      ),
    ],
  );

  Widget _summaryResult(BuildContext context) {
    final notice = ref.watch(aiNoticeProvider);
    final jobId = ref.watch(selectedAiJobIdProvider);
    final jobAsync = jobId == null || jobId.isEmpty ? null : ref.watch(aiJobProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _episodeHeader(context),
        const SizedBox(height: PelevoSpacing.md),
        Wrap(
          spacing: PelevoSpacing.sm,
          children: [
            _tabChip('Summary', 0),
            _tabChip('Key Takeaways', 1),
          ],
        ),
        const SizedBox(height: PelevoSpacing.lg),
        if (notice != null) Text(notice),
        if (jobAsync == null && notice == null)
          CatalogStatusBody(error: missingAiJob)
        else if (jobAsync != null && jobAsync.isLoading)
          const CatalogStatusBody()
        else if (jobAsync != null && jobAsync.hasError)
          CatalogStatusBody(
            error: jobAsync.error,
            retry: () => ref.invalidate(aiJobProvider),
          )
        else if (jobAsync != null)
          _jobBody(jobAsync.requireValue, takeaways: _summaryTab == 1)
        else
          const SizedBox.shrink(),
        const SizedBox(height: PelevoSpacing.lg),
        Text('Topics Covered', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: PelevoSpacing.sm),
        if (jobAsync?.asData?.value.topics.isNotEmpty == true)
          Wrap(
            spacing: PelevoSpacing.xs,
            runSpacing: PelevoSpacing.xs,
            children: [
              for (final topic in jobAsync!.requireValue.topics)
                Chip(label: Text(topic), visualDensity: VisualDensity.compact),
            ],
          )
        else
          const Text(
            'Topics are not returned as tags.',
            style: TextStyle(color: PelevoColors.textMuted),
          ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'Ask AI about this',
          outlined: true,
          color: PelevoColors.green,
          onPressed: () => context.go('/screen/ai-ask'),
        ),
      ],
    );
  }

  Widget _chaptersIntro(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/ai/hero_chapters.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text(
        'Chapters Generator',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'Automatically create chapter markers so you can jump to the moments that matter.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Chapter style',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      for (final option in const [
        (0, 'Detailed', 'More chapters, deeper labels'),
        (1, 'Balanced', 'Clear sections without clutter'),
        (2, 'Brief', 'Only the major beats'),
      ])
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: option.$1,
          groupValue: _chapterStyle,
          activeColor: PelevoColors.green,
          title: Text(option.$2),
          subtitle: Text(option.$3),
          onChanged: (value) => setState(() => _chapterStyle = value ?? 1),
        ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Generate Chapters',
        color: PelevoColors.green,
        onPressed: _busy
            ? null
            : () => _startJob(context, type: 'chapters', resultRoute: '/screen/ai-notes'),
      ),
    ],
  );

  Widget _chaptersResult(BuildContext context) {
    final notice = ref.watch(aiNoticeProvider);
    final jobId = ref.watch(selectedAiJobIdProvider);
    final jobAsync = jobId == null || jobId.isEmpty ? null : ref.watch(aiJobProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _episodeHeader(context),
        const SizedBox(height: PelevoSpacing.md),
        if (notice != null) Text(notice),
        if (jobAsync == null && notice == null)
          CatalogStatusBody(error: missingAiJob)
        else if (jobAsync != null && jobAsync.isLoading)
          const CatalogStatusBody()
        else if (jobAsync != null && jobAsync.hasError)
          CatalogStatusBody(
            error: jobAsync.error,
            retry: () => ref.invalidate(aiJobProvider),
          )
        else if (jobAsync != null)
          _jobBody(jobAsync.requireValue)
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _highlightsIntro(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.lg),
      Image.asset(
        'assets/ai/hero_highlights.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text(
        'Highlights Finder',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'Find the most useful moments from this episode in seconds.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Highlight type',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      for (final option in const [
        (0, 'Key Insights'),
        (1, 'Inspiring Quotes'),
        (2, 'Actionable Tips'),
        (3, 'All Highlights'),
      ])
        RadioListTile<int>(
          contentPadding: EdgeInsets.zero,
          value: option.$1,
          groupValue: _highlightType,
          activeColor: PelevoColors.green,
          title: Text(option.$2),
          onChanged: (value) => setState(() => _highlightType = value ?? 0),
        ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: 'Find Highlights',
        color: PelevoColors.green,
        onPressed: _busy
            ? null
            : () => _startJob(
                context,
                type: 'highlights',
                resultRoute: '/screen/ai-history',
              ),
      ),
    ],
  );

  Widget _highlightsResult(BuildContext context) {
    final notice = ref.watch(aiNoticeProvider);
    final jobId = ref.watch(selectedAiJobIdProvider);
    final jobAsync = jobId == null || jobId.isEmpty ? null : ref.watch(aiJobProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _episodeHeader(context),
        const SizedBox(height: PelevoSpacing.md),
        if (notice != null) Text(notice),
        if (jobAsync == null && notice == null)
          const Text(
            'Find highlights from the selected episode.',
            style: TextStyle(color: PelevoColors.textMuted),
          )
        else if (jobAsync != null && jobAsync.isLoading)
          const CatalogStatusBody()
        else if (jobAsync != null && jobAsync.hasError)
          CatalogStatusBody(
            error: jobAsync.error,
            retry: () => ref.invalidate(aiJobProvider),
          )
        else if (jobAsync != null)
          _jobBody(jobAsync.requireValue)
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _askIntro(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Image.asset(
          'assets/ai/hero_ask.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Center(
        child:         Text(
          'Ask Pelevo',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const SizedBox(height: PelevoSpacing.sm),
      const Text(
        'Describe what you want to hear. Pelevo recommends shows from your interests, listening history, and the context of your request.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PelevoColors.textMuted),
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        'Suggested Questions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      for (final q in const [
        'Summarize this episode',
        'Something thoughtful about growth',
        'A short show I can finish today',
        'Niche stories I would not search for by name',
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.help_outline_rounded,
            color: PelevoColors.blue,
          ),
          title: Text(q),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _openAskResult(context, q),
        ),
      const SizedBox(height: PelevoSpacing.lg),
      TextField(
        controller: _askController,
        decoration: InputDecoration(
          hintText: 'Ask a question…',
          suffixIcon: IconButton(
            tooltip: 'Send question',
            onPressed: () {
              final text = _askController.text.trim();
              if (text.isEmpty) return;
              _openAskResult(context, text);
            },
            icon: const Icon(Icons.send_rounded, color: PelevoColors.green),
          ),
        ),
      ),
    ],
  );

  Widget _askAnswer(BuildContext context) {
    final question = ref.watch(selectedAiQuestionProvider);
    final async = ref.watch(aiAskProvider(question));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: PelevoSpacing.md),
            padding: const EdgeInsets.all(PelevoSpacing.md),
            decoration: BoxDecoration(
              color: PelevoColors.greenDark,
              borderRadius: BorderRadius.circular(PelevoRadii.large),
            ),
            child: Text(question),
          ),
        ),
        async.when(
          loading: () => const CatalogStatusBody(),
          error:
              (error, _) => CatalogStatusBody(
                error: error,
                retry: () => ref.invalidate(aiAskProvider(question)),
              ),
          data: (conversation) => _pickResults(
            context,
            reply: conversation.reply,
            items: conversation.items,
          ),
        ),
        const SizedBox(height: PelevoSpacing.lg),
        PelevoButton(
          label: 'Ask another question',
          color: PelevoColors.green,
          onPressed: () => context.go('/screen/ai-ask'),
        ),
      ],
    );
  }

  Widget _lineup(BuildContext context) {
    final async = ref.watch(aiLineupProvider);
    return async.when(
      loading: () => const CatalogStatusBody(),
      error:
          (error, _) => CatalogStatusBody(
            error: error,
            retry: () => ref.invalidate(aiLineupProvider),
          ),
      data: (lineup) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lineup.weekLabel,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PelevoSpacing.sm),
          Text(lineup.intro, style: const TextStyle(color: PelevoColors.textMuted)),
          const SizedBox(height: PelevoSpacing.lg),
          if (lineup.items.isEmpty)
            const Text(
              'Your lineup will appear after you listen to a few shows.',
              style: TextStyle(color: PelevoColors.textMuted),
            )
          else
            for (final item in lineup.items) _pickTile(context, item),
        ],
      ),
    );
  }

  Widget _pickResults(
    BuildContext context, {
    required String reply,
    required List<AiPick> items,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PelevoSpacing.md),
        decoration: BoxDecoration(
          color: PelevoColors.surface,
          borderRadius: BorderRadius.circular(PelevoRadii.large),
        ),
        child: Text(reply),
      ),
      const SizedBox(height: PelevoSpacing.md),
      if (items.isEmpty)
        const Text(
          'No matching shows yet. Try describing a topic or mood.',
          style: TextStyle(color: PelevoColors.textMuted),
        )
      else
        for (final item in items) _pickTile(context, item),
    ],
  );

  Widget _pickTile(BuildContext context, AiPick item) => Card(
    color: PelevoColors.surface,
    margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
    child: ListTile(
      leading: CatalogArtwork(
        url: item.artworkUrl,
        width: 52,
        height: 52,
        assetPath: 'assets/ai/rec_deep.png',
      ),
      title: Text(item.title),
      subtitle: Text(item.reason ?? item.showTitle ?? ''),
      isThreeLine: item.reason != null && item.reason!.isNotEmpty,
      onTap: () {
        final showId = item.showId;
        if (showId != null && showId.isNotEmpty) {
          openCatalogShow(context, showId);
          context.go('/screen/podcast-details');
        }
      },
    ),
  );

  Widget _settings(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('AI Preferences', style: Theme.of(context).textTheme.titleLarge),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Summary Length'),
        subtitle: Text(const ['Short', 'Medium', 'Detailed'][_summaryLength]),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => setState(() => _summaryLength = (_summaryLength + 1) % 3),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Default Chapter Style'),
        subtitle: Text(const ['Detailed', 'Balanced', 'Brief'][_chapterStyle]),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => setState(() => _chapterStyle = (_chapterStyle + 1) % 3),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Highlight Type'),
        subtitle: Text(
          const [
            'Key Insights',
            'Inspiring Quotes',
            'Actionable Tips',
            'All Highlights',
          ][_highlightType],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => setState(() => _highlightType = (_highlightType + 1) % 4),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text('Data & Privacy', style: Theme.of(context).textTheme.titleLarge),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.delete_outline_rounded,
          color: PelevoColors.red,
        ),
        title: const Text('Clear AI History'),
        onTap: () => context.showPelevoMessage(
          'Job history cannot be cleared. There is no list or delete jobs API.',
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline_rounded),
        title: const Text('Learn how AI works'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap:
            () => showDialog<void>(
              context: context,
              builder:
                  (dialogContext) => AlertDialog(
                    title: const Text('How Pelevo AI works'),
                    content: const Text(
                      'Ask Pelevo and Your Podcast Lineup recommend shows from your listening history and what you describe. '
                      'Summary and chapters still queue a job when that tool is enabled on the server.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
            ),
      ),
      const SizedBox(height: PelevoSpacing.lg),
      Text('About', style: Theme.of(context).textTheme.titleLarge),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('AI Hub Beta'),
        subtitle: Text('Queued jobs only'),
      ),
    ],
  );

  Widget _episodeHeader(BuildContext context) {
    final episodeId = ref.watch(selectedEpisodeIdProvider);
    final episode =
        episodeId == null || episodeId.isEmpty
            ? null
            : ref.watch(catalogEpisodeProvider).asData?.value;
    return Row(
      children: [
        CatalogArtwork(
          url: episode?.artworkUrl,
          width: 56,
          height: 56,
          assetPath: 'assets/ai/episode_thumb.png',
        ),
        const SizedBox(width: PelevoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode?.title ?? 'No episode selected',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                [
                  episode?.showTitle,
                  if (episode?.durationSeconds != null)
                    formatCatalogDuration(episode!.durationSeconds!),
                ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
                style: const TextStyle(color: PelevoColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _jobBody(AiJob job, {bool takeaways = false}) {
    if (job.state == 'failed' || job.state == 'safety_review') {
      return Text(
        job.outputText ?? 'This ${job.type} could not be generated.',
        style: const TextStyle(color: PelevoColors.textMuted, height: 1.45),
      );
    }
    if (job.queued) {
      return Text(
        'This ${job.type} job is ${job.state}.',
        style: const TextStyle(color: PelevoColors.textMuted, height: 1.45),
      );
    }
    if (takeaways) {
      if (job.takeaways.isEmpty) {
        return const Text(
          'Key takeaways are not returned as a list.',
          style: TextStyle(color: PelevoColors.textMuted, height: 1.45),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in job.takeaways)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $item', style: const TextStyle(height: 1.45)),
            ),
        ],
      );
    }
    if (!job.completed || job.outputText == null || job.outputText!.isEmpty) {
      return Text(
        'No ${job.type} text is available yet.',
        style: const TextStyle(color: PelevoColors.textMuted, height: 1.45),
      );
    }
    return Text(
      job.outputText!,
      style: const TextStyle(color: PelevoColors.textMuted, height: 1.45),
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _summaryTab == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: PelevoColors.green,
      onSelected: (_) => setState(() => _summaryTab = index),
    );
  }

  Widget _toolTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .18),
      child: Icon(icon, color: color),
    ),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );

  void _openAskResult(BuildContext context, String question) {
    ref.read(selectedAiQuestionProvider.notifier).set(question);
    context.go('/screen/ai-result');
  }

  Future<void> _startJob(
    BuildContext context, {
    required String type,
    required String resultRoute,
  }) async {
    final episodeId = ref.read(selectedEpisodeIdProvider);
    if (episodeId == null || episodeId.isEmpty) {
      context.showPelevoMessage('Select an episode first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final job = await ref.read(aiRepositoryProvider).createJob(
        type: type,
        input: {
          'episode_id': episodeId,
          if (type == 'summary')
            'length': const ['short', 'medium', 'detailed'][_summaryLength],
          if (type == 'chapters')
            'style': const ['detailed', 'balanced', 'brief'][_chapterStyle],
          if (type == 'highlights')
            'focus': const ['insights', 'quotes', 'tips', 'all'][_highlightType],
        },
      );
      ref.read(aiNoticeProvider.notifier).set(null);
      ref.read(selectedAiJobIdProvider.notifier).select(job.id);
      if (context.mounted) context.go(resultRoute);
    } on ApiFailure catch (error) {
      ref.read(selectedAiJobIdProvider.notifier).select(null);
      ref.read(aiNoticeProvider.notifier).set(error.message);
      if (context.mounted) context.go(resultRoute);
    } catch (error) {
      if (context.mounted) {
        context.showPelevoMessage(catalogFailure(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
