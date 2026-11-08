import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/config/app_config.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/player/pelevo_mini_player.dart';
import 'package:pelevo/features/reels/reel_player.dart';

final pelevoRouteObserver = RouteObserver<ModalRoute<void>>();

/// Network artwork that avoids Flutter Web decode failures when CDNs omit CORS.
///
/// On web, [CachedNetworkImage] fetches bytes via XHR (needs CORS). Many podcast
/// CDNs (e.g. assets.pippa.io) serve valid JPEGs without ACAO headers, which
/// surfaces as `EncodingError: The source image cannot be decoded`. HTML `<img>`
/// display does not require CORS, so web uses [Image.network] with
/// [WebHtmlElementStrategy.prefer] and explicit width/height.
class PelevoNetworkArt extends StatelessWidget {
  const PelevoNetworkArt({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (_, _, _) => fallback,
      );
    }

    Widget image({required double w, required double h}) => Image.network(
      url,
      width: w,
      height: h,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, _, _) => SizedBox(width: w, height: h, child: fallback),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: w,
          height: h,
          child: ColoredBox(color: context.pelevo.surfaceHigh),
        );
      },
    );

    if (width != null && height != null) {
      return image(w: width!, h: height!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w =
            width ??
            (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 1.0);
        final h =
            height ??
            (constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 1.0);
        return image(w: w, h: h);
      },
    );
  }
}

class PelevoBackButton extends StatelessWidget {
  const PelevoBackButton({super.key, this.fallback});

  final String? fallback;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => context.pelevoBack(fallback: fallback),
    icon: const Icon(Icons.arrow_back_rounded),
  );
}

class PelevoPage extends ConsumerWidget {
  const PelevoPage({
    required this.child,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.symmetric(horizontal: PelevoSpacing.page),
    this.scrollable = true,
    this.showMiniPlayer = true,
    this.safeArea = true,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final bool showMiniPlayer;
  final bool safeArea;
  final bool extendBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedBar = withPelevoNavigationLeading(context, appBar);
    final body = Padding(padding: padding, child: child);
    Widget? chrome = bottomNavigationBar;
    if (chrome != null && showMiniPlayer) {
      chrome = Column(
        mainAxisSize: MainAxisSize.min,
        children: [const PelevoMiniPlayer(), chrome],
      );
    }
    final isRoot = isPelevoNavigationRoot(context);
    final leaveApp = isPelevoTabRoot(context);
    final content =
        scrollable
            ? SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: PelevoSpacing.xxl),
              child: body,
            )
            : body;
    return PopScope(
      canPop: !isRoot && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) return;
        if (leaveApp) {
          confirmPelevoExit(context);
          return;
        }
        if (isRoot) return;
        context.pelevoBack();
      },
      child: Scaffold(
        extendBody: extendBody,
        backgroundColor: context.pelevo.background,
        appBar: resolvedBar,
        bottomNavigationBar: chrome,
        body:
            safeArea
                ? SafeArea(top: resolvedBar == null, child: content)
                : content,
      ),
    );
  }
}

class PelevoButton extends StatelessWidget {
  const PelevoButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.color = PelevoColors.red,
    this.foregroundColor = Colors.white,
    this.outlined = false,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foregroundColor;
  final bool outlined;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ink = outlined && foregroundColor == Colors.white
        ? color
        : foregroundColor;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PelevoRadii.small),
        ),
      ),
      foregroundColor: WidgetStatePropertyAll(ink),
      backgroundColor: outlined ? null : WidgetStatePropertyAll(color),
      side: outlined
          ? WidgetStatePropertyAll(BorderSide(color: color, width: 1.5))
          : null,
    );
    final child =
        icon == null && !loading
            ? Text(label, textAlign: TextAlign.center)
            : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: ink,
                    ),
                  )
                else
                  Icon(icon, size: 20),
                const SizedBox(width: PelevoSpacing.sm),
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            );
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child:
            outlined
                ? OutlinedButton(
                  onPressed: onPressed,
                  style: style,
                  child: child,
                )
                : FilledButton(
                  onPressed: onPressed,
                  style: style,
                  child: child,
                ),
      ),
    );
  }
}

class PelevoSectionHeader extends StatelessWidget {
  const PelevoSectionHeader({
    required this.title,
    super.key,
    this.onSeeAll,
    this.trailing = 'See All',
  });

  final String title;
  final String trailing;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (onSeeAll != null)
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            trailing,
            style: const TextStyle(color: PelevoColors.green),
          ),
        ),
    ],
  );
}

class PelevoArtwork extends StatelessWidget {
  const PelevoArtwork({
    required this.label,
    super.key,
    this.size = 72,
    this.color = PelevoColors.red,
    this.icon = Icons.podcasts_rounded,
    this.borderRadius = PelevoRadii.medium,
  });

  final String label;
  final double size;
  final Color color;
  final IconData icon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '$label artwork',
    child: RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: .95), Colors.black],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: .2),
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Icon(icon, size: size * .42, color: Colors.white),
      ),
    ),
  );
}

class PelevoEpisodeTile extends StatelessWidget {
  const PelevoEpisodeTile({
    required this.title,
    required this.subtitle,
    super.key,
    this.rank,
    this.trailing = Icons.play_circle_fill_rounded,
    this.color = PelevoColors.red,
    this.assetPath,
    this.artworkUrl,
    this.onTap,
    this.onPlay,
    this.onQueue,
  });

  final String title;
  final String subtitle;
  final int? rank;
  final IconData trailing;
  final Color color;
  final String? assetPath;
  final String? artworkUrl;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onQueue;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: PelevoSpacing.xs,
    leading: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank != null) ...[
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: PelevoColors.yellow,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: PelevoSpacing.xs),
        ],
        if (artworkUrl != null && artworkUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(PelevoRadii.small),
            child: PelevoNetworkArt(
              url: artworkUrl!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              fallback: PelevoArtwork(label: title, size: 52, color: color),
            ),
          )
        else if (assetPath == null)
          PelevoArtwork(label: title, size: 52, color: color)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(PelevoRadii.small),
            child: Image.asset(
              assetPath!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
      ],
    ),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onQueue != null)
          IconButton(
            tooltip: 'Add $title to queue',
            onPressed: onQueue,
            icon: const Icon(Icons.playlist_add_rounded, size: 24),
          ),
        if (onPlay == null)
          Icon(trailing, size: 24)
        else
          IconButton(
            tooltip: 'Play $title',
            onPressed: onPlay,
            icon: Icon(trailing, size: 24),
          ),
      ],
    ),
  );
}

class PelevoStateHero extends StatelessWidget {
  const PelevoStateHero({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.color = PelevoColors.green,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: PelevoSpacing.xl),
      Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .22), blurRadius: 28),
          ],
        ),
        child: Icon(icon, size: 54, color: color),
      ).animate().scale(
        begin: const Offset(.8, .8),
        duration: PelevoMotion.normal,
        curve: Curves.easeOutBack,
      ),
      const SizedBox(height: PelevoSpacing.xl),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: PelevoSpacing.sm),
      Text(
        body,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.pelevo.textMuted),
      ),
    ],
  );
}

class PelevoBottomNavigation extends ConsumerWidget {
  const PelevoBottomNavigation({
    this.index,
    this.selectedRoute,
    required this.onDestinationSelected,
    super.key,
  }) : assert(
         index != null || selectedRoute != null,
         'Provide index or selectedRoute',
       );

  final int? index;
  final String? selectedRoute;
  final ValueChanged<int> onDestinationSelected;

  static List<
    ({String label, IconData icon, IconData selectedIcon, String route})
  >
  tabsFor(AppConfig? config) {
    // Earn stays wired for a future relaunch; muted from the bar until earn_enabled.
    final earnEnabled = config?.enabled('earn_enabled') ?? false;
    return [
      (
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        route: '/screen/home-feed',
      ),
      (
        label: 'Search',
        icon: Icons.search_rounded,
        selectedIcon: Icons.search_rounded,
        route: '/screen/search',
      ),
      (
        label: 'Library',
        icon: Icons.library_books_outlined,
        selectedIcon: Icons.library_books_rounded,
        route: '/screen/library-1',
      ),
      if (earnEnabled)
        (
          label: 'Earn',
          icon: Icons.payments_outlined,
          selectedIcon: Icons.payments_rounded,
          route: '/screen/earn',
        ),
      (
        label: 'Reels',
        icon: Icons.movie_creation_outlined,
        selectedIcon: Icons.movie_rounded,
        route: '/screen/reels',
      ),
      (
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        route: '/screen/profile',
      ),
    ];
  }

  static int indexForRoute(AppConfig? config, String route) {
    final index = tabsFor(config).indexWhere((tab) => tab.route == route);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).asData?.value;
    final tabs = tabsFor(config);
    final resolved =
        selectedRoute != null
            ? indexForRoute(config, selectedRoute!)
            : (index ?? 0);
    final selected = resolved.clamp(0, tabs.length - 1);
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: context.pelevo.background,
          border: Border(top: BorderSide(color: context.pelevo.border)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _PelevoNavItem(
                  destination: _PelevoNavDestination(
                    label: tabs[i].label,
                    icon: tabs[i].icon,
                    selectedIcon: tabs[i].selectedIcon,
                  ),
                  selected: selected == i,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PelevoNavDestination {
  const _PelevoNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _PelevoNavItem extends StatelessWidget {
  const _PelevoNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _PelevoNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.pelevo.text : context.pelevo.textDim;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: 24,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> showPelevoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled || heightFactor != null,
    backgroundColor: context.pelevo.surface,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) {
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      Widget child = builder(context);
      if (heightFactor != null) {
        child = FractionallySizedBox(heightFactor: heightFactor, child: child);
      }
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(top: false, child: child),
      );
    },
  );
}

bool isPelevoTabRoot(BuildContext context) {
  final path = pelevoRouterPath(context);
  if (path == null) return false;
  final config =
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appConfigProvider).asData?.value;
  return PelevoBottomNavigation.tabsFor(config).any((tab) => tab.route == path);
}

var _pelevoExitPromptOpen = false;

Future<void> confirmPelevoExit(BuildContext context) async {
  if (_pelevoExitPromptOpen) return;
  _pelevoExitPromptOpen = true;
  try {
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Leave Pelevo?'),
            content: const Text('You can keep using the app, or exit.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Exit'),
              ),
            ],
          ),
    );
    if (leave == true) {
      await SystemNavigator.pop();
    }
  } finally {
    _pelevoExitPromptOpen = false;
  }
}

/// Path of the current GoRouter page.
///
/// A raw [MaterialPageRoute] has no [GoRouterState]. Calling
/// [GoRouterState.of] there throws and the route paints as a blank screen.
String? pelevoRouterPath(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  final route = ModalRoute.of(context);
  if (route == null || route.settings is! Page<Object?>) return null;
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    return null;
  }
}

bool isPelevoNavigationRoot(BuildContext context) {
  final path = pelevoRouterPath(context);
  if (path == null) return GoRouter.maybeOf(context) == null;
  if (path == '/screen/splash' ||
      path.startsWith('/screen/onboarding-') ||
      path == '/screen/auth-sign-in' ||
      path == '/screen/auth-account-created') {
    return true;
  }
  final config =
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appConfigProvider).asData?.value;
  return PelevoBottomNavigation.tabsFor(config).any((tab) => tab.route == path);
}

String pelevoFallbackFor(String path) {
  final id = path.startsWith('/screen/') ? path.substring(8) : path;
  if (id.startsWith('library-')) {
    if (id == 'library-3') return '/screen/library-2';
    if (id == 'library-10' || id == 'library-11') return '/screen/library-9';
    return '/screen/library-1';
  }
  if (id.startsWith('downloads-')) {
    return id == 'downloads-1' ? '/screen/library-5' : '/screen/downloads-1';
  }
  if (id.startsWith('ai-')) {
    return id == 'ai-hub' ? '/screen/library-1' : '/screen/ai-hub';
  }
  if (id.startsWith('stats-')) {
    return id == 'stats-overview'
        ? '/screen/library-1'
        : '/screen/stats-overview';
  }
  if (id.startsWith('queue-')) {
    return (id == 'queue-up-next' || id == 'queue-empty')
        ? '/screen/library-1'
        : '/screen/queue-up-next';
  }
  if (id.startsWith('notifications-')) {
    return id == 'notifications-1'
        ? '/screen/library-1'
        : '/screen/notifications-1';
  }
  if (id.startsWith('permissions-')) return '/screen/library-1';
  if (id.startsWith('browse')) {
    if (id == 'browse' || id == 'browse-search') return '/screen/search';
    if (id == 'browse-filters') return '/screen/browse-search';
    if (id == 'browse-detail' ||
        id == 'browse-music' ||
        id == 'browse-preview') {
      return '/screen/browse-categories';
    }
    return '/screen/browse';
  }
  if (id.startsWith('home-')) return '/screen/home-feed';
  if (id.startsWith('search-')) return '/screen/search';
  if (id.startsWith('podcast-')) return '/screen/search';
  if (id.startsWith('episode-') || id.startsWith('player-')) {
    return '/screen/home-feed';
  }
  if (id == 'profile' ||
      id.startsWith('profile-') ||
      id.startsWith('settings')) {
    return '/screen/home-feed';
  }
  if (id.startsWith('device-sync') || id.startsWith('sync-')) {
    return '/screen/home-feed';
  }
  if (id.startsWith('earn-') || id.startsWith('withdraw')) {
    return '/screen/earn';
  }
  if (id.startsWith('reels-') || id.startsWith('creator-')) {
    return '/screen/reels';
  }
  return '/screen/home-feed';
}

PreferredSizeWidget? withPelevoNavigationLeading(
  BuildContext context,
  PreferredSizeWidget? appBar,
) {
  if (appBar is! AppBar ||
      appBar.leading != null ||
      isPelevoNavigationRoot(context)) {
    return appBar;
  }
  final path = pelevoRouterPath(context);
  if (path == null) return appBar;
  return AppBar(
    key: appBar.key,
    leading: PelevoBackButton(
      fallback: pelevoFallbackFor(path),
    ),
    automaticallyImplyLeading: false,
    title: appBar.title,
    actions: appBar.actions,
    bottom: appBar.bottom,
    flexibleSpace: appBar.flexibleSpace,
    backgroundColor: appBar.backgroundColor,
    foregroundColor: appBar.foregroundColor,
    elevation: appBar.elevation,
    scrolledUnderElevation: appBar.scrolledUnderElevation,
    shadowColor: appBar.shadowColor,
    surfaceTintColor: appBar.surfaceTintColor,
    centerTitle: appBar.centerTitle,
    titleSpacing: appBar.titleSpacing,
    toolbarHeight: appBar.toolbarHeight,
    leadingWidth: appBar.leadingWidth,
  );
}

extension Snackbars on BuildContext {
  /// Pops the current route when possible; otherwise goes to [fallback].
  void pelevoBack({String? fallback}) {
    if (canPop()) {
      pop();
      return;
    }
    final path = pelevoRouterPath(this) ?? '/screen/home-feed';
    go(fallback ?? pelevoFallbackFor(path));
  }

  /// Pushes nested screens so the system/AppBar back button can return.
  /// Tab roots still replace the stack with [go].
  void pelevoOpen(String location) {
    final parsed = Uri.parse(location);
    final config =
        ProviderScope.containerOf(this).read(appConfigProvider).asData?.value;
    final isTab = PelevoBottomNavigation.tabsFor(
      config,
    ).any((tab) => tab.route == parsed.path);
    if (isTab) {
      go(location);
      return;
    }
    push(location);
  }

  void openPelevoTab(int index) {
    final config =
        ProviderScope.containerOf(this).read(appConfigProvider).asData?.value;
    final tabs = PelevoBottomNavigation.tabsFor(config);
    if (index < 0 || index >= tabs.length) return;
    ReelPlayback.halt();
    go(tabs[index].route);
  }

  void showPelevoMessage(String message) {
    final trimmed = message.trim();
    // Auto-dispose CancelTokens surface this when navigating; never toast it.
    if (trimmed.isEmpty || trimmed == 'Request cancelled.') return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          trimmed,
          style: TextStyle(color: pelevo.text),
        ),
        backgroundColor: pelevo.border,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

typedef PelevoSelectOption = ({String value, String label});

/// Form-style field that opens a searchable bottom sheet of options.
class SearchableSelectField extends StatelessWidget {
  const SearchableSelectField({
    required this.options,
    required this.onSelected,
    required this.hint,
    required this.searchHint,
    required this.sheetTitle,
    this.valueLabel,
    this.enabled = true,
    super.key,
  });

  final List<PelevoSelectOption> options;
  final ValueChanged<String> onSelected;
  final String hint;
  final String searchHint;
  final String sheetTitle;
  final String? valueLabel;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SearchableSelectSheet(
        title: sheetTitle,
        searchHint: searchHint,
        options: options,
      ),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final label = valueLabel?.trim();
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(PelevoRadii.medium),
      child: InputDecorator(
        isEmpty: label == null || label.isEmpty,
        decoration: InputDecoration(
          hintText: hint,
          enabled: enabled,
          suffixIcon: Icon(
            Icons.search_rounded,
            color: enabled ? context.pelevo.textMuted : context.pelevo.border,
          ),
        ),
        child:
            label == null || label.isEmpty
                ? null
                : Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SearchableSelectSheet extends StatefulWidget {
  const _SearchableSelectSheet({
    required this.title,
    required this.searchHint,
    required this.options,
  });

  final String title;
  final String searchHint;
  final List<PelevoSelectOption> options;

  @override
  State<_SearchableSelectSheet> createState() => _SearchableSelectSheetState();
}

class _SearchableSelectSheetState extends State<_SearchableSelectSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.text.trim().toLowerCase();
    final filtered =
        needle.isEmpty
            ? widget.options
            : widget.options
                .where((option) => option.label.toLowerCase().contains(needle))
                .toList(growable: false);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  filtered.isEmpty
                      ? Center(
                        child: Text(
                          'No matches',
                          style: TextStyle(color: context.pelevo.textMuted),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          return ListTile(
                            title: Text(option.label),
                            onTap: () => Navigator.of(context).pop(option.value),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
