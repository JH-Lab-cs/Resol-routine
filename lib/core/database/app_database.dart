import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    Attempts,
    VocabMaster,
    VocabUser,
    VocabSrsState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

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
        await m.createTable(attempts);
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
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_attempts_session_question '
      'ON attempts(session_id, question_id) '
      'WHERE session_id IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_daily_session_items_question '
      'ON daily_session_items(question_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vocab_srs_due_at '
      'ON vocab_srs_state(due_at)',
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
