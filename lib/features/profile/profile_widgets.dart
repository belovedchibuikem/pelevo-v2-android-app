import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/services/app_services.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/profile/profile_data.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.url,
    this.size = 72,
    this.borderWidth = 2,
  });
  final String? url;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = url == null ? null : Uri.tryParse(url!);
    final source =
        parsed == null
            ? null
            : Uri.parse(
              ref.watch(dioProvider).options.baseUrl,
            ).resolveUri(parsed);
    final placeholder = Icon(
      Icons.person_outline_rounded,
      size: size * .48,
      color: context.pelevo.textMuted,
    );
    return Semantics(
      label: 'Profile photo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: PelevoColors.green, width: borderWidth),
        ),
        child: ClipOval(
          child:
              source == null || !['http', 'https'].contains(source.scheme)
                  ? placeholder
                  : Image.network(
                    source.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                    loadingBuilder:
                        (_, child, progress) =>
                            progress == null ? child : placeholder,
                  ),
        ),
      ),
    );
  }
}

class ProfileNavAvatar extends ConsumerWidget {
  const ProfileNavAvatar({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(profileProvider).asData?.value.avatarUrl;
    return Semantics(
      button: true,
      label: 'Open profile',
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: () => context.pelevoOpen('/screen/profile'),
        child: ProfileAvatar(url: url, size: size, borderWidth: 1.5),
      ),
    );
  }
}

class ProfileLoadState extends StatelessWidget {
  const ProfileLoadState({super.key, this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PelevoSpacing.xl),
    child: Center(
      child:
          error == null
              ? const CircularProgressIndicator()
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profileFailure(error!).message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: PelevoSpacing.sm),
                  OutlinedButton(onPressed: retry, child: const Text('Retry')),
                ],
              ),
    ),
  );
}
