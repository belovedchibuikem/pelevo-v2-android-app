import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_environment.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_link_text.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';

/// Store-required privacy controls: data export and account deletion.
class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _exporting = false;
  bool _deleting = false;
  PrivacyExportRequest? _export;
  AccountDeletionRequest? _deletion;

  Future<void> _requestExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final request =
          await ref.read(profileRepositoryProvider).requestDataExport();
      if (!mounted) return;
      setState(() => _export = request);
      context.showPelevoMessage(
        'Export queued. We will prepare a downloadable copy of your data.',
      );
      _pollExport(request.id);
    } catch (error) {
      if (mounted) context.showPelevoMessage(profileFailure(error).message);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pollExport(String id) async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final status =
            await ref.read(profileRepositoryProvider).dataExportStatus(id);
        if (!mounted) return;
        setState(() => _export = status);
        if (status.state == 'completed' ||
            status.state == 'failed' ||
            status.downloadUrl != null) {
          return;
        }
      } catch (_) {
        return;
      }
    }
  }

  Future<void> _openDownload() async {
    final url = _export?.downloadUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await openPelevoExternalLink(uri);
    if (!opened && mounted) {
      context.showPelevoMessage('Could not open the download link.');
    }
  }

  Future<void> _confirmDelete() async {
    if (_deleting) return;
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final reason = TextEditingController();
    final usePassword = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete your account?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Deletion is scheduled for 30 days. Sign back in before then to cancel. '
                    'This removes your profile, library, earn balance, and creator data.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (if you have one)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmation,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Or type DELETE to confirm',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: PelevoColors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Schedule deletion'),
              ),
            ],
          ),
    );
    final passwordText = password.text;
    final confirmationText = confirmation.text.trim();
    final reasonText = reason.text.trim();
    password.dispose();
    confirmation.dispose();
    reason.dispose();
    if (usePassword != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final request = await ref
          .read(profileRepositoryProvider)
          .requestAccountDeletion(
            password: passwordText.isEmpty ? null : passwordText,
            confirmation: confirmationText.isEmpty ? null : confirmationText,
            reason: reasonText.isEmpty ? null : reasonText,
          );
      if (!mounted) return;
      setState(() => _deletion = request);
      try {
        await ref.read(authRepositoryProvider).logout();
      } on Object {
        // Session clear still required even if logout fails offline.
      }
      await ref.read(authSessionProvider.notifier).clear();
      if (!mounted) return;
      context.showPelevoMessage(
        request.scheduledFor == null
            ? 'Account deletion scheduled.'
            : 'Account deletion scheduled for ${request.scheduledFor}.',
      );
      context.go('/screen/auth-sign-in');
    } catch (error) {
      if (mounted) context.showPelevoMessage(profileFailure(error).message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacyUrl = '${ApiEnvironment.publicWebBase}/privacy';
    final termsUrl = '${ApiEnvironment.publicWebBase}/terms';
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/settings-account'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Privacy & data'),
        centerTitle: true,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(PelevoSpacing.md),
            children: [
              Text(
                'Download a copy of your data or permanently delete your Pelevo account. '
                'These controls are required by Google Play and the App Store.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.pelevo.textMuted,
                ),
              ),
              const SizedBox(height: PelevoSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Privacy Policy'),
                subtitle: Text(privacyUrl),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap:
                    () => openPelevoExternalLink(Uri.parse(privacyUrl)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms and Conditions'),
                subtitle: Text(termsUrl),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => openPelevoExternalLink(Uri.parse(termsUrl)),
              ),
              const Divider(height: 32),
              Text(
                'Download your data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'We prepare a JSON export of your account. Large accounts may take a few minutes.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _exporting ? null : _requestExport,
                icon:
                    _exporting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.download_outlined),
                label: Text(_exporting ? 'Requesting…' : 'Request data export'),
              ),
              if (_export != null) ...[
                const SizedBox(height: 12),
                Text('Status: ${_export!.state}'),
                if (_export!.downloadUrl != null)
                  TextButton(
                    onPressed: _openDownload,
                    child: const Text('Open download'),
                  ),
              ],
              const Divider(height: 40),
              Text(
                'Delete account',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: PelevoColors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Schedules permanent deletion after 30 days. Earn balances, gifts, '
                'subscriptions, and creator payouts tied to this account are removed.',
              ),
              if (_deletion != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Already scheduled'
                  '${_deletion!.scheduledFor == null ? '' : ' for ${_deletion!.scheduledFor}'}.',
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deleting ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PelevoColors.red,
                  side: const BorderSide(color: PelevoColors.red),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(
                  _deleting ? 'Scheduling…' : 'Delete my account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
