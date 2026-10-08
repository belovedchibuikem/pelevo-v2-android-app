import 'package:flutter/material.dart';
import 'package:pelevo/core/deep_links/pelevo_deep_links.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:go_router/go_router.dart';

/// Resolves `https://pelevo.com/s/{token}` inside the app, then opens the episode.
class ShareLinkResolverScreen extends StatefulWidget {
  const ShareLinkResolverScreen({required this.token, super.key});

  final String token;

  @override
  State<ShareLinkResolverScreen> createState() => _ShareLinkResolverScreenState();
}

class _ShareLinkResolverScreenState extends State<ShareLinkResolverScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final location = await PelevoDeepLinks.resolveShareToken(widget.token);
    if (!mounted) return;
    if (location == null) {
      setState(() => _error = 'This share link is invalid or no longer available.');
      return;
    }
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    return PelevoPage(
      appBar: AppBar(title: const Text('Opening share')),
      child: Center(
        child:
            _error == null
                ? const CircularProgressIndicator()
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: PelevoSpacing.md),
                    PelevoButton(
                      label: 'Go Home',
                      color: PelevoColors.green,
                      onPressed: () => context.go('/screen/home-feed'),
                    ),
                  ],
                ),
      ),
    );
  }
}
