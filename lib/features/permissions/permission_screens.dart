import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/notifications/firebase_push.dart';
import 'package:pelevo/features/onboarding/onboarding_progress.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionIntroScreen extends ConsumerWidget {
  const PermissionIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PelevoPage(
    appBar: AppBar(
      leading: const PelevoBackButton(fallback: '/screen/library-1'),
      title: const Text('App Permissions'),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const _PermissionArtwork(
              assetPath: 'assets/permissions/intro_brand.png',
              semanticLabel: 'Pelevo logo',
              width: 150,
              height: 216,
            ),
            const SizedBox(height: PelevoSpacing.sm),
            Text(
              "Let's get you set up",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'Pelevo needs a few permissions\nto work properly and improve\nyour experience.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted, height: 1.5),
            ),
            const SizedBox(height: 44),
            PelevoButton(
              label: 'Continue',
              onPressed: () => context.go('/screen/permissions-notifications'),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(onboardingProgressStoreProvider)
                    .markPermissionsComplete();
                if (context.mounted) {
                  context.pelevoBack(fallback: '/screen/home-feed');
                }
              },
              child: const Text(
                'Maybe Later',
                style: TextStyle(color: PelevoColors.green),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PermissionRequestScreen extends ConsumerStatefulWidget {
  const PermissionRequestScreen({
    required this.title,
    required this.body,
    required this.assetPath,
    required this.allowLabel,
    required this.step,
    required this.previousId,
    required this.nextId,
    super.key,
  });

  final String title;
  final String body;
  final String assetPath;
  final String allowLabel;
  final int step;
  final String previousId;
  final String nextId;

  @override
  ConsumerState<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState
    extends ConsumerState<PermissionRequestScreen> {
  bool _submitting = false;

  @override
  void didUpdateWidget(covariant PermissionRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextId != widget.nextId) {
      _submitting = false;
    }
  }

  Future<void> _complete(bool allowed) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (allowed) {
        final permission = switch (widget.nextId) {
          'permissions-microphone' => Permission.notification,
          'permissions-storage' => Permission.microphone,
          _ => null,
        };
        if (permission != null &&
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)) {
          final status = await permission.request();
          if (!mounted) return;
          if (status.isPermanentlyDenied || status.isRestricted) {
            await showDialog<void>(
              context: context,
              builder:
                  (dialogContext) => AlertDialog(
                    title: const Text('Permission unavailable'),
                    content: const Text(
                      'You can continue and enable access in Settings when needed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Continue'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await openAppSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );
          }
        }
        if (widget.nextId == 'permissions-microphone') {
          unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
        }
      }
      if (mounted) context.go('/screen/${widget.nextId}');
    } on Object {
      if (mounted) {
        context.showPelevoMessage(
          'Access could not be requested. You can enable it in Settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PelevoPage(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => context.pelevoBack(
                  fallback: '/screen/${widget.previousId}',
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 18),
            _PermissionArtwork(
              assetPath: widget.assetPath,
              semanticLabel: '${widget.title} permission illustration',
            ),
            const SizedBox(height: PelevoSpacing.xl),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PelevoSpacing.md),
            Text(
              widget.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.pelevo.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 40),
            PelevoButton(
              label: _submitting ? 'Please wait…' : widget.allowLabel,
              color: PelevoColors.green,
              onPressed: _submitting ? null : () => _complete(true),
            ),
            const SizedBox(height: PelevoSpacing.sm),
            PelevoButton(
              label: 'Not Now',
              outlined: true,
              color: PelevoColors.yellow,
              foregroundColor: context.pelevo.text,
              onPressed: _submitting ? null : () => _complete(false),
            ),
            const SizedBox(height: 36),
            _ProgressDots(active: widget.step),
          ],
        ),
      ),
    ),
  );
}

class PermissionsCompleteScreen extends ConsumerWidget {
  const PermissionsCompleteScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    unawaited(ref.read(pelevoFirebasePushProvider).bootstrap());
    await ref.read(onboardingProgressStoreProvider).markPermissionsComplete();
    if (context.mounted) context.go('/screen/home-feed');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PelevoPage(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Column(
          children: [
            const SizedBox(height: 72),
            const _PermissionArtwork(
              assetPath: 'assets/permissions/complete.png',
              semanticLabel: 'Permissions complete shield',
            ),
            const SizedBox(height: PelevoSpacing.xl),
            Text(
              "You're all set!",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: PelevoSpacing.lg),
            Text(
              'You can change these\npermissions anytime in\nSettings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.pelevo.textMuted, height: 1.5),
            ),
            const SizedBox(height: 44),
            PelevoButton(
              label: 'Finish Setup',
              onPressed: () => _finish(context, ref),
            ),
            TextButton(
              onPressed: () => _finish(context, ref),
              child: const Text(
                'Go to App',
                style: TextStyle(color: PelevoColors.green),
              ),
            ),
            const SizedBox(height: PelevoSpacing.xl),
            const _ProgressDots(active: 3),
          ],
        ),
      ),
    ),
  );
}

class _PermissionArtwork extends StatelessWidget {
  const _PermissionArtwork({
    required this.assetPath,
    required this.semanticLabel,
    this.width = 150,
    this.height = 170,
  });

  final String assetPath;
  final String semanticLabel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder:
          (context, error, stackTrace) => SizedBox(
            width: width,
            height: height,
            child: const Icon(
              Icons.security_rounded,
              size: 72,
              color: PelevoColors.red,
            ),
          ),
    ),
  );
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Setup progress, step ${active + 1} of 4',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (index) => AnimatedContainer(
          duration: PelevoMotion.fast,
          width: index == active ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: index == active ? PelevoColors.red : context.pelevo.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}
