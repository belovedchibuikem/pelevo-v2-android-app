import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';
import 'package:pelevo/features/profile/preferences_data.dart';
import 'package:pelevo/features/profile/preferences_panel.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _offline = false;
  bool _signingOut = false;

  Future<void> _logout() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Log out of Pelevo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log Out'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).logout();
      if (!mounted) return;
      await ref.read(authSessionProvider.notifier).clear();
      if (mounted) context.go('/screen/auth-sign-in');
    } on Object {
      if (mounted) {
        context.showPelevoMessage(
          'Unable to log out. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final user = profile.asData?.value;
    if (user == null) {
      return PelevoPage(
        appBar: AppBar(title: const Text('Profile')),
        bottomNavigationBar: PelevoBottomNavigation(
          index: 0,
          onDestinationSelected: context.openPelevoTab,
        ),
        child: ProfileLoadState(
          error: profile.error,
          retry: () => ref.invalidate(profileProvider),
        ),
      );
    }
    final isCreator = user.creatorAccess;
    return PelevoPage(
      appBar: AppBar(
        leading: const PelevoBackButton(),
        title: const Text('Profile'),
      ),
      bottomNavigationBar: PelevoBottomNavigation(
        index: 0,
        onDestinationSelected: context.openPelevoTab,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed:
                            () => context.push('/screen/notifications-1'),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (user.unreadNotifications > 0)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: PelevoColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.push('/screen/settings-account'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.md),
              Row(
                children: [
                  ProfileAvatar(url: user.avatarUrl),
                  const SizedBox(width: PelevoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (isCreator) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified,
                                color: PelevoColors.green,
                                size: 17,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          user.handle == null
                              ? 'No username set'
                              : '@${user.handle}',
                          style: const TextStyle(color: PelevoColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => context.push('/screen/profile-edit'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: PelevoColors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: PelevoColors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: PelevoColors.surface,
                  borderRadius: PelevoRadii.card,
                  border: Border.all(color: PelevoColors.border),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap:
                              () => context.push('/screen/profile-following'),
                          child: _Stat(
                            value: '${user.following}',
                            label: 'Following',
                          ),
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: PelevoColors.border,
                      ),
                      Expanded(
                        child: _Stat(
                          value: '${user.followers}',
                          label: 'Followers',
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        color: PelevoColors.border,
                      ),
                      Expanded(
                        child: InkWell(
                          onTap:
                              () => context.push(
                                isCreator
                                    ? '/screen/creator-studio'
                                    : '/screen/library-2',
                              ),
                          child: _Stat(
                            value:
                                '${isCreator ? user.podcasts : user.playlists}',
                            label: isCreator ? 'Podcasts' : 'Playlists Created',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              _UpgradeProCard(
                onPressed: () => context.push('/screen/premium-intro'),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              if (isCreator) ...[
                _CreatorStudioCard(
                  onPressed: () => context.push('/screen/creator-studio'),
                ),
                const SizedBox(height: PelevoSpacing.sm),
              ],
              _EarnWalletCard(
                onPressed: () => context.push('/screen/earn-wallet'),
              ),
              if (!isCreator) ...[
                const SizedBox(height: PelevoSpacing.sm),
                _ProfileMenuPanel(
                  children: [
                    _MenuTile(
                      icon: Icons.mic_none_rounded,
                      color: PelevoColors.purple,
                      title: 'Claim Your Podcast',
                      subtitle: 'Claim your podcast and unlock creator tools',
                      onTap: () => context.push('/screen/claim-podcast'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: PelevoSpacing.md),
              _ProfileMenuPanel(
                children: [
                  _MenuTile(
                    icon: Icons.history_rounded,
                    color: PelevoColors.red,
                    title: 'History',
                    subtitle: 'Recently played & listened',
                    onTap: () => context.push('/screen/library-8'),
                  ),
                  _MenuTile(
                    icon: Icons.person_add_alt_1_rounded,
                    color: PelevoColors.blue,
                    title: 'Following',
                    subtitle: 'Podcasts & creators you follow',
                    onTap: () => context.push('/screen/profile-following'),
                  ),
                  _MenuTile(
                    icon: Icons.sync_rounded,
                    color: const Color(0xFF22D3EE),
                    title: 'Sync',
                    subtitle: 'Sync across your devices',
                    onTap: () => context.push('/screen/device-sync-basic-1'),
                  ),
                  _MenuTile(
                    icon: Icons.devices_rounded,
                    color: PelevoColors.yellow,
                    title: 'Devices',
                    subtitle: 'Manage connected devices',
                    onTap: () => context.push('/screen/sync-dashboard'),
                  ),
                  _MenuTile(
                    icon: Icons.cloud_off_outlined,
                    color: PelevoColors.purple,
                    title: 'Offline Mode',
                    subtitle: 'Listen without internet',
                    trailing: Switch(
                      value: _offline,
                      activeColor: PelevoColors.green,
                      onChanged: (value) => setState(() => _offline = value),
                    ),
                  ),
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    color: PelevoColors.textMuted,
                    title: 'Settings',
                    subtitle: 'App settings & preferences',
                    onTap: () => context.push('/screen/settings-account'),
                  ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.lg),
              Text(
                'Support & More',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PelevoColors.textDim,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: PelevoSpacing.sm),
              _ProfileMenuPanel(
                children: [
                  _MenuTile(
                    icon: Icons.help_outline_rounded,
                    color: PelevoColors.blue,
                    title: 'Help & Support',
                    subtitle: 'FAQs, support & feedback',
                    onTap: () => context.push('/screen/profile-help'),
                  ),
                  _MenuTile(
                    icon: Icons.card_giftcard_rounded,
                    color: PelevoColors.pink,
                    title: 'Invite Friends',
                    subtitle: 'Invite friends & earn rewards',
                    onTap: () => context.push('/screen/profile-invite'),
                  ),
                  _MenuTile(
                    icon: Icons.info_outline_rounded,
                    color: PelevoColors.orange,
                    title: 'About',
                    subtitle: 'App version & information',
                    onTap: () => context.push('/screen/profile-about'),
                  ),
                ],
              ),
              const SizedBox(height: PelevoSpacing.lg),
              OutlinedButton.icon(
                onPressed: _signingOut ? null : _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PelevoColors.red,
                  side: const BorderSide(color: PelevoColors.red),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsAccountScreen extends StatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  State<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends State<SettingsAccountScreen> {
  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/profile'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Settings & Account'),
      centerTitle: true,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PreferencesPanel(
          builder:
              (preferences, saving, save) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionLabel('Account'),
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    onTap: () => context.push('/screen/profile-personal'),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    onTap: () => context.push('/screen/profile-password'),
                  ),
                  _SettingsTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email Preferences',
                    onTap: () => context.push('/screen/profile-email'),
                  ),
                  _SettingsTile(
                    icon: Icons.link_rounded,
                    title: 'Connected Accounts',
                    subtitle: 'Google, Apple, Facebook',
                    onTap: () => context.push('/screen/profile-connected'),
                  ),
                  const _SectionLabel('Playback'),
                  _SettingsTile(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Audio Quality',
                    trailingText: audioQualityLabels[preferences.audioQuality],
                    subtitle: 'Saved preference; player integration pending',
                    onTap:
                        saving
                            ? null
                            : () async {
                              final choice = await showDialog<String>(
                                context: context,
                                builder:
                                    (context) => SimpleDialog(
                                      title: const Text('Audio Quality'),
                                      children: [
                                        for (final option
                                            in audioQualityLabels.entries)
                                          SimpleDialogOption(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  option.key,
                                                ),
                                            child: Text(option.value),
                                          ),
                                      ],
                                    ),
                              );
                              if (choice != null && context.mounted) {
                                await save({'audio_quality': choice});
                              }
                            },
                  ),
                  _SettingsTile(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Playback Settings',
                    onTap: () => context.push('/screen/player-now-playing'),
                  ),
                  _SettingsTile(
                    icon: Icons.data_saver_off_outlined,
                    title: 'Data Saver',
                    subtitle: 'Saved preference; player integration pending',
                    trailing: Switch(
                      value: preferences.flag('data_saver'),
                      activeColor: PelevoColors.green,
                      onChanged:
                          saving
                              ? null
                              : (value) => save({'data_saver': value}),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.timer_outlined,
                    title: 'Sleep Timer',
                    trailingText: 'Unavailable',
                    onTap: () async {
                      final choice = await showDialog<String>(
                        context: context,
                        builder:
                            (context) => SimpleDialog(
                              title: const Text('Sleep Timer'),
                              children: [
                                for (final option in [
                                  'Off',
                                  '15 min',
                                  '30 min',
                                  '1 hour',
                                  'End of episode',
                                ])
                                  SimpleDialogOption(
                                    onPressed:
                                        () => Navigator.pop(context, option),
                                    child: Text(option),
                                  ),
                              ],
                            ),
                      );
                      if (choice != null && context.mounted) {
                        context.showPelevoMessage(
                          'Sleep timer is unavailable until playback integration is complete. No timer was started.',
                        );
                      }
                    },
                  ),
                  const _SectionLabel('Notifications'),
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Push Notifications',
                    trailingText: 'Manage',
                    onTap: () => context.push('/screen/notifications-7'),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'New Episodes',
                    trailingText: 'Manage',
                    onTap: () => context.push('/screen/notifications-7'),
                  ),
                  _SettingsTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Recommendations',
                    trailingText: 'Manage',
                    onTap: () => context.push('/screen/notifications-7'),
                  ),
                  const _SectionLabel('Appearance'),
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    trailingText: 'On',
                    onTap:
                        () => context.showPelevoMessage(
                          'This app currently supports the supplied dark theme only.',
                        ),
                  ),
                ],
              ),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _GradientCard extends StatelessWidget {
  const _GradientCard({required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: PelevoSpacing.xs),
    padding: const EdgeInsets.all(PelevoSpacing.md),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(PelevoRadii.large),
      gradient: LinearGradient(colors: colors),
    ),
    child: child,
  );
}

class _UpgradeProCard extends StatelessWidget {
  const _UpgradeProCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _GradientCard(
    colors: const [Color(0xFF4C146F), Color(0xFF21082F)],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.workspace_premium_rounded, color: PelevoColors.purple),
            SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Pro',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Ad-free listening, unlimited downloads, offline mode, exclusives, Pelevo AI Hub, and priority support.',
                    style: TextStyle(
                      color: PelevoColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: PelevoColors.purple),
            child: const Text('Upgrade Now →'),
          ),
        ),
      ],
    ),
  );
}

class _CreatorStudioCard extends StatelessWidget {
  const _CreatorStudioCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _GradientCard(
    colors: const [Color(0xFF0A4B22), Color(0xFF071D10)],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.analytics_outlined, color: PelevoColors.green),
            SizedBox(width: PelevoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creator Studio',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Manage your podcasts, reels, audience, analytics and earnings.',
                    style: TextStyle(
                      color: PelevoColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(backgroundColor: PelevoColors.green),
          child: const Text('Open Creator Studio →'),
        ),
      ],
    ),
  );
}

class _EarnWalletCard extends ConsumerWidget {
  const _EarnWalletCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _GradientCard(
    colors: const [Color(0xFF0A4220), Color(0xFF061A0D)],
    child: Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: PelevoColors.green,
        ),
        const SizedBox(width: PelevoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earn Wallet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'Available Balance',
                style: TextStyle(color: PelevoColors.textMuted, fontSize: 11),
              ),
              ref
                  .watch(earnBalanceProvider)
                  .when(
                    data:
                        (balance) => Text(
                          '${balance.coins} ECN',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    loading: () => const LinearProgressIndicator(),
                    error:
                        (error, stack) => TextButton(
                          onPressed: () => ref.invalidate(earnBalanceProvider),
                          child: const Text('Balance unavailable · Retry'),
                        ),
                  ),
            ],
          ),
        ),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: PelevoColors.green.withValues(alpha: .18),
            foregroundColor: PelevoColors.green,
          ),
          child: const Text('View Wallet →'),
        ),
      ],
    ),
  );
}

class _ProfileMenuPanel extends StatelessWidget {
  const _ProfileMenuPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: PelevoColors.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: PelevoColors.border),
    ),
    child: Column(children: children),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: color.withValues(alpha: .15),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: PelevoColors.textMuted),
    ),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: PelevoSpacing.md,
      bottom: PelevoSpacing.xs,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: PelevoColors.textDim,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: PelevoColors.textMuted),
    title: Text(title),
    subtitle:
        subtitle == null
            ? null
            : Text(
              subtitle!,
              style: const TextStyle(color: PelevoColors.textMuted),
            ),
    trailing:
        trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(
                  color: PelevoColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
    onTap: onTap,
  );
}
