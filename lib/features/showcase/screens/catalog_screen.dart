import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/features/showcase/models/screen_spec.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({required this.screens, super.key});

  final List<PelevoScreenSpec> screens;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<PelevoScreenSpec>>{};
    for (final screen in screens) {
      groups.putIfAbsent(screen.section, () => []).add(screen);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelevo UI'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: PelevoSpacing.md),
            child: Center(
              child: Text(
                '${screens.length} states',
                style: const TextStyle(color: PelevoColors.green),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          PelevoSpacing.page,
          PelevoSpacing.sm,
          PelevoSpacing.page,
          PelevoSpacing.xxl,
        ),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final entry = groups.entries.elementAt(index);
          return Card(
            color: context.pelevo.surface,
            margin: const EdgeInsets.only(bottom: PelevoSpacing.sm),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              title: Text(entry.key),
              subtitle: Text('${entry.value.length} screens / states'),
              children: [
                for (final screen in entry.value)
                  ListTile(
                    title: Text(screen.title),
                    subtitle: screen.state == null ? null : Text(screen.state!),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/screen/${screen.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
