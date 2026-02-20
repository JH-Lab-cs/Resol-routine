import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/user_settings_repository.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return UserSettingsRepository(database: database);
});

class UserSettingsNotifier extends AsyncNotifier<UserSettingsModel> {
  @override
  Future<UserSettingsModel> build() {
    return ref.read(userSettingsRepositoryProvider).get();
  }

  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<UserSettingsModel>().copyWithPrevious(
      previous,
      isRefresh: true,
    );
    await _syncFromDatabase(previous: previous);
  }

  Future<void> updateName(String displayName) async {
    await _persistAndPublish(
      (repository) => repository.updateName(displayName),
    );
  }

  Future<void> updateBirthDate(String birthDate) async {
    await _persistAndPublish(
      (repository) => repository.updateBirthDate(birthDate),
    );
  }

  Future<void> updateTrack(String track) async {
    await _persistAndPublish((repository) => repository.updateTrack(track));
  }

  Future<void> updateRole(String role) async {
    await _persistAndPublish((repository) => repository.updateRole(role));
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    await _persistAndPublish(
      (repository) => repository.updateNotificationsEnabled(enabled),
    );
  }

  Future<void> updateStudyReminderEnabled(bool enabled) async {
    await _persistAndPublish(
      (repository) => repository.updateStudyReminderEnabled(enabled),
    );
  }

  Future<void> logout() async {
    await _persistAndPublish((repository) => repository.resetForLogout());
  }

  Future<void> withdraw() async {
    await _persistAndPublish((repository) => repository.resetForWithdrawal());
  }

  Future<void> _persistAndPublish(
    Future<void> Function(UserSettingsRepository repository) mutation,
  ) async {
    final repository = ref.read(userSettingsRepositoryProvider);
    final previous = state;
    try {
      await mutation(repository);
      final updated = await repository.get();
      state = AsyncData(updated);
    } catch (error, stackTrace) {
      final previousValue = previous.valueOrNull;
      if (previousValue != null) {
        state = AsyncData(previousValue);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _syncFromDatabase({
    required AsyncValue<UserSettingsModel> previous,
  }) async {
    try {
      final settings = await ref.read(userSettingsRepositoryProvider).get();
      state = AsyncData(settings);
    } catch (error, stackTrace) {
      final previousValue = previous.valueOrNull;
      if (previousValue != null) {
        state = AsyncData(previousValue);
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, UserSettingsModel>(
      UserSettingsNotifier.new,
    );

class SelectedTrackNotifier extends Notifier<String> {
  @override
  String build() {
    final settings = ref.watch(userSettingsProvider);
    return settings.valueOrNull?.track ?? UserSettingsRepository.defaultTrack;
  }

  Future<void> setTrack(String track) async {
    if (state == track) {
      return;
    }
    final previous = state;
    state = track;
    try {
      await ref.read(userSettingsProvider.notifier).updateTrack(track);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final selectedTrackProvider = NotifierProvider<SelectedTrackNotifier, String>(
  SelectedTrackNotifier.new,
);

final displayNameProvider = Provider<String>((Ref ref) {
  final settings = ref.watch(userSettingsProvider);
  final trimmed = settings.valueOrNull?.displayName.trim() ?? '';
  return trimmed.isEmpty ? '사용자' : trimmed;
});
