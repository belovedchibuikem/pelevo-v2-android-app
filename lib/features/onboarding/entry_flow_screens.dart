import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/config/app_config.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/authentication_screens.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/creator_audience_screens.dart';
import 'package:pelevo/features/creator/creator_content_screens.dart';
import 'package:pelevo/features/creator/creator_management_screens.dart';
import 'package:pelevo/features/creator/creator_monetization_screens.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/creator/podcast_claim_screens.dart';
import 'package:pelevo/features/earn/earn_screens.dart';
import 'package:pelevo/features/earn/withdrawal_screens.dart';
import 'package:pelevo/features/comments/comment_screens.dart';
import 'package:pelevo/features/gifts/gift_screens.dart';
import 'package:pelevo/features/home/home_screens.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/onboarding/onboarding_data.dart';
import 'package:pelevo/features/onboarding/onboarding_progress.dart';
import 'package:pelevo/features/notifications/notification_router.dart';
import 'package:pelevo/features/notifications/firebase_push.dart';
import 'package:pelevo/features/permissions/permission_screens.dart';
import 'package:pelevo/features/profile/profile_screens.dart';
import 'package:pelevo/features/profile/profile_support_screens.dart';
import 'package:pelevo/features/reels/create_reel_screens.dart';
import 'package:pelevo/features/reels/reels_monetization_screens.dart';
import 'package:pelevo/features/reels/reels_monetization_service.dart';
import 'package:pelevo/features/reels/reels_screens.dart';
import 'package:pelevo/features/reels/creator_public_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> entryFlowScreens = [
  const PelevoScreenSpec(
    id: 'splash',
    section: 'Onboarding & Splash',
    title: 'Splash',
    builder: _buildSplash,
  ),
  const PelevoScreenSpec(
    id: 'onboarding-personalized',
    section: 'Onboarding & Splash',
    title: 'Podcasts Built Around You',
    state: 'Feature 1',
    builder: _buildPersonalized,
  ),
  const PelevoScreenSpec(
    id: 'onboarding-language',
    section: 'Onboarding & Splash',
    title: 'Listen In Your Language',
    state: 'Feature 2',
    builder: _buildLanguage,
  ),
  const PelevoScreenSpec(
    id: 'onboarding-ai',
    section: 'Onboarding & Splash',
    title: 'AI Powered Discovery',
    state: 'Feature 3',
    builder: _buildAi,
  ),
  const PelevoScreenSpec(
    id: 'onboarding-community',
    section: 'Onboarding & Splash',
    title: 'Your World, Your Networks',
    state: 'Feature 4',
    builder: _buildCommunity,
  ),
  const PelevoScreenSpec(
    id: 'onboarding-interests',
    section: 'Onboarding & Splash',
    title: 'Interests & Language',
    builder: _buildInterests,
  ),
  const PelevoScreenSpec(
    id: 'auth-sign-in',
    section: 'Authentication',
    title: 'Welcome Back',
    builder: _buildSignIn,
  ),
  const PelevoScreenSpec(
    id: 'auth-create-account',
    section: 'Authentication',
    title: 'Create Account',
    builder: _buildCreateAccount,
  ),
  const PelevoScreenSpec(
    id: 'auth-verify-number',
    section: 'Authentication',
    title: 'Verify Your Number',
    builder: _buildVerifyNumber,
  ),
  const PelevoScreenSpec(
    id: 'auth-account-created',
    section: 'Authentication',
    title: 'Account Created',
    builder: _buildAccountCreated,
  ),
  const PelevoScreenSpec(
    id: 'auth-options',
    section: 'Authentication',
    title: 'Sign In Options',
    builder: _buildSignInOptions,
  ),
  const PelevoScreenSpec(
    id: 'auth-forgot-password',
    section: 'Authentication',
    title: 'Forgot Password',
    builder: _buildForgotPassword,
  ),
  const PelevoScreenSpec(
    id: 'auth-check-email',
    section: 'Authentication',
    title: 'Check Your Email',
    builder: _buildCheckEmail,
  ),
  const PelevoScreenSpec(
    id: 'permissions-intro',
    section: 'Permissions',
    title: 'Permission Intro',
    builder: _buildPermissionIntro,
  ),
  const PelevoScreenSpec(
    id: 'permissions-notifications',
    section: 'Permissions',
    title: 'Stay in the Loop',
    state: 'Notifications',
    builder: _buildNotificationsPermission,
  ),
  const PelevoScreenSpec(
    id: 'permissions-microphone',
    section: 'Permissions',
    title: 'Voice Search',
    state: 'Microphone',
    builder: _buildMicrophonePermission,
  ),
  const PelevoScreenSpec(
    id: 'permissions-storage',
    section: 'Permissions',
    title: 'Downloads',
    state: 'Storage access',
    builder: _buildStoragePermission,
  ),
  const PelevoScreenSpec(
    id: 'permissions-background',
    section: 'Permissions',
    title: 'Background Playback',
    builder: _buildBackgroundPermission,
  ),
  const PelevoScreenSpec(
    id: 'permissions-devices',
    section: 'Permissions',
    title: 'Connect Devices',
    state: 'Nearby devices',
    builder: _buildDevicesPermission,
  ),
  const PelevoScreenSpec(
    id: 'permissions-complete',
    section: 'Permissions',
    title: 'All Set',
    builder: _buildPermissionsComplete,
  ),
  const PelevoScreenSpec(
    id: 'home-feed',
    section: 'Home / Discover',
    title: 'Home',
    builder: _buildHome,
  ),
  const PelevoScreenSpec(
    id: 'home-discover',
    section: 'Home / Discover',
    title: 'Discover',
    builder: _buildDiscover,
  ),
  const PelevoScreenSpec(
    id: 'home-charts',
    section: 'Home / Discover',
    title: 'Charts',
    builder: _buildCharts,
  ),
  const PelevoScreenSpec(
    id: 'home-playlists',
    section: 'Home / Discover',
    title: 'Playlists & More',
    builder: _buildPlaylists,
  ),
  const PelevoScreenSpec(
    id: 'profile',
    section: 'Profile & Settings',
    title: 'Profile',
    builder: _buildProfile,
  ),
  ...creatorStudioScreens,
  ...podcastClaimScreens,
  ...creatorContentScreens,
  ...creatorMonetizationScreens,
  ...creatorAudienceScreens,
  ...creatorManagementScreens,
  ...giftScreens,
  ...commentScreens,
  const PelevoScreenSpec(
    id: 'settings-account',
    section: 'Profile & Settings',
    title: 'Settings & Account',
    builder: _buildSettingsAccount,
  ),
  const PelevoScreenSpec(
    id: 'reels',
    section: 'Reels',
    title: 'Reels For You',
    builder: _buildReels,
  ),
  const PelevoScreenSpec(
    id: 'saved-reels',
    section: 'Reels',
    title: 'Saved Reels',
    builder: _buildSavedReels,
  ),
  const PelevoScreenSpec(
    id: 'reels-create',
    section: 'Reels',
    title: 'Create Reel',
    builder: _buildReelsCreate,
  ),
  const PelevoScreenSpec(
    id: 'reels-record',
    section: 'Reels',
    title: 'Record Reel',
    builder: _buildReelsRecord,
  ),
  const PelevoScreenSpec(
    id: 'reels-upload',
    section: 'Reels',
    title: 'Upload Reel',
    builder: _buildReelsUpload,
  ),
  const PelevoScreenSpec(
    id: 'reels-drafts',
    section: 'Reels',
    title: 'Reel Drafts',
    builder: _buildReelsDrafts,
  ),
  const PelevoScreenSpec(
    id: 'reels-editor',
    section: 'Reels',
    title: 'Edit Reel',
    builder: _buildReelsEditor,
  ),
  const PelevoScreenSpec(
    id: 'reels-monetization',
    section: 'Reels',
    title: 'Reels Monetization',
    builder: _buildReelsMonetization,
  ),
  const PelevoScreenSpec(
    id: 'reels-monetization-progress',
    section: 'Reels',
    title: 'Reels Monetization Progress',
    builder: _buildReelsMonetizationProgress,
  ),
  const PelevoScreenSpec(
    id: 'reels-monetization-eligible',
    section: 'Reels',
    title: 'Reels Monetization Eligible',
    builder: _buildReelsMonetizationEligible,
  ),
  const PelevoScreenSpec(
    id: 'reels-monetization-active',
    section: 'Reels',
    title: 'Reels Monetization Active',
    builder: _buildReelsMonetizationActive,
  ),
  const PelevoScreenSpec(
    id: 'creator-profile',
    section: 'Reels',
    title: 'Creator Profile',
    builder: _buildCreatorProfile,
  ),
  const PelevoScreenSpec(
    id: 'creator-stories',
    section: 'Reels',
    title: 'Creator Reels',
    builder: _buildCreatorStories,
  ),
  const PelevoScreenSpec(
    id: 'earn',
    section: 'Earn',
    title: 'Earn Monetized Podcasts',
    builder: _buildEarn,
  ),
  const PelevoScreenSpec(
    id: 'earn-all',
    section: 'Earn',
    title: 'All Earn Podcasts',
    builder: _buildEarnAll,
  ),
  const PelevoScreenSpec(
    id: 'earn-player',
    section: 'Earn',
    title: 'Earn Playback',
    builder: _buildEarnPlayer,
  ),
  const PelevoScreenSpec(
    id: 'earn-wallet',
    section: 'Earn',
    title: 'Earn Wallet',
    builder: _buildEarnWallet,
  ),
  const PelevoScreenSpec(
    id: 'withdraw',
    section: 'Earn',
    title: 'Withdraw Earnings',
    builder: _buildWithdraw,
  ),
  const PelevoScreenSpec(
    id: 'withdraw-setup-paypal',
    section: 'Earn',
    title: 'PayPal Setup',
    builder: _buildWithdrawPaypal,
  ),
  const PelevoScreenSpec(
    id: 'withdraw-setup-flutterwave',
    section: 'Earn',
    title: 'Flutterwave Setup',
    builder: _buildWithdrawFlutterwave,
  ),
  const PelevoScreenSpec(
    id: 'withdraw-amount',
    section: 'Earn',
    title: 'Withdrawal Amount',
    builder: _buildWithdrawAmount,
  ),
  const PelevoScreenSpec(
    id: 'withdraw-review',
    section: 'Earn',
    title: 'Review Withdrawal',
    builder: _buildWithdrawReview,
  ),
  const PelevoScreenSpec(
    id: 'withdraw-success',
    section: 'Earn',
    title: 'Withdrawal Queued',
    builder: _buildWithdrawSuccess,
  ),
  const PelevoScreenSpec(
    id: 'withdraw-history',
    section: 'Earn',
    title: 'Withdrawal History',
    builder: _buildWithdrawHistory,
  ),
  const PelevoScreenSpec(
    id: 'profile-edit',
    section: 'Profile & Settings',
    title: 'Edit Profile',
    builder: _buildProfileEdit,
  ),
  const PelevoScreenSpec(
    id: 'profile-following',
    section: 'Profile & Settings',
    title: 'Following',
    builder: _buildProfileFollowing,
  ),
  const PelevoScreenSpec(
    id: 'profile-help',
    section: 'Profile & Settings',
    title: 'Help & Support',
    builder: _buildProfileHelp,
  ),
  const PelevoScreenSpec(
    id: 'profile-invite',
    section: 'Profile & Settings',
    title: 'Invite Friends',
    builder: _buildProfileInvite,
  ),
  const PelevoScreenSpec(
    id: 'profile-about',
    section: 'Profile & Settings',
    title: 'About Pelevo',
    builder: _buildProfileAbout,
  ),
  const PelevoScreenSpec(
    id: 'profile-personal',
    section: 'Profile & Settings',
    title: 'Personal Information',
    builder: _buildProfilePersonal,
  ),
  const PelevoScreenSpec(
    id: 'profile-password',
    section: 'Profile & Settings',
    title: 'Change Password',
    builder: _buildProfilePassword,
  ),
  const PelevoScreenSpec(
    id: 'profile-email',
    section: 'Profile & Settings',
    title: 'Email Preferences',
    builder: _buildProfileEmail,
  ),
  const PelevoScreenSpec(
    id: 'profile-connected',
    section: 'Profile & Settings',
    title: 'Connected Accounts',
    builder: _buildProfileConnected,
  ),
];

Widget _buildSplash(BuildContext context) => const SplashScreen();
Widget _buildPersonalized(BuildContext context) =>
    const OnboardingFeatureScreen(
      title: 'Podcasts\nBuilt Around You',
      body: 'Personalized recommendations\nthat match your taste.',
      assetPath: 'assets/onboarding/feature_personalized.png',
      color: PelevoColors.red,
      step: 0,
      nextId: 'onboarding-language',
    );
Widget _buildLanguage(BuildContext context) => const OnboardingFeatureScreen(
  title: 'Listen In\nYour Language',
  body: 'Enjoy podcasts in your\nlanguage and dialect.',
  assetPath: 'assets/onboarding/feature_language.png',
  color: PelevoColors.yellow,
  step: 1,
  nextId: 'onboarding-ai',
);
Widget _buildAi(BuildContext context) => const OnboardingFeatureScreen(
  title: 'AI Powered\nDiscovery',
  body: "Smart AI finds content\nyou'll love.",
  assetPath: 'assets/onboarding/feature_ai.png',
  color: PelevoColors.green,
  step: 2,
  nextId: 'onboarding-community',
);
Widget _buildCommunity(BuildContext context) => const OnboardingFeatureScreen(
  title: 'Your World,\nYour Networks',
  body: 'Follow creators and join\ncommunities that inspire you.',
  assetPath: 'assets/onboarding/feature_community.png',
  color: PelevoColors.red,
  step: 3,
  nextId: 'onboarding-interests',
);
Widget _buildInterests(BuildContext context) => const InterestsScreen();
Widget _buildSignIn(BuildContext context) => const SignInScreen();
Widget _buildCreateAccount(BuildContext context) => const CreateAccountScreen();
Widget _buildVerifyNumber(BuildContext context) => const VerifyNumberScreen();
Widget _buildAccountCreated(BuildContext context) =>
    const AccountCreatedScreen();
Widget _buildSignInOptions(BuildContext context) => const SignInOptionsScreen();
Widget _buildForgotPassword(BuildContext context) =>
    const ForgotPasswordScreen();
Widget _buildCheckEmail(BuildContext context) => const CheckEmailScreen();
Widget _buildPermissionIntro(BuildContext context) =>
    const PermissionIntroScreen();
Widget _buildNotificationsPermission(
  BuildContext context,
) => const PermissionRequestScreen(
  title: 'Stay in the loop',
  body:
      'Turn on notifications to get\nepisode alerts, recommendations,\nand important updates.',
  assetPath: 'assets/permissions/notifications.png',
  allowLabel: 'Allow Notifications',
  permission: PelevoSetupPermission.notifications,
  step: 0,
  previousId: 'permissions-intro',
  nextId: 'permissions-microphone',
);
Widget _buildMicrophonePermission(
  BuildContext context,
) => const PermissionRequestScreen(
  title: 'Voice Search',
  body:
      'Allow microphone access to\nsearch for shows, control\nplayback, and more using\nyour voice.',
  assetPath: 'assets/permissions/microphone.png',
  allowLabel: 'Allow Microphone',
  permission: PelevoSetupPermission.microphone,
  step: 1,
  previousId: 'permissions-notifications',
  nextId: 'permissions-storage',
);
Widget _buildStoragePermission(
  BuildContext context,
) => const PermissionRequestScreen(
  title: 'Downloads',
  body:
      'Downloads are stored privately\non this device. No access to\nyour other files is needed.',
  assetPath: 'assets/permissions/storage.png',
  allowLabel: 'Continue',
  permission: PelevoSetupPermission.storage,
  step: 2,
  previousId: 'permissions-microphone',
  nextId: 'permissions-background',
);
Widget _buildBackgroundPermission(
  BuildContext context,
) => const PermissionRequestScreen(
  title: 'Background Playback',
  body:
      'Keep listening while using other\napps or when your screen is\nturned off.',
  assetPath: 'assets/permissions/background.png',
  allowLabel: 'Allow background playback',
  permission: PelevoSetupPermission.background,
  step: 3,
  previousId: 'permissions-storage',
  nextId: 'permissions-devices',
);
Widget _buildDevicesPermission(
  BuildContext context,
) => const PermissionRequestScreen(
  title: 'Connect Devices',
  body:
      'Connect headphones and speakers over Bluetooth, AirPlay, or Chromecast on the same Wi‑Fi. You can also AirDrop episode links from Share.',
  assetPath: 'assets/permissions/devices.png',
  allowLabel: 'Allow nearby devices',
  permission: PelevoSetupPermission.devices,
  step: 4,
  previousId: 'permissions-background',
  nextId: 'permissions-complete',
);
Widget _buildPermissionsComplete(BuildContext context) =>
    const PermissionsCompleteScreen();
Widget _buildHome(BuildContext context) => const HomeFeedScreen();
Widget _buildDiscover(BuildContext context) => const DiscoverScreen();
Widget _buildCharts(BuildContext context) => const ChartsScreen();
Widget _buildPlaylists(BuildContext context) => const PlaylistsScreen();
Widget _buildProfile(BuildContext context) => const ProfileScreen();
Widget _buildSettingsAccount(BuildContext context) =>
    const SettingsAccountScreen();
Widget _buildReels(BuildContext context) => const ReelsScreen();
Widget _buildSavedReels(BuildContext context) => const SavedReelsScreen();
Widget _buildReelsCreate(BuildContext context) => const CreateReelHubScreen();
Widget _buildReelsRecord(BuildContext context) => const ReelRecordScreen();
Widget _buildReelsUpload(BuildContext context) => const ReelUploadScreen();
Widget _buildReelsDrafts(BuildContext context) => const ReelDraftsScreen();
Widget _buildReelsEditor(BuildContext context) => const ReelEditorScreen();
Widget _buildReelsMonetization(BuildContext context) =>
    const ReelsMonetizationScreen();
Widget _buildReelsMonetizationProgress(BuildContext context) =>
    const ReelsMonetizationScreen(
      forceStage: ReelsMonetizationStage.progressing,
    );
Widget _buildReelsMonetizationEligible(BuildContext context) =>
    const ReelsMonetizationScreen(forceStage: ReelsMonetizationStage.eligible);
Widget _buildReelsMonetizationActive(BuildContext context) =>
    const ReelsMonetizationScreen(forceStage: ReelsMonetizationStage.monetized);
Widget _buildCreatorProfile(BuildContext context) =>
    const PublicCreatorProfileScreen();
Widget _buildCreatorStories(BuildContext context) =>
    const CreatorStoriesScreen();
Widget _buildEarn(BuildContext context) => const EarnHomeScreen();
Widget _buildEarnAll(BuildContext context) => const EarnAllScreen();
Widget _buildEarnPlayer(BuildContext context) => const EarnPlayerScreen();
Widget _buildEarnWallet(BuildContext context) => const EarnWalletScreen();
Widget _buildWithdraw(BuildContext context) => const WithdrawHomeScreen();
Widget _buildWithdrawPaypal(BuildContext context) =>
    const WithdrawSetupPaypalScreen();
Widget _buildWithdrawFlutterwave(BuildContext context) =>
    const WithdrawSetupFlutterwaveScreen();
Widget _buildWithdrawAmount(BuildContext context) =>
    const WithdrawAmountScreen();
Widget _buildWithdrawReview(BuildContext context) =>
    const WithdrawReviewScreen();
Widget _buildWithdrawSuccess(BuildContext context) =>
    const WithdrawSuccessScreen();
Widget _buildWithdrawHistory(BuildContext context) =>
    const WithdrawHistoryScreen();
Widget _buildProfileEdit(BuildContext context) => const ProfileEditScreen();
Widget _buildProfileFollowing(BuildContext context) =>
    const ProfileFollowingScreen();
Widget _buildProfileHelp(BuildContext context) => const ProfileHelpScreen();
Widget _buildProfileInvite(BuildContext context) => const ProfileInviteScreen();
Widget _buildProfileAbout(BuildContext context) => const ProfileAboutScreen();
Widget _buildProfilePersonal(BuildContext context) =>
    const ProfilePersonalInfoScreen();
Widget _buildProfilePassword(BuildContext context) =>
    const ProfileChangePasswordScreen();
Widget _buildProfileEmail(BuildContext context) =>
    const ProfileEmailPreferencesScreen();
Widget _buildProfileConnected(BuildContext context) =>
    const ProfileConnectedAccountsScreen();

bool _stillOnSplash(BuildContext context) {
  try {
    final path = GoRouterState.of(context).uri.path;
    return path == '/screen/splash' || path == '/';
  } on Object {
    return false;
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolveStart();
    });
  }

  Future<void> _resolveStart() async {
    final session = ref.read(authSessionProvider);
    final authenticated =
        await ref.read(authSessionProvider.notifier).bootstrap();
    if (!mounted) return;
    if (authenticated) {
      final destination = await resolveSetupDestination(ref);
      if (!mounted || !_stillOnSplash(context)) return;
      await ref.read(appConfigProvider.notifier).refresh();
      unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
      if (!mounted || !_stillOnSplash(context)) return;
      final pending = PelevoNotificationRouter.consumePending();
      context.go(
        destination == '/screen/home-feed' && pending != null
            ? pending
            : destination,
      );
      return;
    }

    final introductionSeen =
        await ref.read(onboardingProgressStoreProvider).hasSeenIntroduction();
    if (!mounted || !_stillOnSplash(context)) return;
    context.go(
      startupDestination(
        hadStoredSession: session.authenticated,
        authenticated: false,
        introductionSeen: introductionSeen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: context.pelevo.background,
      body: Semantics(
        label: 'Pelevo splash screen. New Africa. Discover the world.',
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _PatternBackground(),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  if (light)
                    const _LightSplashMark()
                  else
                    Image.asset(
                      'assets/onboarding/splash_brand.png',
                      width: 190,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  const Spacer(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingFeatureScreen extends StatelessWidget {
  const OnboardingFeatureScreen({
    required this.title,
    required this.body,
    required this.assetPath,
    required this.color,
    required this.step,
    required this.nextId,
    super.key,
  });

  final String title;
  final String body;
  final String assetPath;
  final Color color;
  final int step;
  final String nextId;

  @override
  Widget build(BuildContext context) => PelevoPage(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/screen/onboarding-interests'),
                child: const Text('Skip'),
              ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            _PortraitIllustration(
              assetPath: assetPath,
              semanticLabel: title.replaceAll('\n', ' '),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            _OnboardingDots(active: step),
            const SizedBox(height: PelevoSpacing.xl),
            PelevoButton(
              label: 'Next',
              color: color,
              foregroundColor:
                  color == PelevoColors.yellow ? Colors.black : Colors.white,
              onPressed: () => context.go('/screen/$nextId'),
            ),
          ],
        ),
      ),
    ),
  );
}

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  static const _interestIcons = {
    'News': Icons.newspaper_rounded,
    'True Crime': Icons.search_rounded,
    'Comedy': Icons.sentiment_very_satisfied_rounded,
    'Business': Icons.business_center_rounded,
    'Health': Icons.favorite_rounded,
    'History': Icons.history_edu_rounded,
    'Technology': Icons.memory_rounded,
    'Sports': Icons.sports_soccer_rounded,
    'Music': Icons.music_note_rounded,
    'Culture': Icons.public_rounded,
    'Education': Icons.school_rounded,
    'Stories': Icons.auto_stories_rounded,
    'Lifestyle': Icons.spa_rounded,
    'Politics': Icons.account_balance_rounded,
    'Science': Icons.science_rounded,
  };

  final Set<String> _selected = {'News', 'Culture', 'Technology'};
  String _language = 'English';
  bool _restored = true;
  bool _continuing = false;
  ApiFailure? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreDraft();
    });
  }

  Future<void> _restoreDraft() async {
    final draft = await ref.read(onboardingProgressStoreProvider).readDraft();
    if (!mounted) return;
    setState(() {
      if (draft != null) {
        _selected
          ..clear()
          ..addAll(draft.interests);
        _language = draft.language;
      }
      _restored = true;
    });
  }

  OnboardingDraft? _draftFromSelection() {
    final locale = localeForOnboardingLanguage(_language);
    if (locale == null || _selected.isEmpty) return null;
    return OnboardingDraft(interests: _selected.toList(), locale: locale);
  }

  Future<void> _continueToSignIn() async {
    if (_continuing || _selected.isEmpty) return;
    final draft = _draftFromSelection();
    if (draft == null) return;
    setState(() {
      _continuing = true;
      _failure = null;
    });
    final store = ref.read(onboardingProgressStoreProvider);
    await store.saveDraft(draft);
    await store.markIntroductionSeen();
    if (!mounted) return;

    if (!ref.read(authSessionProvider).authenticated) {
      if (mounted) context.go('/screen/auth-sign-in');
      return;
    }

    try {
      final result = await ref.read(onboardingRepositoryProvider).submit(draft);
      if (result.userId != ref.read(authSessionProvider).userId) {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message:
              'Your listening preferences could not be confirmed. Please try again.',
        );
      }
      await store.clearDraft();
      if (mounted) context.go('/screen/permissions-intro');
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _continuing = false;
          _failure = apiFailureFromDio(error);
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _continuing = false;
          _failure = error;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _continuing = false;
          _failure = const ApiFailure(
            code: 'UNEXPECTED',
            message: 'Something went wrong. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'What do you love\nlistening to?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PelevoSpacing.xs),
            Text(
              'Choose the podcast types you want. Select all that apply.',
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            LayoutBuilder(
              builder:
                  (context, constraints) => Wrap(
                    spacing: PelevoSpacing.xs,
                    runSpacing: PelevoSpacing.xs,
                    children:
                        onboardingInterestCatalog.map((interest) {
                          final selected = _selected.contains(interest);
                          final ink =
                              selected ? Colors.white : context.pelevo.text;
                          return FilterChip(
                            avatar: Icon(
                              _interestIcons[interest],
                              size: 18,
                              color: ink,
                            ),
                            label: Text(interest),
                            labelStyle: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                            selected: selected,
                            showCheckmark: false,
                            backgroundColor: context.pelevo.surface,
                            selectedColor: PelevoColors.red,
                            side: BorderSide(
                              color:
                                  selected
                                      ? PelevoColors.red
                                      : context.pelevo.text,
                              width: 1.2,
                            ),
                            onSelected:
                                _continuing
                                    ? null
                                    : (value) => setState(() {
                                      value
                                          ? _selected.add(interest)
                                          : _selected.remove(interest);
                                    }),
                          );
                        }).toList(),
                  ),
            ),
            const SizedBox(height: PelevoSpacing.xxl),
            Text(
              'Choose your language',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: PelevoSpacing.xs),
            DropdownButtonFormField<String>(
              key: ValueKey(_language),
              value: _language,
              dropdownColor: context.pelevo.surface,
              style: TextStyle(
                color: context.pelevo.text,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.language_rounded,
                  color: context.pelevo.text,
                ),
              ),
              items:
                  onboardingLanguageCatalog.values
                      .map(
                        (language) => DropdownMenuItem(
                          value: language,
                          child: Text(
                            language,
                            style: TextStyle(color: context.pelevo.text),
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  _continuing
                      ? null
                      : (value) =>
                          setState(() => _language = value ?? _language),
            ),
            const SizedBox(height: PelevoSpacing.xl),
            if (_failure case final failure?)
              Padding(
                padding: const EdgeInsets.only(bottom: PelevoSpacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(PelevoSpacing.sm),
                    decoration: BoxDecoration(
                      color: PelevoColors.red.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(PelevoRadii.small),
                    ),
                    child: Text(
                      failure.requestId == null
                          ? failure.message
                          : '${failure.message}\nReference: ${failure.requestId}',
                      style: const TextStyle(color: PelevoColors.red),
                    ),
                  ),
                ),
              ),
            PelevoButton(
              label: _continuing ? 'Please wait…' : 'Get Started',
              onPressed:
                  !_restored || _selected.isEmpty || _continuing
                      ? null
                      : _continueToSignIn,
            ),
            const SizedBox(height: PelevoSpacing.xs),
            Text(
              'You can change this later',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textDim),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PatternBackground extends StatelessWidget {
  const _PatternBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: .08,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
        ),
        itemBuilder:
            (context, index) => Transform.rotate(
              angle: index.isEven ? .5 : -.5,
              child: Icon(
                Icons.change_history_rounded,
                size: 48,
                color: context.pelevo.text,
              ),
            ),
      ),
    ),
  );
}

class _LightSplashMark extends StatelessWidget {
  const _LightSplashMark();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _KnockoutLogo(
          asset: 'assets/branding/app_icon_foreground.png',
          width: 148,
        ),
        const SizedBox(height: 4),
        Text(
          'pelevo',
          style: TextStyle(
            color: context.pelevo.text,
            fontSize: 46,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'New Africa.',
          style: TextStyle(
            color: PelevoColors.red,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Discover the World.',
          style: TextStyle(
            color: context.pelevo.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 20),
        const _SplashWave(),
      ],
    ),
  );
}

class _SplashWave extends StatelessWidget {
  const _SplashWave();

  static const _bars = <(double, Color)>[
    (7, PelevoColors.red),
    (16, PelevoColors.red),
    (10, PelevoColors.orange),
    (22, PelevoColors.yellow),
    (12, PelevoColors.yellow),
    (18, PelevoColors.green),
    (8, PelevoColors.green),
    (14, PelevoColors.green),
  ];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (final bar in _bars)
        Container(
          width: 3,
          height: bar.$1,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: bar.$2,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
    ],
  );
}

/// Drops the black plate baked into the brand artwork so the mark sits on
/// the light background instead of a dark rectangle.
class _KnockoutLogo extends StatefulWidget {
  const _KnockoutLogo({required this.asset, required this.width});

  final String asset;
  final double width;

  @override
  State<_KnockoutLogo> createState() => _KnockoutLogoState();
}

class _KnockoutLogoState extends State<_KnockoutLogo> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(widget.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final source = frame.image;
      final bytes = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) {
        source.dispose();
        return;
      }
      final pixels = bytes.buffer.asUint8List();
      for (var i = 0; i < pixels.length; i += 4) {
        final maxChannel = _maxChannel(pixels[i], pixels[i + 1], pixels[i + 2]);
        if (maxChannel < 22) {
          pixels[i + 3] = 0;
        } else if (maxChannel < 48) {
          pixels[i + 3] = (pixels[i + 3] * (maxChannel - 22) / 26).round();
        }
      }
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        source.width,
        source.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;
      source.dispose();
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {}
  }

  int _maxChannel(int red, int green, int blue) {
    var maxChannel = red;
    if (green > maxChannel) maxChannel = green;
    if (blue > maxChannel) maxChannel = blue;
    return maxChannel;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final height = widget.width;
    if (image == null) return SizedBox(width: widget.width, height: height);
    return RawImage(
      image: image,
      width: widget.width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _PortraitIllustration extends StatelessWidget {
  const _PortraitIllustration({
    required this.assetPath,
    required this.semanticLabel,
  });

  final String assetPath;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Container(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height.clamp(560, 900) * .34,
      constraints: const BoxConstraints(maxHeight: 285),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PelevoRadii.large),
        color: context.pelevo.background,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}

class _OnboardingDots extends StatelessWidget {
  const _OnboardingDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Onboarding feature ${active + 1} of 4',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (index) => Container(
          width: index == active ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                index == active
                    ? const [
                      PelevoColors.red,
                      PelevoColors.yellow,
                      PelevoColors.green,
                      PelevoColors.red,
                    ][index]
                    : context.pelevo.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}
