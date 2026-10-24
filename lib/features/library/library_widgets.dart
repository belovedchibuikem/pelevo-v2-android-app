import 'package:flutter/material.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';

class UtilityScreen extends StatelessWidget {
  const UtilityScreen({
    required this.title,
    required this.children,
    super.key,
    this.navIndex = 2,
    this.leading = true,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final int navIndex;
  final bool leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PelevoPage(
    appBar: AppBar(
      leading:
          leading
              ? IconButton(
                tooltip: 'Back',
                onPressed: () => context.pelevoBack(fallback: '/screen/library-1'),
                icon: const Icon(Icons.arrow_back_rounded),
              )
              : null,
      automaticallyImplyLeading: false,
      title: Text(title),
      actions: action == null ? null : [action!],
    ),
    bottomNavigationBar: PelevoBottomNavigation(
      index: navIndex,
      onDestinationSelected: context.openPelevoTab,
    ),
    child: Semantics(
      container: true,
      label: '$title screen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class UtilityTabs extends StatefulWidget {
  const UtilityTabs(this.labels, {super.key, this.initial = 0});
  final List<String> labels;
  final int initial;

  @override
  State<UtilityTabs> createState() => _UtilityTabsState();
}

class _UtilityTabsState extends State<UtilityTabs> {
  late int selected = widget.initial;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Filter tabs',
    child: SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        for (var i = 0; i < widget.labels.length; i++)
          ButtonSegment(value: i, label: Text(widget.labels[i])),
      ],
      selected: {selected},
      onSelectionChanged: (value) => setState(() => selected = value.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStatePropertyAll(context.pelevo.surface),
      ),
    ),
  );
}

class UtilitySection extends StatelessWidget {
  const UtilitySection(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: PelevoSpacing.xl,
      bottom: PelevoSpacing.xs,
    ),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: context.pelevo.textMuted),
    ),
  );
}

class UtilityRow extends StatelessWidget {
  const UtilityRow({
    required this.title,
    super.key,
    this.subtitle,
    this.icon = Icons.podcasts_rounded,
    this.color = PelevoColors.green,
    this.trailing,
    this.onTap,
    this.artwork = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool artwork;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: PelevoSpacing.xs),
    color: context.pelevo.surface,
    child: ListTile(
      onTap: onTap ?? () => context.showPelevoMessage(title),
      leading:
          artwork
              ? PelevoArtwork(label: title, size: 46, color: color, icon: icon)
              : Icon(icon, color: color),
      title: Text(title),
      subtitle:
          subtitle == null
              ? null
              : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class ToggleRow extends StatefulWidget {
  const ToggleRow({
    required this.title,
    super.key,
    this.subtitle,
    this.initial = true,
    this.icon = Icons.notifications_outlined,
  });

  final String title;
  final String? subtitle;
  final bool initial;
  final IconData icon;

  @override
  State<ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<ToggleRow> {
  late bool value = widget.initial;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(widget.icon, color: PelevoColors.green),
    contentPadding: EdgeInsets.zero,
    title: Text(widget.title),
    subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
    value: value,
    onChanged: (next) => setState(() => value = next),
  );
}

class ChoiceList extends StatefulWidget {
  const ChoiceList({required this.options, super.key, this.initial = 0});

  final List<(String, String)> options;
  final int initial;

  @override
  State<ChoiceList> createState() => _ChoiceListState();
}

class _ChoiceListState extends State<ChoiceList> {
  late int selected = widget.initial;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < widget.options.length; i++)
        RadioListTile<int>(
          value: i,
          groupValue: selected,
          title: Text(widget.options[i].$1),
          subtitle: Text(widget.options[i].$2),
          activeColor: PelevoColors.green,
          onChanged: (value) => setState(() => selected = value!),
        ),
    ],
  );
}

class UtilityHero extends StatelessWidget {
  const UtilityHero({
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
  Widget build(BuildContext context) =>
      PelevoStateHero(icon: icon, title: title, body: body, color: color);
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    super.key,
  });

  final String title;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) => Card(
    color: context.pelevo.surface,
    child: Padding(
      padding: const EdgeInsets.all(PelevoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PelevoSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: PelevoSpacing.sm),
          Semantics(
            label: '${(progress * 100).round()} percent complete',
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: PelevoColors.green,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    ),
  );
}

class StorageChart extends StatelessWidget {
  const StorageChart({
    required this.used,
    required this.total,
    required this.items,
    super.key,
    this.donut = true,
    this.centerLabel,
    this.semanticsLabel,
  });

  final double used;
  final double total;
  final List<(String, String, Color)> items;
  final bool donut;
  final String? centerLabel;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel ?? '$used GB used of $total GB',
      child: Card(
        color: context.pelevo.surface,
        child: Padding(
          padding: const EdgeInsets.all(PelevoSpacing.lg),
          child: Column(
            children: [
              if (donut)
                SizedBox.square(
                  dimension: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        color: PelevoColors.green,
                        backgroundColor: context.pelevo.border,
                      ),
                      Text(
                        centerLabel ?? '$used GB\nUsed',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              else
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  color: PelevoColors.green,
                  backgroundColor: context.pelevo.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              const SizedBox(height: PelevoSpacing.lg),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: PelevoSpacing.sm),
                      Expanded(child: Text(item.$1)),
                      Text(item.$2),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectionList extends StatefulWidget {
  const SelectionList({
    required this.items,
    required this.actionLabel,
    super.key,
    this.destructive = false,
  });

  final List<String> items;
  final String actionLabel;
  final bool destructive;

  @override
  State<SelectionList> createState() => _SelectionListState();
}

class _SelectionListState extends State<SelectionList> {
  final selected = <int>{0, 1, 2};

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < widget.items.length; i++)
        CheckboxListTile(
          value: selected.contains(i),
          title: Text(widget.items[i]),
          activeColor: PelevoColors.green,
          onChanged:
              (_) => setState(
                () =>
                    selected.contains(i) ? selected.remove(i) : selected.add(i),
              ),
        ),
      const SizedBox(height: PelevoSpacing.md),
      PelevoButton(
        label: '${widget.actionLabel} (${selected.length})',
        color: widget.destructive ? PelevoColors.red : PelevoColors.green,
        onPressed:
            selected.isEmpty
                ? null
                : () => context.showPelevoMessage(
                  '${widget.actionLabel}: ${selected.length} selected',
                ),
      ),
    ],
  );
}
