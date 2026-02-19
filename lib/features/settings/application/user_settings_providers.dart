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
    state = const AsyncLoading<UserSettingsModel>();
    state = AsyncData(await ref.read(userSettingsRepositoryProvider).get());
  }

  Future<void> updateName(String displayName) async {
    await ref.read(userSettingsRepositoryProvider).updateName(displayName);
    await refresh();
  }

  Future<void> updateTrack(String track) async {
    await ref.read(userSettingsRepositoryProvider).updateTrack(track);
    await refresh();
  }

  Future<void> updateRole(String role) async {
    await ref.read(userSettingsRepositoryProvider).updateRole(role);
    await refresh();
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    await ref
        .read(userSettingsRepositoryProvider)
        .updateNotificationsEnabled(enabled);
    await refresh();
  }

  Future<void> updateStudyReminderEnabled(bool enabled) async {
    await ref
        .read(userSettingsRepositoryProvider)
        .updateStudyReminderEnabled(enabled);
    await refresh();
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
    return settings.maybeWhen(
      data: (value) => value.track,
      orElse: () => UserSettingsRepository.defaultTrack,
    );
  }

  Future<void> setTrack(String track) async {
    if (state == track) {
      return;
    }
    state = track;
    await ref.read(userSettingsProvider.notifier).updateTrack(track);
  }
}

final selectedTrackProvider = NotifierProvider<SelectedTrackNotifier, String>(
  SelectedTrackNotifier.new,
);

final displayNameProvider = Provider<String>((Ref ref) {
  final settings = ref.watch(userSettingsProvider);
  return settings.maybeWhen(
    data: (value) {
      final trimmed = value.displayName.trim();
      return trimmed.isEmpty ? '지훈' : trimmed;
    },
    orElse: () => '지훈',
  );
});
