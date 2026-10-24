import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/features/profile/legal_links.dart';
import 'package:pelevo/features/profile/support_data.dart';
import 'package:pelevo/features/profile/support_dialogs.dart';
import 'package:pelevo/features/profile/preferences_data.dart';
import 'package:pelevo/features/profile/preferences_panel.dart';
import 'package:pelevo/features/profile/account_feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/features/authentication/social_auth.dart';
import 'package:pelevo/features/profile/connected_accounts_data.dart';
import 'package:pelevo/features/profile/invite_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';
import 'package:pelevo/features/reels/reel_ad_service.dart';
import 'package:pelevo/features/reels/reel_data.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  String? _loadedUserId;
  bool _saving = false;
  bool _dirty = false;
  ApiFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text('Your unsaved profile changes will be lost.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) context.go('/screen/profile');
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _failure = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .saveProfile(name: _name.text, handle: _handle.text, bio: _bio.text);
      if (!mounted) return;
      ref.invalidate(reelsFeedProvider);
      ref.invalidate(publicCreatorProfileProvider);
      ref.invalidate(publicCreatorReelsProvider);
      setState(() => _dirty = false);
      context.showPelevoMessage('Profile updated');
      context.go('/screen/profile');
    } on Object catch (error) {
      if (mounted) setState(() => _failure = profileFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _photo() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (photo == null || !mounted) return;
      if (await photo.length() > 5 * 1024 * 1024) {
        throw const ApiFailure(
          code: 'VALIDATION',
          message: 'Choose a photo smaller than 5 MB.',
        );
      }
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      await ref.read(profileProvider.notifier).uploadAvatar(bytes, photo.name);
      if (mounted) context.showPelevoMessage('Profile photo updated');
    } on PlatformException {
      if (mounted) {
        setState(
          () =>
              _failure = const ApiFailure(
                code: 'PHOTO_ACCESS',
                message:
                    'Unable to open your photos. Check photo access in device settings.',
              ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _failure = profileFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final user = profile.asData?.value;
    if (user != null && _loadedUserId != user.id) {
      _loadedUserId = user.id;
      _name.text = user.name;
      _handle.text = user.handle ?? '';
      _bio.text = user.bio ?? '';
      _dirty = false;
    }
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: PelevoPage(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _saving ? null : _back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Edit Profile'),
        ),
        child:
            user == null
                ? ProfileLoadState(
                  error: profile.error,
                  retry: () => ref.invalidate(profileProvider),
                )
                : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      onChanged: () {
                        if (!_dirty) setState(() => _dirty = true);
                      },
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ProfileAvatar(url: user.avatarUrl, size: 96),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: PelevoColors.green,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Change photo',
                                  onPressed: _saving ? null : _photo,
                                  icon: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: PelevoSpacing.xl),
                          if (_saving) const LinearProgressIndicator(),
                          if (_failure != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: PelevoSpacing.sm,
                              ),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _failure!.message,
                                  style: const TextStyle(
                                    color: PelevoColors.red,
                                  ),
                                ),
                              ),
                            ),
                          TextFormField(
                            controller: _name,
                            enabled: !_saving,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: 'Display name',
                              errorText: _failure?.fields['name'],
                            ),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Enter your display name.'
                                        : null,
                          ),
                          const SizedBox(height: PelevoSpacing.sm),
                          TextFormField(
                            controller: _handle,
                            enabled: !_saving,
                            maxLength: 30,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixText: '@',
                              errorText: _failure?.fields['handle'],
                            ),
                            validator:
                                (value) =>
                                    value == null ||
                                            value.trim().isEmpty ||
                                            RegExp(
                                              r'^[a-zA-Z0-9_-]{3,30}$',
                                            ).hasMatch(value.trim())
                                        ? null
                                        : 'Use 3–30 letters, numbers, underscores or hyphens.',
                          ),
                          const SizedBox(height: PelevoSpacing.sm),
                          TextFormField(
                            controller: _bio,
                            enabled: !_saving,
                            maxLines: 3,
                            maxLength: 500,
                            decoration: InputDecoration(
                              labelText: 'Bio',
                              errorText: _failure?.fields['bio'],
                            ),
                          ),
                          const SizedBox(height: PelevoSpacing.xl),
                          PelevoButton(
                            label: _saving ? 'Saving…' : 'Save Changes',
                            color: PelevoColors.green,
                            onPressed: _saving ? null : _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}

class ProfileFollowingScreen extends StatelessWidget {
  const ProfileFollowingScreen({super.key});

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/profile'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Following'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            AccountFeedPanel(
              feed: AccountFeed.following,
              builder:
                  (state) => Column(
                    children: [
                      if (state.items.isEmpty)
                        const Text('You are not following any shows yet.'),
                      for (final item in state.items)
                        Card(
                          margin: const EdgeInsets.only(
                            bottom: PelevoSpacing.sm,
                          ),
                          child: ListTile(
                            leading: ProfileAvatar(url: item.artwork, size: 40),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(item.body),
                            trailing: OutlinedButton(
                              onPressed:
                                  state.busy || state.loading
                                      ? null
                                      : () async {
                                        final confirmed = await showDialog<
                                          bool
                                        >(
                                          context: context,
                                          builder:
                                              (dialogContext) => AlertDialog(
                                                title: Text(
                                                  'Unfollow ${item.title}?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          dialogContext,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          dialogContext,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Unfollow',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                        );
                                        if (confirmed == true &&
                                            state.mounted) {
                                          await state.mutate(
                                            (repo) => repo.unfollow(item.id),
                                            'Unfollowed ${item.title}',
                                          );
                                        }
                                      },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PelevoColors.green,
                                side: const BorderSide(
                                  color: PelevoColors.green,
                                ),
                              ),
                              child: const Text('Following'),
                            ),
                          ),
                        ),
                    ],
                  ),
            ),
            const SizedBox(height: PelevoSpacing.md),
            PelevoButton(
              label: 'Discover more creators',
              color: PelevoColors.green,
              onPressed: () => context.go('/screen/browse'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileHelpScreen extends ConsumerWidget {
  const ProfileHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/profile'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Help & Support'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('FAQs', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: PelevoSpacing.sm),
            CmsDocumentContent(document: CmsDocument.help, expandable: true),
            const SizedBox(height: PelevoSpacing.lg),
            PelevoButton(
              label: 'Contact Support',
              color: PelevoColors.blue,
              onPressed: () => showSupportForm(context, feedback: false),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            PelevoButton(
              label: 'Send Feedback',
              outlined: true,
              color: PelevoColors.blue,
              onPressed: () => showSupportForm(context, feedback: true),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileInviteScreen extends ConsumerWidget {
  const ProfileInviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = ref.watch(userInviteProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/profile'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Invite Friends'),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: invite.when(
            skipLoadingOnRefresh: false,
            loading:
                () => const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator(),
                ),
            error:
                (error, stack) => Column(
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      inviteFailure(error).message,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(userInviteProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            data: (data) {
              final code = data.code;
              return Column(
                children: [
                  const SizedBox(height: 24),
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFF3B0A45),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: PelevoColors.pink,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: PelevoSpacing.lg),
                  Text(
                    'Invite friends & earn rewards',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: PelevoSpacing.sm),
                  Text(
                    'Share your invite code. When friends join and listen, you both unlock bonus coins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                  const SizedBox(height: PelevoSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(PelevoSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.pelevo.surface,
                      borderRadius: BorderRadius.circular(PelevoRadii.large),
                      border: Border.all(color: context.pelevo.border),
                    ),
                    child: Column(
                      children: [
                        const Text('Your invite code'),
                        const SizedBox(height: 8),
                        Text(
                          code ?? 'No active invite code',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: PelevoColors.green,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PelevoSpacing.lg),
                  PelevoButton(
                    label: 'Copy Invite Code',
                    color: PelevoColors.pink,
                    onPressed:
                        code == null
                            ? null
                            : () async {
                              await Clipboard.setData(
                                ClipboardData(text: code),
                              );
                              if (context.mounted) {
                                context.showPelevoMessage('Invite code copied');
                              }
                            },
                  ),
                  const SizedBox(height: PelevoSpacing.sm),
                  PelevoButton(
                    label: 'Share Invite Link',
                    outlined: true,
                    color: PelevoColors.pink,
                    onPressed:
                        code == null
                            ? null
                            : () async {
                              await Clipboard.setData(
                                ClipboardData(text: data.shareLink),
                              );
                              if (!context.mounted) return;
                              context.showPelevoMessage('Invite link copied');
                              context.push('/screen/share-card-home');
                            },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class ProfileAboutScreen extends ConsumerWidget {
  const ProfileAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(packageInfoProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/profile'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('About Pelevo'),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Image.asset(
                'assets/onboarding/splash_brand.png',
                height: 96,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.graphic_eq_rounded,
                      size: 72,
                      color: PelevoColors.red,
                    ),
              ),
              const SizedBox(height: PelevoSpacing.md),
              Text('pelevo', style: Theme.of(context).textTheme.headlineLarge),
              CmsDocumentContent(document: CmsDocument.about),
              const SizedBox(height: PelevoSpacing.xl),
              _AboutRow(
                label: 'Version',
                value: '${package.version} (build ${package.buildNumber})',
              ),
              _AboutRow(
                label: 'Platform',
                value: kIsWeb ? 'Web' : defaultTargetPlatform.name,
              ),
              InkWell(
                onTap: () => context.push('/screen/profile-help'),
                child: const _AboutRow(
                  label: 'Support',
                  value: 'Help & Support',
                ),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Terms and Conditions'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/terms'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/legal/privacy'),
              ),
              FutureBuilder<bool>(
                future: ReelAds.privacyOptionsRequired(),
                builder:
                    (context, snapshot) =>
                        snapshot.data == true
                            ? ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Advertising privacy choices'),
                              subtitle: const Text(
                                'Review or change your ad consent choices',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: ReelAds.showPrivacyOptions,
                            )
                            : const SizedBox.shrink(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap:
                    () => showLicensePage(
                      context: context,
                      applicationName: 'Pelevo',
                      applicationVersion: package.version,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePersonalInfoScreen extends ConsumerWidget {
  const ProfilePersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/settings-account'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Personal Information'),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: profile.when(
            loading:
                () => ProfileLoadState(
                  retry: () => ref.invalidate(profileProvider),
                ),
            error:
                (error, stack) => ProfileLoadState(
                  error: error,
                  retry: () => ref.invalidate(profileProvider),
                ),
            data:
                (user) => Column(
                  children: [
                    _AboutRow(label: 'Full name', value: user.name),
                    _AboutRow(label: 'Email', value: user.email),
                    _AboutRow(label: 'Phone', value: user.phone ?? 'Not set'),
                    _AboutRow(
                      label: 'Country',
                      value: user.countryCode ?? 'Not set',
                    ),
                    _AboutRow(
                      label: 'Language',
                      value: user.locale ?? 'Not set',
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class ProfileChangePasswordScreen extends ConsumerStatefulWidget {
  const ProfileChangePasswordScreen({super.key});

  @override
  ConsumerState<ProfileChangePasswordScreen> createState() =>
      _ProfileChangePasswordScreenState();
}

class _ProfileChangePasswordScreenState
    extends ConsumerState<ProfileChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _hideCurrent = true;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  ApiFailure? _failure;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final current = _current.text;
    final password = _password.text;
    final confirmation = _confirmation.text;
    if (current.isEmpty || password.length < 8 || confirmation.isEmpty) {
      context.showPelevoMessage(
        'Enter your current password and a new password of at least 8 characters.',
      );
      return;
    }
    if (password != confirmation) {
      context.showPelevoMessage('New passwords do not match');
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: current,
            password: password,
            confirmation: confirmation,
          );
      if (!mounted) return;
      context.showPelevoMessage('Password updated');
      context.go('/screen/settings-account');
    } on Object catch (error) {
      if (mounted) setState(() => _failure = profileFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed:
            _saving ? null : () => context.go('/screen/settings-account'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Change Password'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your current session stays signed in after this change. Other devices will need to sign in again.',
              style: TextStyle(color: context.pelevo.textMuted),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            if (_saving) const LinearProgressIndicator(),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: PelevoSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!.message,
                    style: const TextStyle(color: PelevoColors.red),
                  ),
                ),
              ),
            TextField(
              controller: _current,
              enabled: !_saving,
              obscureText: _hideCurrent,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Current password',
                errorText: _failure?.fields['current_password'],
                suffixIcon: IconButton(
                  tooltip: _hideCurrent ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                  icon: Icon(
                    _hideCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            TextField(
              controller: _password,
              enabled: !_saving,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password',
                errorText: _failure?.fields['password'],
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed:
                      () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            TextField(
              controller: _confirmation,
              enabled: !_saving,
              obscureText: _hideConfirmation,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                errorText: _failure?.fields['password_confirmation'],
                suffixIcon: IconButton(
                  tooltip:
                      _hideConfirmation ? 'Show password' : 'Hide password',
                  onPressed:
                      () => setState(
                        () => _hideConfirmation = !_hideConfirmation,
                      ),
                  icon: Icon(
                    _hideConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: PelevoSpacing.lg),
            PelevoButton(
              label: _saving ? 'Updating…' : 'Update Password',
              color: PelevoColors.green,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileEmailPreferencesScreen extends StatelessWidget {
  const ProfileEmailPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.go('/screen/settings-account'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Email Preferences'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: PreferencesPanel(
          builder:
              (preferences, saving, save) => _EmailPreferencesDraft(
                key: ValueKey('${preferences.userId}:${preferences.version}'),
                preferences: preferences,
                saving: saving,
                save: save,
              ),
        ),
      ),
    ),
  );
}

class _EmailPreferencesDraft extends StatefulWidget {
  const _EmailPreferencesDraft({
    super.key,
    required this.preferences,
    required this.saving,
    required this.save,
  });
  final AccountPreferences preferences;
  final bool saving;
  final SavePreferences save;
  @override
  State<_EmailPreferencesDraft> createState() => _EmailPreferencesDraftState();
}

class _EmailPreferencesDraftState extends State<_EmailPreferencesDraft> {
  late bool _product;
  late bool _episodes;
  late bool _marketing;
  @override
  void initState() {
    super.initState();
    _product = widget.preferences.flag('email_product');
    _episodes = widget.preferences.flag('email_episodes');
    _marketing = widget.preferences.flag('email_marketing');
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Product updates'),
        subtitle: const Text('Optional feature and product news'),
        value: _product,
        activeColor: PelevoColors.green,
        onChanged:
            widget.saving ? null : (value) => setState(() => _product = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('New episodes'),
        subtitle: const Text('Shows you follow'),
        value: _episodes,
        activeColor: PelevoColors.green,
        onChanged:
            widget.saving ? null : (value) => setState(() => _episodes = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Offers & promotions'),
        subtitle: const Text('Pelevo Plus deals and partner news'),
        value: _marketing,
        activeColor: PelevoColors.green,
        onChanged:
            widget.saving
                ? null
                : (value) => setState(() => _marketing = value),
      ),
      const Text(
        'Essential security and account emails are not affected. Optional email delivery is not yet enabled.',
      ),
      const SizedBox(height: PelevoSpacing.lg),
      PelevoButton(
        label: widget.saving ? 'Saving…' : 'Save Preferences',
        color: PelevoColors.green,
        onPressed:
            widget.saving
                ? null
                : () => widget.save({
                  'email_product': _product,
                  'email_episodes': _episodes,
                  'email_marketing': _marketing,
                }),
      ),
    ],
  );
}

class ProfileConnectedAccountsScreen extends ConsumerStatefulWidget {
  const ProfileConnectedAccountsScreen({super.key});

  @override
  ConsumerState<ProfileConnectedAccountsScreen> createState() =>
      _ProfileConnectedAccountsScreenState();
}

class _ProfileConnectedAccountsScreenState
    extends ConsumerState<ProfileConnectedAccountsScreen> {
  String? _busyId;

  String _title(String provider) => switch (provider) {
    'google' => 'Google',
    'apple' => 'Apple',
    _ => 'Facebook',
  };

  void _connect(String provider) {
    if (provider == 'facebook') {
      context.showPelevoMessage(
        'Facebook is not offered by the connected-accounts API. No account has been linked.',
      );
      return;
    }
    _linkProvider(provider);
  }

  Future<void> _linkProvider(String provider) async {
    setState(() => _busyId = provider);
    try {
      final tokens =
          provider == 'google'
              ? await SocialAuthService.google()
              : await SocialAuthService.apple();
      await ref
          .read(connectedAccountsRepositoryProvider)
          .link(provider: tokens.provider, token: tokens.token);
      ref.invalidate(connectedAccountsProvider);
      if (!mounted) return;
      context.showPelevoMessage('${_title(provider)} connected');
    } on Object catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(connectedAccountsFailure(error).message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _manage(ConnectedAccount account) async {
    if (_busyId != null) return;
    final title = _title(account.provider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Disconnect $title?'),
            content: Text(
              account.email == null
                  ? '$title will be removed from this account.'
                  : '${account.email} will be removed from this account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = account.id);
    try {
      await ref
          .read(connectedAccountsRepositoryProvider)
          .disconnect(account.id);
      ref.invalidate(connectedAccountsProvider);
      if (!mounted) return;
      context.showPelevoMessage('$title disconnected');
    } catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(profileFailure(error).message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(connectedAccountsProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/settings-account'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Connected Accounts'),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: result.when(
            loading:
                () => ProfileLoadState(
                  retry: () => ref.invalidate(connectedAccountsProvider),
                ),
            error:
                (error, _) => ProfileLoadState(
                  error: error,
                  retry: () => ref.invalidate(connectedAccountsProvider),
                ),
            data: (page) {
              final google = page.forProvider('google');
              final apple = page.forProvider('apple');
              return Column(
                children: [
                  _ConnectedTile(
                    title: 'Google',
                    subtitle: google?.subtitle ?? 'Not connected',
                    connected: google != null,
                    onPressed:
                        _busyId != null
                            ? null
                            : () =>
                                google == null
                                    ? _connect('google')
                                    : _manage(google),
                  ),
                  _ConnectedTile(
                    title: 'Apple',
                    subtitle: apple?.subtitle ?? 'Not connected',
                    connected: apple != null,
                    onPressed:
                        _busyId != null
                            ? null
                            : () =>
                                apple == null
                                    ? _connect('apple')
                                    : _manage(apple),
                  ),
                  _ConnectedTile(
                    title: 'Facebook',
                    subtitle: 'Not connected',
                    connected: false,
                    onPressed:
                        _busyId != null ? null : () => _connect('facebook'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            body,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ),
      ],
    ),
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ConnectedTile extends StatelessWidget {
  const _ConnectedTile({
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
    child: ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: onPressed,
        child: Text(connected ? 'Manage' : 'Connect'),
      ),
    ),
  );
}

class CmsDocumentContent extends ConsumerWidget {
  const CmsDocumentContent({
    super.key,
    required this.document,
    this.expandable = false,
  });
  final CmsDocument document;
  final bool expandable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(cmsPageProvider(document));
    return result.when(
      loading:
          () => ProfileLoadState(
            retry: () => ref.invalidate(cmsPageProvider(document)),
          ),
      error: (error, stack) {
        final failure = profileFailure(error);
        if (failure.code == 'NOT_FOUND' || failure.statusCode == 404) {
          return Column(
            children: [
              const Text('This content has not been published yet.'),
              TextButton(
                onPressed: () => ref.invalidate(cmsPageProvider(document)),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        return ProfileLoadState(
          error: error,
          retry: () => ref.invalidate(cmsPageProvider(document)),
        );
      },
      data:
          (page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page.intro.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: PelevoSpacing.sm),
                  child:
                      document == CmsDocument.terms ||
                              document == CmsDocument.privacy
                          ? PublicLegalText(text: page.intro)
                          : SelectableText(
                            page.intro,
                            style: TextStyle(
                              color: context.pelevo.textMuted,
                            ),
                          ),
                ),
              if (page.intro.isEmpty && page.sections.isEmpty)
                const Text('No content is available yet.'),
              for (final section in page.sections)
                if (expandable)
                  _HelpTile(title: section.title, body: section.body)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: PelevoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          section.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: PelevoSpacing.xs),
                        if (document == CmsDocument.terms ||
                            document == CmsDocument.privacy)
                          PublicLegalText(text: section.body)
                        else
                          SelectableText(section.body),
                      ],
                    ),
                  ),
            ],
          ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});
  final CmsDocument document;
  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/screen/auth-sign-in');
          }
        },
      ),
      title: Text(
        document == CmsDocument.terms
            ? 'Terms and Conditions'
            : 'Privacy Policy',
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CmsDocumentContent(document: document),
      ),
    ),
  );
}
