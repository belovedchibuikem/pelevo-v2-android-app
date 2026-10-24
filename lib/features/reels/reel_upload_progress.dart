import 'package:flutter/material.dart';
import 'package:pelevo/core/theme/app_theme.dart';

class ReelUploadProgressBar extends StatelessWidget {
  const ReelUploadProgressBar({
    super.key,
    required this.stage,
    this.progress,
  });

  final String stage;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final value = progress;
    final percent =
        value == null ? null : '${(value.clamp(0, 1) * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stage,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.pelevo.textMuted,
                ),
              ),
            ),
            if (percent != null)
              Text(
                percent,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: PelevoColors.green,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: context.pelevo.border,
            color: PelevoColors.green,
          ),
        ),
      ],
    );
  }
}

class ReelDetailsFields extends StatelessWidget {
  const ReelDetailsFields({
    super.key,
    required this.titleController,
    required this.descriptionController,
    this.enabled = true,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: titleController,
          enabled: enabled,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Name this reel',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: descriptionController,
          enabled: enabled,
          maxLines: 4,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'What is this reel about?',
          ),
        ),
      ],
    );
  }
}
