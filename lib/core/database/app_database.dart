import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/sha256_hash.dart';
import 'converters/json_converters.dart';
import 'converters/json_models.dart';
import 'tables/app_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    ContentPacks,
    Passages,
    Scripts,
    Questions,
    Explanations,
    DailySessions,
    DailySessionItems,
    UserSettings,
    SharedReports,
    VocabQuizResults,
    MockExamSessions,
    MockExamSessionItems,
    Attempts,
    VocabMaster,
    VocabUser,
    VocabSrsState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
      await _ensureUserSettingsRow();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await _migrateToV2(m);
      }
      if (from < 3) {
        await _migrateToV3();
      }
      if (from < 4) {
        await _migrateToV4(m);
      }
      if (from >= 4 && from < 5) {
        await _migrateToV5();
      }
      if (from < 6) {
        await _migrateToV6(m);
      }
      if (from == 6) {
        await _migrateToV7(m);
      }
      if (from < 8) {
        await _migrateToV8(m);
      }
      if (from < 9) {
        await _migrateToV9(m);
      }
      if (from < 10) {
        await _migrateToV10(m);
      }
      if (from < 11) {
        await _migrateToV11(m);
      }
      if (from < 12) {
        await _migrateToV12(m);
      }
      if (from < 13) {
        await _migrateToV13(m);
      }
      if (from < 14) {
        await _migrateToV14(m);
      }
      if (from < 15) {
        await _migrateToV15(m);
      }
      await _createIndexes();
      await _ensureUserSettingsRow();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _migrateToV2(Migrator m) async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await customStatement(
          'ALTER TABLE daily_sessions RENAME TO daily_sessions_old',
        );
        await m.createTable(dailySessions);
        await customStatement(
          'INSERT INTO daily_sessions ('
          'id, day_key, track, planned_items, completed_items, created_at'
          ') '
          "SELECT id, day_key, 'M3', planned_items, completed_items, created_at "
          'FROM daily_sessions_old',
        );

        await customStatement('ALTER TABLE attempts RENAME TO attempts_old');
        await customStatement(
          'CREATE TABLE attempts ('
          'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          'question_id TEXT NOT NULL REFERENCES questions(id) ON DELETE CASCADE, '
          'session_id INTEGER REFERENCES daily_sessions(id) ON DELETE SET NULL, '
          'user_answer_json TEXT NOT NULL, '
          'is_correct INTEGER NOT NULL CHECK (is_correct IN (0, 1)), '
          'response_time_ms INTEGER, '
          'attempted_at INTEGER NOT NULL'
          ')',
        );
        await customStatement(
          'INSERT INTO attempts ('
          'id, question_id, session_id, user_answer_json, is_correct, '
          'response_time_ms, attempted_at'
          ') '
          'SELECT id, question_id, session_id, user_answer_json, is_correct, '
          'response_time_ms, attempted_at '
          'FROM attempts_old',
        );

        await customStatement('DROP TABLE attempts_old');
        await customStatement('DROP TABLE daily_sessions_old');
        await m.createTable(dailySessionItems);
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _migrateToV3() async {
    await transaction(() async {
      // Keep only the latest attempt per (session_id, question_id) before enforcing uniqueness.
      await customStatement(
        'DELETE FROM attempts '
        'WHERE session_id IS NOT NULL '
        'AND EXISTS ('
        '  SELECT 1 FROM attempts newer '
        '  WHERE newer.session_id = attempts.session_id '
        '    AND newer.question_id = attempts.question_id '
        '    AND ('
        '      newer.attempted_at > attempts.attempted_at '
        '      OR (newer.attempted_at = attempts.attempted_at AND newer.id > attempts.id)'
        '    )'
        ')',
      );
    });
  }

  Future<void> _migrateToV4(Migrator m) async {
    await m.createTable(userSettings);
  }

  Future<void> _migrateToV5() async {
    await customStatement(
      "ALTER TABLE user_settings ADD COLUMN birth_date TEXT NOT NULL DEFAULT '' "
      "CHECK (birth_date = '' OR birth_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    );
  }

  Future<void> _migrateToV6(Migrator m) async {
    await m.createTable(sharedReports);
  }

  Future<void> _migrateToV7(Migrator m) async {
    await m.addColumn(sharedReports, sharedReports.payloadSha256);

    final rows = await customSelect(
      'SELECT id, payload_json FROM shared_reports',
      readsFrom: {sharedReports},
    ).get();

    for (final row in rows) {
      final id = row.read<int>('id');
      final payloadJson = row.read<String>('payload_json');
      final payloadSha256 = computeSha256Hex(payloadJson);
      await customStatement(
        'UPDATE shared_reports SET payload_sha256 = ? WHERE id = ?',
        <Object>[payloadSha256, id],
      );
    }

    await customStatement(
      'DELETE FROM shared_reports '
      'WHERE id NOT IN ('
      '  SELECT MIN(id) FROM shared_reports GROUP BY payload_sha256'
      ')',
    );
  }

  Future<void> _migrateToV8(Migrator m) async {
    await m.createTable(vocabQuizResults);
  }

  Future<void> _migrateToV9(Migrator m) async {
    await m.addColumn(vocabMaster, vocabMaster.deletedAt);
  }

  Future<void> _migrateToV10(Migrator m) async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await m.createTable(mockExamSessions);
        await m.createTable(mockExamSessionItems);

        await customStatement(
          'ALTER TABLE attempts RENAME TO attempts_old_v10',
        );
        await m.createTable(attempts);
        await customStatement(
          'INSERT INTO attempts ('
          'id, question_id, session_id, mock_session_id, user_answer_json, '
          'is_correct, response_time_ms, attempted_at'
          ') '
          'SELECT id, question_id, session_id, NULL, user_answer_json, '
          'is_correct, response_time_ms, attempted_at '
          'FROM attempts_old_v10',
        );
        await customStatement('DROP TABLE attempts_old_v10');
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _migrateToV11(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info('user_settings')",
      readsFrom: {userSettings},
    ).get();
    final hasDevToolsEnabled = columns.any(
      (row) => row.read<String>('name') == 'dev_tools_enabled',
    );
    if (hasDevToolsEnabled) {
      return;
    }
    await m.addColumn(userSettings, userSettings.devToolsEnabled);
  }

  Future<void> _migrateToV12(Migrator _) async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await customStatement(
          'CREATE TABLE questions_v12 ('
          'id TEXT NOT NULL PRIMARY KEY, '
          "skill TEXT NOT NULL CHECK (skill IN ('LISTENING', 'READING')), "
          'type_tag TEXT NOT NULL, '
          "track TEXT NOT NULL CHECK (track IN ('M3', 'H1', 'H2', 'H3')), "
          'difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5), '
          'passage_id TEXT REFERENCES passages(id) ON DELETE CASCADE, '
          'script_id TEXT REFERENCES scripts(id) ON DELETE CASCADE, '
          'prompt TEXT NOT NULL, '
          'options_json TEXT NOT NULL, '
          "answer_key TEXT NOT NULL CHECK (answer_key IN ('A', 'B', 'C', 'D', 'E')), "
          'order_index INTEGER NOT NULL CHECK (order_index >= 0), '
          "CHECK ((skill = 'LISTENING' AND script_id IS NOT NULL AND passage_id IS NULL) OR "
          "(skill = 'READING' AND passage_id IS NOT NULL AND script_id IS NULL)), "
          "CHECK ((skill != 'LISTENING') OR ("
          "type_tag IN ('L_GIST','L_DETAIL','L_INTENT','L_RESPONSE','L_SITUATION','L_LONG_TALK') "
          "OR type_tag GLOB 'L[0-9]*')), "
          "CHECK ((skill != 'READING') OR ("
          "type_tag IN ('R_MAIN_IDEA','R_DETAIL','R_INFERENCE','R_BLANK','R_ORDER','R_INSERTION','R_SUMMARY','R_VOCAB') "
          "OR type_tag GLOB 'R[0-9]*'))"
          ')',
        );

        await customStatement(
          'INSERT INTO questions_v12 ('
          'id, skill, type_tag, track, difficulty, passage_id, script_id, prompt, options_json, answer_key, order_index'
          ') '
          'SELECT '
          "id, skill, CASE type_tag "
          "WHEN 'L1' THEN 'L_GIST' "
          "WHEN 'L2' THEN 'L_DETAIL' "
          "WHEN 'L3' THEN 'L_INTENT' "
          "WHEN 'R1' THEN 'R_MAIN_IDEA' "
          "WHEN 'R2' THEN 'R_DETAIL' "
          "WHEN 'R3' THEN 'R_INFERENCE' "
          'ELSE type_tag END, '
          'track, difficulty, passage_id, script_id, prompt, options_json, answer_key, order_index '
          'FROM questions',
        );

        await customStatement('DROP TABLE questions');
        await customStatement('ALTER TABLE questions_v12 RENAME TO questions');
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _migrateToV13(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info('daily_sessions')",
      readsFrom: {dailySessions},
    ).get();
    final hasMetadataJson = columns.any(
      (row) => row.read<String>('name') == 'metadata_json',
    );
    if (hasMetadataJson) {
      return;
    }
    await m.addColumn(dailySessions, dailySessions.metadataJson);
  }

  Future<void> _migrateToV14(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info('vocab_master')",
      readsFrom: {vocabMaster},
    ).get();
    final existingColumnNames = columns
        .map((row) => row.read<String>('name'))
        .toSet();

    if (!existingColumnNames.contains('source_tag')) {
      await m.addColumn(vocabMaster, vocabMaster.sourceTag);
      await customStatement(
        "UPDATE vocab_master SET source_tag = 'USER_CUSTOM' "
        "WHERE id LIKE 'user_%'",
      );
    }
    if (!existingColumnNames.contains('target_min_track')) {
      await m.addColumn(vocabMaster, vocabMaster.targetMinTrack);
    }
    if (!existingColumnNames.contains('target_max_track')) {
      await m.addColumn(vocabMaster, vocabMaster.targetMaxTrack);
    }
    if (!existingColumnNames.contains('difficulty_band')) {
      await m.addColumn(vocabMaster, vocabMaster.difficultyBand);
    }
    if (!existingColumnNames.contains('frequency_tier')) {
      await m.addColumn(vocabMaster, vocabMaster.frequencyTier);
    }
  }

  Future<void> _migrateToV15(Migrator m) async {
    final columns = await customSelect(
      "PRAGMA table_info('user_settings')",
      readsFrom: {userSettings},
    ).get();
    final hasBackendUserId = columns.any(
      (row) => row.read<String>('name') == 'backend_user_id',
    );
    if (hasBackendUserId) {
      return;
    }
    await m.addColumn(userSettings, userSettings.backendUserId);
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_passages_pack_order '
      'ON passages(pack_id, order_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_scripts_pack_order '
      'ON scripts(pack_id, order_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_questions_skill_track_order '
      'ON questions(skill, track, order_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_questions_passage '
      'ON questions(passage_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_questions_script '
      'ON questions(script_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attempts_question '
      'ON attempts(question_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attempts_session '
      'ON attempts(session_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attempts_mock_session '
      'ON attempts(mock_session_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_attempts_session_question '
      'ON attempts(session_id, question_id) '
      'WHERE session_id IS NOT NULL',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_attempts_mock_session_question '
      'ON attempts(mock_session_id, question_id) '
      'WHERE mock_session_id IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_daily_session_items_question '
      'ON daily_session_items(question_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vocab_srs_due_at '
      'ON vocab_srs_state(due_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vocab_master_deleted_at '
      'ON vocab_master(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vocab_master_source_tag '
      'ON vocab_master(source_tag)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shared_reports_created_at '
      'ON shared_reports(created_at DESC)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_shared_reports_payload_sha256 '
      'ON shared_reports(payload_sha256)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vocab_quiz_results_day_track '
      'ON vocab_quiz_results(day_key, track)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_mock_exam_sessions_lookup '
      'ON mock_exam_sessions(exam_type, period_key, track)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_mock_exam_sessions_completed_at '
      'ON mock_exam_sessions(completed_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_mock_exam_session_items_session '
      'ON mock_exam_session_items(session_id)',
    );
  }

  Future<void> _ensureUserSettingsRow() async {
    await customStatement(
      'INSERT OR IGNORE INTO user_settings (id) VALUES (1)',
    );
  }

  Future<bool> hasAnyContentPacks() async {
    final total = await _countRows('content_packs');
    return total > 0;
  }

  Future<int> countContentPacks() => _countRows('content_packs');

  Future<int> countPassages() => _countRows('passages');

  Future<int> countScripts() => _countRows('scripts');

  Future<int> countQuestions() => _countRows('questions');

  Future<int> countExplanations() => _countRows('explanations');

  Future<int> countVocabMaster() => _countRows('vocab_master');

  Future<int> countVocabSrsState() => _countRows('vocab_srs_state');

  Future<int> _countRows(String tableName) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS row_count FROM $tableName',
      readsFrom: {},
    ).getSingle();

    return row.read<int>('row_count');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(appDocDir.path, 'resol_routine_v1.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}
