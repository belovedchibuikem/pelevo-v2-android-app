import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/creator/claim_data.dart';
import 'package:pelevo/features/creator/creator_studio_screens.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

final List<PelevoScreenSpec> podcastClaimScreens = List.unmodifiable([
  const PelevoScreenSpec(
    id: 'claim-method',
    section: 'Podcast Claim',
    title: 'Verify Ownership',
    builder: _buildMethod,
  ),
  const PelevoScreenSpec(
    id: 'claim-rss',
    section: 'Podcast Claim',
    title: 'Send Verification Code',
    builder: _buildRss,
  ),
  const PelevoScreenSpec(
    id: 'claim-enter-code',
    section: 'Podcast Claim',
    title: 'Enter Verification Code',
    builder: _buildEnterCode,
  ),
  const PelevoScreenSpec(
    id: 'claim-manual-code',
    section: 'Podcast Claim',
    title: 'Add Verification Code',
    builder: _buildManualCode,
  ),
  const PelevoScreenSpec(
    id: 'claim-review',
    section: 'Podcast Claim',
    title: 'Code Submitted',
    builder: _buildReview,
  ),
  const PelevoScreenSpec(
    id: 'claim-status',
    section: 'Podcast Claim',
    title: 'My Claim Requests',
    builder: _buildStatusList,
  ),
  const PelevoScreenSpec(
    id: 'claim-success',
    section: 'Podcast Claim',
    title: 'Verification Successful',
    builder: _buildSuccess,
  ),
  const PelevoScreenSpec(
    id: 'claim-failed',
    section: 'Podcast Claim',
    title: 'Verification Failed',
    builder: _buildFailed,
  ),
]);

String _claimError(Object error) {
  if (error is ApiFailure) return error.message;
  if (error is DioException) return apiFailureFromDio(error).message;
  return 'Claim details could not be updated. Please try again.';
}

Widget _buildMethod(BuildContext context) => const ClaimMethodScreen();
Widget _buildRss(BuildContext context) => const ClaimRssScreen();
Widget _buildEnterCode(BuildContext context) => const ClaimEnterCodeScreen();
Widget _buildManualCode(BuildContext context) => const ClaimManualCodeScreen();
Widget _buildReview(BuildContext context) => const ClaimReviewScreen();
Widget _buildStatusList(BuildContext context) => const ClaimStatusListScreen();
Widget _buildSuccess(BuildContext context) => const ClaimSuccessScreen();
Widget _buildFailed(BuildContext context) => const ClaimFailedScreen();

class ClaimMethodScreen extends ConsumerWidget {
  const ClaimMethodScreen({super.key});

  void _requireShow(BuildContext context, WidgetRef ref, String route) {
    if (ref.read(claimDraftProvider).show == null) {
      context.go('/screen/claim-podcast');
      return;
    }
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ClaimPage(
    title: 'Verify Ownership',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const _ClaimHero(
          icon: Icons.verified_user_outlined,
          title: 'Verify that you own\nthis podcast',
          body:
              'Choose one of the available methods\nto verify your ownership.',
        ),
        const SizedBox(height: 30),
        _MethodCard(
          icon: Icons.rss_feed_rounded,
          color: PelevoColors.green,
          title: 'Verify through your\npodcast RSS feed',
          body:
              'Add a verification code to your podcast description. Our team will review and manually verify your ownership.',
          recommended: true,
          onTap: () => _requireShow(context, ref, '/screen/claim-rss'),
        ),
        const SizedBox(height: 14),
        _MethodCard(
          icon: Icons.description_outlined,
          color: PelevoColors.blue,
          title: 'Add a verification code to\nyour podcast description',
          body:
              'Add a unique code to your podcast description in your RSS feed. Our team will review and verify your ownership.',
          onTap: () => _requireShow(context, ref, '/screen/claim-manual-code'),
        ),
        const SizedBox(height: 20),
        const _InfoCard(
          icon: Icons.info_outline_rounded,
          title: 'How it works',
          body:
              'We’ll review the information you provide and manually verify that you’re the owner of this podcast. You’ll get notified via email once your podcast is verified.',
        ),
        const SizedBox(height: 24),
        const _SupportLink(),
      ],
    ),
  );
}

class ClaimRssScreen extends ConsumerStatefulWidget {
  const ClaimRssScreen({super.key});

  @override
  ConsumerState<ClaimRssScreen> createState() => _ClaimRssScreenState();
}

class _ClaimRssScreenState extends ConsumerState<ClaimRssScreen> {
  var _sending = false;
  String? _error;

  Future<void> _send() async {
    final show = ref.read(claimDraftProvider).show;
    if (show == null) {
      context.go('/screen/claim-podcast');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final start = await ref
          .read(claimRepositoryProvider)
          .startClaim(showId: show.id, method: 'email');
      ref.read(claimDraftProvider.notifier).rememberStart(start);
      if (mounted) context.push('/screen/claim-enter-code');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _claimError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = ref.watch(claimDraftProvider).start;
    final email = start?.maskedDestination;
    return _ClaimPage(
      title: 'Send verification code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          const _ClaimHero(
            icon: Icons.mail_outline_rounded,
            title: 'Send verification code',
            body:
                'We’ll send a verification code to the\nemail address we found in your RSS feed.',
            compact: true,
          ),
          const SizedBox(height: 28),
          _InfoCard(
            icon: Icons.alternate_email_rounded,
            title:
                email == null
                    ? 'Podcast email'
                    : 'Podcast email found',
            body:
                email ??
                'We’ll look up the owner email in your RSS feed when you send the code.',
            highlightBody: email != null,
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.info_outline_rounded,
            title: 'Why this email?',
            body:
                'This email is pulled from your RSS feed. If this looks incorrect, make sure your RSS feed contains the correct contact email and try again.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: PelevoColors.red)),
          ],
          const SizedBox(height: 24),
          PelevoButton(
            label: _sending ? 'Sending…' : 'Send Code',
            color: const Color(0xFF55C51F),
            onPressed: _sending ? null : _send,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/screen/claim-method'),
            child: const Text(
              'Change method',
              style: TextStyle(color: PelevoColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class ClaimEnterCodeScreen extends ConsumerStatefulWidget {
  const ClaimEnterCodeScreen({super.key});

  @override
  ConsumerState<ClaimEnterCodeScreen> createState() =>
      _ClaimEnterCodeScreenState();
}

class _ClaimEnterCodeScreenState extends ConsumerState<ClaimEnterCodeScreen> {
  final _controller = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final start = ref.read(claimDraftProvider).start;
    if (start == null || start.method != 'email') {
      context.go('/screen/claim-rss');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(claimRepositoryProvider)
          .verify(claimId: start.claimId, code: _controller.text.trim());
      if (result.state != 'verified') {
        throw const ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'This claim is not verified yet.',
        );
      }
      PodcastCreatorService.instance.claim();
      await ref.read(authSessionProvider.notifier).bootstrap();
      if (mounted) context.go('/screen/claim-success');
    } on Object catch (error) {
      if (!mounted) return;
      final message = _claimError(error);
      final failed =
          error is ApiFailure &&
          (error.statusCode == 409 || error.code == 'CONFLICT');
      setState(() {
        _busy = false;
        _error = message;
      });
      if (failed) context.go('/screen/claim-failed');
    }
  }

  Future<void> _resend() async {
    final start = ref.read(claimDraftProvider).start;
    if (start == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await ref.read(claimRepositoryProvider).resend(start.claimId);
      ref.read(claimDraftProvider.notifier).rememberStart(next);
      if (!mounted) return;
      setState(() => _busy = false);
      context.showPelevoMessage('A new code was sent');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _claimError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = ref.watch(claimDraftProvider).start;
    final destination = start?.maskedDestination ?? 'the email from your RSS feed';
    return _ClaimPage(
      title: 'Enter verification code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Text(
            'Enter verification code',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code we sent to',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          Text(
            destination,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PelevoColors.green),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 26,
              letterSpacing: 20,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (start?.challengeExpiresAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Code expires at ${start!.challengeExpiresAt}',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted, fontSize: 12),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PelevoColors.red),
            ),
          ],
          const SizedBox(height: 34),
          PelevoButton(
            label: _busy ? 'Verifying…' : 'Verify Code',
            color: const Color(0xFF55C51F),
            onPressed:
                !_busy && _controller.text.length == 6 ? _verify : null,
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _busy ? null : _resend,
            child: const Text('Didn’t receive the code? Resend'),
          ),
          const SizedBox(height: 34),
          TextButton(
            onPressed: () => context.go('/screen/claim-method'),
            child: const Text(
              'Change method',
              style: TextStyle(color: PelevoColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class ClaimManualCodeScreen extends ConsumerStatefulWidget {
  const ClaimManualCodeScreen({super.key});

  @override
  ConsumerState<ClaimManualCodeScreen> createState() =>
      _ClaimManualCodeScreenState();
}

class _ClaimManualCodeScreenState extends ConsumerState<ClaimManualCodeScreen> {
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureClaim());
  }

  Future<void> _ensureClaim() async {
    final draft = ref.read(claimDraftProvider);
    final show = draft.show;
    if (show == null) {
      context.go('/screen/claim-podcast');
      return;
    }
    if (draft.start?.method == 'description' && draft.start?.challenge != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final start = await ref
          .read(claimRepositoryProvider)
          .startClaim(showId: show.id, method: 'description');
      ref.read(claimDraftProvider.notifier).rememberStart(start);
      if (!mounted) return;
      setState(() => _busy = false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _claimError(error);
      });
    }
  }

  Future<void> _submit() async {
    final start = ref.read(claimDraftProvider).start;
    if (start == null || start.method != 'description') {
      await _ensureClaim();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(claimRepositoryProvider)
          .confirmDescription(start.claimId);
      ref.read(claimDraftProvider.notifier).rememberStatus(status);
      if (mounted) context.push('/screen/claim-review');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _claimError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(claimDraftProvider).start?.challenge;
    return _ClaimPage(
      title: 'Add Verification Code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const _StepDots(),
          const SizedBox(height: 30),
          Text(
            'Add a verification code to\nyour podcast description',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Add the unique code below to your podcast description in your RSS feed. Our team will manually review and verify your ownership.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.pelevo.textMuted),
          ),
          const SizedBox(height: 26),
          _InfoCard(
            icon: Icons.key_rounded,
            title: 'Your verification code',
            body:
                challenge ??
                (_busy
                    ? 'Requesting a verification code…'
                    : 'A verification code will appear here after the claim starts.'),
            highlightBody: challenge != null,
            trailingCopy: challenge != null,
            onCopy:
                challenge == null
                    ? null
                    : () async {
                      await Clipboard.setData(ClipboardData(text: challenge));
                      if (context.mounted) {
                        context.showPelevoMessage('Verification code copied');
                      }
                    },
          ),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.description_outlined,
            title: 'Where to add the code',
            body:
                'Add the code anywhere in your podcast description. It can be at the beginning, middle, or end.${challenge == null ? '' : '\n\nExample\nWelcome to our podcast!\n\n$challenge\n\nNew episodes every week. Subscribe now!'}',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.schedule_rounded,
            title: 'What happens next?',
            body:
                '✓  Add the verification code to your podcast description.\n\n✓  Our team will manually review your podcast.\n\n✓  You’ll get notified via email once your podcast is verified.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: PelevoColors.red)),
          ],
          const SizedBox(height: 24),
          PelevoButton(
            label:
                _busy
                    ? 'Submitting…'
                    : 'I’ve added the code, submit for review',
            color: const Color(0xFF55C51F),
            onPressed: _busy || challenge == null ? null : _submit,
          ),
          const SizedBox(height: 14),
          const _SupportLink(),
        ],
      ),
    );
  }
}

class ClaimReviewScreen extends ConsumerStatefulWidget {
  const ClaimReviewScreen({super.key});

  @override
  ConsumerState<ClaimReviewScreen> createState() => _ClaimReviewScreenState();
}

class _ClaimReviewScreenState extends ConsumerState<ClaimReviewScreen> {
  var _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(claimDraftProvider).start != null) _check();
    });
  }

  Future<void> _check() async {
    final start = ref.read(claimDraftProvider).start;
    if (start == null) {
      context.go('/screen/claim-status');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(claimRepositoryProvider)
          .readClaim(start.claimId);
      ref.read(claimDraftProvider.notifier).rememberStatus(status);
      if (!mounted) return;
      if (status.isVerified) {
        PodcastCreatorService.instance.claim();
        await ref.read(authSessionProvider.notifier).bootstrap();
        if (mounted) context.go('/screen/claim-success');
        return;
      }
      if (status.isFailed) {
        context.go('/screen/claim-failed');
        return;
      }
      setState(() => _checking = false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = _claimError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(claimDraftProvider).status;
    final codeMissing =
        status != null &&
        status.method == 'description' &&
        status.state == 'pending';
    return _ClaimPage(
      title: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 44),
          const _ClaimHero(
            icon: Icons.pending_actions_rounded,
            title: 'Code submitted!',
            body:
                'Our team will review your podcast\ndescription and verify your ownership.',
          ),
          const SizedBox(height: 34),
          _InfoCard(
            icon: Icons.schedule_rounded,
            title: 'What happens next?',
            body:
                '✓  We’ll manually review your RSS feed.\n\n✓  You’ll get notified in the app and via email once your podcast is verified.\n\n✓  This usually takes 1–3 business days.\n\n✓  You can come back any time from Creator Studio › My claim requests.${status == null ? '' : '\n\nCurrent status: ${_claimStateLabel(status.state, status.method)}'}',
          ),
          if (codeMissing) ...[
            const SizedBox(height: 14),
            const _InfoCard(
              icon: Icons.error_outline_rounded,
              color: PelevoColors.red,
              title: 'Code not found in your RSS feed',
              body:
                  'We couldn’t find the verification code in your podcast description yet. RSS hosts can take a while to update — add the code, wait a few minutes and submit again.',
            ),
            const SizedBox(height: 14),
            PelevoButton(
              label: 'Submit again',
              color: const Color(0xFF55C51F),
              onPressed:
                  _checking
                      ? null
                      : () => context.push('/screen/claim-manual-code'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: PelevoColors.red)),
          ],
          const SizedBox(height: 28),
          PelevoButton(
            label: _checking ? 'Checking…' : 'Check status',
            outlined: true,
            color: PelevoColors.green,
            onPressed: _checking ? null : _check,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/screen/claim-status'),
            child: const Text(
              'View all my claim requests',
              style: TextStyle(color: PelevoColors.green),
            ),
          ),
          const SizedBox(height: 4),
          const _SupportLink(),
        ],
      ),
    );
  }
}

String _claimStateLabel(String state, String method) => ClaimSummary(
  id: '-',
  showId: '-',
  method: method,
  state: state,
  showTitle: '',
).stateLabel;

class ClaimStatusListScreen extends ConsumerWidget {
  const ClaimStatusListScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ClaimSummary claim,
  ) async {
    ref.read(claimDraftProvider.notifier).resume(claim);
    if (claim.isVerified) {
      context.push('/screen/claim-success');
      return;
    }
    if (claim.isFailed) {
      context.push('/screen/claim-failed');
      return;
    }
    if (claim.method == 'email' && claim.needsAction) {
      context.push('/screen/claim-enter-code');
      return;
    }
    context.push('/screen/claim-review');
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ClaimSummary claim,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete this request?'),
            content: Text(
              'Remove the ${claim.stateLabel.toLowerCase()} request for ${claim.showTitle.isEmpty ? 'this podcast' : claim.showTitle}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(claimRepositoryProvider).deleteClaim(claim.id);
      ref.invalidate(myClaimsProvider);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final failure =
          error is ApiFailure
              ? error
              : error is DioException
              ? apiFailureFromDio(error)
              : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure?.message ?? 'This claim request could not be deleted.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(myClaimsProvider);
    return _ClaimPage(
      title: 'My claim requests',
      child: claims.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    _claimError(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pelevo.textMuted),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(myClaimsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
          data: (items) {
            if (items.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 44),
                  const _ClaimHero(
                    icon: Icons.inbox_outlined,
                    title: 'No claim requests yet',
                    body:
                        'Claim your podcast to unlock creator tools.\nYour requests and their status will show here.',
                  ),
                  const SizedBox(height: 24),
                  PelevoButton(
                    label: 'Claim a podcast',
                    color: const Color(0xFF55C51F),
                    onPressed: () => context.push('/screen/claim-podcast'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tap a request to see details.',
                        style: TextStyle(
                          color: context.pelevo.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(myClaimsProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final claim in items) ...[
                  _ClaimStatusTile(
                    claim: claim,
                    onTap: () => _open(context, ref, claim),
                    onDelete:
                        claim.canDelete
                            ? () => _delete(context, ref, claim)
                            : null,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                const _SupportLink(),
              ],
            );
          },
        ),
    );
  }
}

class _ClaimStatusTile extends StatelessWidget {
  const _ClaimStatusTile({
    required this.claim,
    required this.onTap,
    this.onDelete,
  });
  final ClaimSummary claim;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color =
        claim.isVerified
            ? PelevoColors.green
            : claim.isFailed
            ? PelevoColors.red
            : claim.needsAction
            ? PelevoColors.orange
            : PelevoColors.blue;
    final icon =
        claim.isVerified
            ? Icons.verified_rounded
            : claim.isFailed
            ? Icons.gpp_bad_rounded
            : claim.needsAction
            ? Icons.error_outline_rounded
            : Icons.pending_actions_rounded;
    final submitted = claim.createdAt?.toLocal();
    return InkWell(
      onTap: onTap,
      borderRadius: PelevoRadii.card,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.pelevo.surface,
          borderRadius: PelevoRadii.card,
          border: Border.all(color: context.pelevo.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child:
                    claim.showArtworkUrl == null ||
                            claim.showArtworkUrl!.isEmpty
                        ? Container(
                          color: context.pelevo.surfaceHigh,
                          child: const Icon(Icons.podcasts_rounded),
                        )
                        : Image.network(
                          claim.showArtworkUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => Container(
                                color: context.pelevo.surfaceHigh,
                                child: const Icon(Icons.podcasts_rounded),
                              ),
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claim.showTitle.isEmpty ? 'Podcast' : claim.showTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          claim.stateLabel,
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (submitted != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Submitted ${submitted.year}-${submitted.month.toString().padLeft(2, '0')}-${submitted.day.toString().padLeft(2, '0')} · ${claim.method == 'email' ? 'Email code' : 'RSS description'}',
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (claim.isFailed &&
                      (claim.decisionReason?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 3),
                    Text(
                      claim.decisionReason!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.pelevo.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete request',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: PelevoColors.red,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class ClaimSuccessScreen extends ConsumerStatefulWidget {
  const ClaimSuccessScreen({super.key});

  @override
  ConsumerState<ClaimSuccessScreen> createState() => _ClaimSuccessScreenState();
}

class _ClaimSuccessScreenState extends ConsumerState<ClaimSuccessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PodcastCreatorService.instance.claim();
      ref.read(authSessionProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title =
        ref.watch(claimDraftProvider).show?.title ?? 'this podcast';
    return _ClaimPage(
    title: '',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 44),
        _ClaimHero(
          icon: Icons.verified_rounded,
          title: 'You’re verified!',
          body: 'You are now the verified owner of\n$title on Pelevo.',
        ),
        const SizedBox(height: 34),
        const _InfoCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Verification complete',
          body:
              '✓  Ownership verified\n\n✓  Creator profile activated\n\n✓  Podcast management unlocked',
        ),
        const SizedBox(height: 24),
        PelevoButton(
          label: 'Go to Creator Dashboard',
          color: const Color(0xFF55C51F),
          onPressed: () => context.go('/screen/creator-dashboard'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/screen/claim-podcast'),
          child: const Text(
            'View Podcast Page',
            style: TextStyle(color: PelevoColors.green),
          ),
        ),
      ],
    ),
    );
  }
}

class ClaimFailedScreen extends StatelessWidget {
  const ClaimFailedScreen({super.key});

  @override
  Widget build(BuildContext context) => _ClaimPage(
    title: '',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 44),
        const _ClaimHero(
          icon: Icons.gpp_bad_rounded,
          color: PelevoColors.red,
          title: 'We couldn’t verify\nyour ownership',
          body:
              'We couldn’t find the verification code in your\npodcast description.',
        ),
        const SizedBox(height: 34),
        const _InfoCard(
          icon: Icons.error_outline_rounded,
          color: PelevoColors.red,
          title: 'What you can do',
          body:
              '○  Make sure the code is added to your podcast description.\n\n○  Ensure your RSS feed is public and accessible.\n\n○  Try again or contact support if you need help.',
        ),
        const SizedBox(height: 24),
        PelevoButton(
          label: 'Try Again',
          color: const Color(0xFF55C51F),
          onPressed: () => context.go('/screen/claim-method'),
        ),
        const SizedBox(height: 12),
        const _SupportLink(),
      ],
    ),
  );
}

class _ClaimPage extends StatelessWidget {
  const _ClaimPage({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed:
            () =>
                context.canPop()
                    ? context.pop()
                    : context.go('/screen/claim-podcast'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(title),
      centerTitle: true,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: child,
      ),
    ),
  );
}

class _ClaimHero extends StatelessWidget {
  const _ClaimHero({
    required this.icon,
    required this.title,
    required this.body,
    this.color = PelevoColors.green,
    this.compact = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: compact ? 86 : 108,
        height: compact ? 86 : 108,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .6), color.withValues(alpha: .08)],
          ),
        ),
        child: Icon(icon, size: compact ? 42 : 54, color: color),
      ),
      const SizedBox(height: 18),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        body,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.pelevo.textMuted),
      ),
    ],
  );
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
    this.recommended = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: PelevoRadii.card,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pelevo.surface,
        borderRadius: PelevoRadii.card,
        border: Border.all(
          color: recommended ? PelevoColors.green : context.pelevo.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: color.withValues(alpha: .18),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (recommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: PelevoColors.green.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            color: PelevoColors.green,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: context.pelevo.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.color = PelevoColors.green,
    this.highlightBody = false,
    this.trailingCopy = false,
    this.onCopy,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final bool highlightBody;
  final bool trailingCopy;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pelevo.surface,
      borderRadius: PelevoRadii.card,
      border: Border.all(color: context.pelevo.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color:
                      highlightBody
                          ? PelevoColors.green
                          : context.pelevo.textMuted,
                  fontSize: highlightBody ? 17 : 12,
                  fontWeight:
                      highlightBody ? FontWeight.w700 : FontWeight.normal,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (trailingCopy)
          IconButton(
            tooltip: 'Copy verification code',
            onPressed:
                onCopy ??
                () => context.showPelevoMessage('Verification code copied'),
            icon: const Icon(Icons.copy_rounded),
          ),
      ],
    ),
  );
}

class _StepDots extends StatelessWidget {
  const _StepDots();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 3; i++) ...[
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == 0 ? PelevoColors.green : context.pelevo.textDim,
            border: i == 0 ? Border.all(color: PelevoColors.green) : null,
          ),
        ),
        if (i < 2) Container(width: 42, height: 1, color: context.pelevo.textDim),
      ],
    ],
  );
}

class _SupportLink extends StatelessWidget {
  const _SupportLink();

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/screen/profile-help'),
    child: Text.rich(
      TextSpan(
        text: 'Need help? ',
        style: TextStyle(color: context.pelevo.textMuted),
        children: [
          TextSpan(
            text: 'Contact support',
            style: TextStyle(color: PelevoColors.green),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  );
}
