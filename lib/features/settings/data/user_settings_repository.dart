import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';

class UserSettingsModel {
  const UserSettingsModel({
    required this.role,
    required this.displayName,
    required this.birthDate,
    required this.track,
    required this.notificationsEnabled,
    required this.studyReminderEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String role;
  final String displayName;
  final String birthDate;
  final String track;
  final bool notificationsEnabled;
  final bool studyReminderEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
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

  Future<void> updateBirthDate(String value) async {
    final normalized = value.trim();
    if (normalized.isNotEmpty && !_isValidBirthDate(normalized)) {
      throw const FormatException(
        'birthDate must follow valid YYYY-MM-DD format.',
      );
    }

    await _update(
      UserSettingsCompanion(
        birthDate: Value(normalized),
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

  Future<void> resetForLogout() {
    final nowUtc = DateTime.now().toUtc();
    return _update(
      UserSettingsCompanion(
        role: const Value(defaultRole),
        displayName: const Value(''),
        birthDate: const Value(''),
        track: const Value(defaultTrack),
        notificationsEnabled: const Value(true),
        studyReminderEnabled: const Value(true),
        createdAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
      ),
    );
  }

  Future<void> resetForWithdrawal() {
    final nowUtc = DateTime.now().toUtc();
    return _update(
      UserSettingsCompanion(
        role: const Value(defaultRole),
        displayName: const Value(''),
        birthDate: const Value(''),
        track: const Value(defaultTrack),
        notificationsEnabled: const Value(true),
        studyReminderEnabled: const Value(true),
        createdAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
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
      birthDate: row.birthDate,
      track: row.track,
      notificationsEnabled: row.notificationsEnabled,
      studyReminderEnabled: row.studyReminderEnabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  bool _isValidBirthDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }

    try {
      final parsed = DateTime.parse(value);
      final normalized =
          '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
      return normalized == value;
    } catch (_) {
      return false;
    }
  }
}
