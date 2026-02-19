import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

void main() {
  group('UserSettingsRepository', () {
    test('creates singleton row with defaults', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final repository = UserSettingsRepository(database: database);
      final settings = await repository.get();

      expect(settings.role, UserSettingsRepository.defaultRole);
      expect(settings.displayName, '');
      expect(settings.track, UserSettingsRepository.defaultTrack);
      expect(settings.notificationsEnabled, true);
      expect(settings.studyReminderEnabled, true);
    });

    test('persists updated settings after reopening database', () async {
      final tempDir = await Directory.systemTemp.createTemp('settings_repo_');
      final dbFile = File(p.join(tempDir.path, 'settings.sqlite'));

      addTearDown(() async {
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final firstDb = AppDatabase(executor: NativeDatabase(dbFile));
      final firstRepo = UserSettingsRepository(database: firstDb);
      await firstRepo.updateName('지훈');
      await firstRepo.updateTrack('H2');
      await firstRepo.updateRole('PARENT');
      await firstRepo.updateNotificationsEnabled(false);
      await firstRepo.updateStudyReminderEnabled(false);
      await firstDb.close();

      final reopenedDb = AppDatabase(executor: NativeDatabase(dbFile));
      addTearDown(reopenedDb.close);

      final reopenedRepo = UserSettingsRepository(database: reopenedDb);
      final settings = await reopenedRepo.get();

      expect(settings.displayName, '지훈');
      expect(settings.track, 'H2');
      expect(settings.role, 'PARENT');
      expect(settings.notificationsEnabled, false);
      expect(settings.studyReminderEnabled, false);
    });
  });
}
