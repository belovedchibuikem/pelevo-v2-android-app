import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pelevo/core/network/api_contract.dart';
import 'package:pelevo/core/theme/app_theme.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/store/fx_rates.dart';

const _starterCurrencies = ['NGN', 'GHS', 'KES', 'ZAR', 'GBP', 'EUR'];

class AdminFxScreen extends ConsumerStatefulWidget {
  const AdminFxScreen({super.key});

  @override
  ConsumerState<AdminFxScreen> createState() => _AdminFxScreenState();
}

class _AdminFxScreenState extends ConsumerState<AdminFxScreen> {
  final _rows = <_FxEditorRow>[];
  final _extraCode = TextEditingController();
  var _seeded = false;
  var _saving = false;

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    _extraCode.dispose();
    super.dispose();
  }

  void _seed(FxRateBook book) {
    if (_seeded) return;
    _seeded = true;
    final codes = {..._starterCurrencies, ...book.reviewed};
    for (final code in codes) {
      if (code == 'USD') continue;
      final rate = book.rateFor(code);
      _rows.add(
        _FxEditorRow(
          code: code,
          reviewed: book.reviewed.contains(code),
          controller: TextEditingController(
            text: rate == null ? '' : _plain(rate),
          ),
        ),
      );
    }
  }

  void _addCurrency() {
    final code = _extraCode.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code) || code == 'USD') {
      context.showPelevoMessage('Enter a 3-letter currency code.');
      return;
    }
    if (_rows.any((row) => row.code == code)) {
      context.showPelevoMessage('$code is already on the list.');
      return;
    }
    setState(() {
      _rows.add(
        _FxEditorRow(
          code: code,
          reviewed: true,
          controller: TextEditingController(),
        ),
      );
      _extraCode.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final rates = <String, double>{};
    for (final row in _rows) {
      if (!row.reviewed) continue;
      final value = double.tryParse(row.controller.text.trim());
      if (value == null || value <= 0) {
        context.showPelevoMessage('Enter how many ${row.code} equal 1 USD.');
        return;
      }
      rates[row.code] = value;
    }
    if (rates.isEmpty) {
      context.showPelevoMessage('Turn on at least one reviewed currency.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(fxRateRepositoryProvider).saveReviewed(rates);
      ref.invalidate(fxRatesProvider);
      if (!mounted) return;
      context.showPelevoMessage('Exchange rates saved. The app uses this board.');
    } on ApiFailure catch (error) {
      if (!mounted) return;
      context.showPelevoMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(fxRatesProvider);
    return PelevoPage(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/screen/settings-account'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Exchange rates'),
        centerTitle: true,
      ),
      child: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Column(
          children: [
            Text(error is ApiFailure ? error.message : 'Exchange rates could not be loaded.'),
            TextButton(
              onPressed: () => ref.invalidate(fxRatesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (book) {
          _seed(book);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'USD is the lead currency. A reviewed rate is what the app converts into that currency. Currencies left on automatic keep the live rate.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PelevoColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current board: ${book.source}'
                    '${book.quotedAt == null ? '' : ' · ${book.quotedAt!.toLocal()}'}',
                    style: const TextStyle(color: PelevoColors.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  for (final row in _rows) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            row.code,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: row.controller,
                            enabled: row.reviewed,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            decoration: InputDecoration(
                              labelText: '1 USD in ${row.code}',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            const Text('Review', style: TextStyle(fontSize: 11)),
                            Switch(
                              value: row.reviewed,
                              onChanged: (value) => setState(() => row.reviewed = value),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _extraCode,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 3,
                          decoration: const InputDecoration(
                            labelText: 'Add currency',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(onPressed: _addCurrency, child: const Text('Add')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PelevoButton(
                    label: _saving ? 'Saving…' : 'Save reviewed rates',
                    color: PelevoColors.purple,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only a Pelevo admin can save. Listeners and creators keep using this same board.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PelevoColors.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FxEditorRow {
  _FxEditorRow({
    required this.code,
    required this.reviewed,
    required this.controller,
  });

  final String code;
  final TextEditingController controller;
  bool reviewed;
}

String _plain(double value) {
  final text = value.toString();
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
