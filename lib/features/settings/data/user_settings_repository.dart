import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';

class UserSettingsModel {
  const UserSettingsModel({
    required this.role,
    required this.displayName,
    required this.track,
    required this.notificationsEnabled,
    required this.studyReminderEnabled,
  });

  final String role;
  final String displayName;
  final String track;
  final bool notificationsEnabled;
  final bool studyReminderEnabled;
}

class UserSettingsRepository {
  UserSettingsRepository({required AppDatabase database})
    : _database = database;

  static const String defaultRole = 'STUDENT';
  static const String defaultTrack = 'M3';
  static const Set<String> supportedRoles = <String>{'STUDENT', 'PARENT'};
  static const Set<String> supportedTracks = <String>{'M3', 'H1', 'H2', 'H3'};
  static const int _singletonId = 1;

  final AppDatabase _database;

  Future<UserSettingsModel> get() async {
    await _ensureSingletonRow();
    final row = await (_database.select(
      _database.userSettings,
    )..where((tbl) => tbl.id.equals(_singletonId))).getSingle();
    return _toModel(row);
  }

  Stream<UserSettingsModel> watch() async* {
    await _ensureSingletonRow();
    yield* (_database.select(
      _database.userSettings,
    )..where((tbl) => tbl.id.equals(_singletonId))).watchSingle().map(_toModel);
  }

  Future<void> updateName(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('displayName must not be empty.');
    }
    if (normalized.length > DbTextLimits.displayNameMax) {
      throw FormatException(
        'displayName exceeds ${DbTextLimits.displayNameMax} characters.',
      );
    }

    await _update(
      UserSettingsCompanion(
        displayName: Value(normalized),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateTrack(String track) async {
    if (!supportedTracks.contains(track)) {
      throw FormatException('Unsupported track: "$track"');
    }

    await _update(
      UserSettingsCompanion(
        track: Value(track),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateRole(String role) async {
    if (!supportedRoles.contains(role)) {
      throw FormatException('Unsupported role: "$role"');
    }

    await _update(
      UserSettingsCompanion(
        role: Value(role),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateNotificationsEnabled(bool enabled) {
    return _update(
      UserSettingsCompanion(
        notificationsEnabled: Value(enabled),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateStudyReminderEnabled(bool enabled) {
    return _update(
      UserSettingsCompanion(
        studyReminderEnabled: Value(enabled),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _update(UserSettingsCompanion companion) async {
    await _ensureSingletonRow();
    await (_database.update(
      _database.userSettings,
    )..where((tbl) => tbl.id.equals(_singletonId))).write(companion);
  }

  Future<void> _ensureSingletonRow() async {
    await _database.customStatement(
      'INSERT OR IGNORE INTO user_settings (id) VALUES ($_singletonId)',
    );
  }

  UserSettingsModel _toModel(UserSetting row) {
    return UserSettingsModel(
      role: row.role,
      displayName: row.displayName,
      track: row.track,
      notificationsEnabled: row.notificationsEnabled,
      studyReminderEnabled: row.studyReminderEnabled,
    );
  }
}
