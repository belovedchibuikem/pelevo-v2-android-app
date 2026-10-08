import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/support_data.dart';

Future<void> showSupportForm(
  BuildContext context, {
  required bool feedback,
}) async {
  final receipt = await showDialog<SupportReceipt>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SupportFormDialog(feedback: feedback),
  );
  if (receipt != null && context.mounted) {
    context.showPelevoMessage(
      '${feedback ? 'Feedback received' : 'Support request received'}. Reference: ${receipt.id}',
    );
  }
}

class SupportFormDialog extends ConsumerStatefulWidget {
  const SupportFormDialog({super.key, required this.feedback});
  final bool feedback;
  @override
  ConsumerState<SupportFormDialog> createState() => _SupportFormDialogState();
}

class _SupportFormDialogState extends ConsumerState<SupportFormDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _type = 'idea';
  int? _rating;
  bool _submitting = false;
  bool _closing = false;
  ApiFailure? _failure;
  String? _fingerprint, _requestId, _ownerId;

  @override
  void initState() {
    super.initState();
    _ownerId = ref.read(authSessionProvider).userId;
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_submitting || _closing) return;
    _closing = true;
    try {
      if (_subject.text.trim().isNotEmpty || _message.text.trim().isNotEmpty) {
        final discard = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Discard this message?'),
                content: const Text('Your draft will not be saved.'),
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
      if (mounted) Navigator.pop(context);
    } finally {
      _closing = false;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _failure = null);
    if (!_form.currentState!.validate()) return;
    final fingerprint = jsonEncode([
      widget.feedback,
      _subject.text.trim(),
      _message.text.trim(),
      _type,
      _rating,
    ]);
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _requestId = newSupportRequestId();
    }
    setState(() => _submitting = true);
    try {
      if (_ownerId == null ||
          ref.read(authSessionProvider).userId != _ownerId) {
        throw const ApiFailure(
          code: 'SESSION_CHANGED',
          message: 'Please sign in again before sending this message.',
        );
      }
      final repository = ref.read(supportRepositoryProvider);
      final receipt =
          widget.feedback
              ? await repository.feedback(
                type: _type,
                message: _message.text,
                rating: _rating,
                requestId: _requestId!,
              )
              : await repository.ticket(
                subject: _subject.text,
                message: _message.text,
                requestId: _requestId!,
              );
      if (!mounted) return;
      if (ref.read(authSessionProvider).userId != _ownerId) {
        throw const ApiFailure(
          code: 'SESSION_CHANGED',
          message: 'Your account changed. Open Support again to continue.',
        );
      }
      Navigator.pop(context, receipt);
    } on Object catch (error) {
      if (mounted) setState(() => _failure = profileFailure(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _cancel();
    },
    child: AlertDialog(
      title: Text(widget.feedback ? 'Send Feedback' : 'Contact Support'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_submitting) const LinearProgressIndicator(),
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
                if (!widget.feedback)
                  TextFormField(
                    controller: _subject,
                    enabled: !_submitting,
                    maxLength: 191,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      errorText: _failure?.fields['subject'],
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a subject.'
                                : null,
                  ),
                if (widget.feedback)
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: InputDecoration(
                      labelText: 'Feedback type',
                      errorText: _failure?.fields['type'],
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'idea',
                        child: Text('Suggestion'),
                      ),
                      DropdownMenuItem(value: 'bug', child: Text('Bug report')),
                      DropdownMenuItem(value: 'rating', child: Text('Rating')),
                    ],
                    onChanged:
                        _submitting
                            ? null
                            : (value) => setState(() => _type = value!),
                  ),
                if (widget.feedback && _type == 'rating')
                  DropdownButtonFormField<int>(
                    value: _rating,
                    decoration: InputDecoration(
                      labelText: 'Rating',
                      errorText: _failure?.fields['rating'],
                    ),
                    items: [
                      for (var value = 1; value <= 5; value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text('$value / 5'),
                        ),
                    ],
                    onChanged:
                        _submitting
                            ? null
                            : (value) => setState(() => _rating = value),
                    validator:
                        (value) => value == null ? 'Choose a rating.' : null,
                  ),
                const SizedBox(height: PelevoSpacing.sm),
                TextFormField(
                  controller: _message,
                  enabled: !_submitting,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 5000,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    errorText: _failure?.fields['message'],
                  ),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter your message.'
                              : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Sending…' : 'Send'),
        ),
      ],
    ),
  );
}
