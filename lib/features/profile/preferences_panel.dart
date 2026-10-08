import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pelevo/core/widgets/pelevo_widgets.dart';
import 'package:pelevo/features/authentication/auth_session.dart';
import 'package:pelevo/features/profile/preferences_data.dart';
import 'package:pelevo/features/profile/profile_data.dart';
import 'package:pelevo/features/profile/profile_widgets.dart';

typedef SavePreferences = Future<bool> Function(Map<String, dynamic> changes);

class PreferencesPanel extends ConsumerStatefulWidget {
  const PreferencesPanel({super.key, required this.builder});
  final Widget Function(
    AccountPreferences preferences,
    bool saving,
    SavePreferences save,
  )
  builder;
  @override
  ConsumerState<PreferencesPanel> createState() => _PreferencesPanelState();
}

class _PreferencesPanelState extends ConsumerState<PreferencesPanel> {
  AccountPreferences? _saved;
  Object? _error;
  bool _saving = false;
  int _accountEpoch = 0;

  Future<bool> _save(
    AccountPreferences previous,
    Map<String, dynamic> changes,
  ) async {
    if (_saving || ref.read(authSessionProvider).userId != previous.userId) {
      return false;
    }
    final epoch = _accountEpoch;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(preferencesRepositoryProvider)
          .save(previous, changes);
      if (!mounted ||
          epoch != _accountEpoch ||
          ref.read(authSessionProvider).userId != previous.userId) {
        return false;
      }
      setState(() => _saved = updated);
      ref.invalidate(preferencesProvider);
      context.showPelevoMessage('Preferences saved');
      return true;
    } on Object catch (error) {
      if (mounted && epoch == _accountEpoch) setState(() => _error = error);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reload() {
    setState(() {
      _saved = null;
      _error = null;
    });
    ref.invalidate(preferencesProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider.select((session) => session.userId), (
      previous,
      next,
    ) {
      if (previous != next) {
        _accountEpoch++;
        _saved = null;
        _error = null;
      }
    });
    final owner = ref.watch(
      authSessionProvider.select((session) => session.userId),
    );
    return ref
        .watch(preferencesProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => ProfileLoadState(retry: _reload),
          error: (error, _) => ProfileLoadState(error: error, retry: _reload),
          data: (loaded) {
            final current =
                _saved != null &&
                        _saved!.userId == owner &&
                        _saved!.version > loaded.version
                    ? _saved!
                    : loaded;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saving) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(profileFailure(_error!).message),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _reload,
                    child: const Text('Reload saved preferences'),
                  ),
                ],
                widget.builder(
                  current,
                  _saving,
                  (changes) => _save(current, changes),
                ),
              ],
            );
          },
        );
  }
}
