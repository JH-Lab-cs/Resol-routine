import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:resol_routine/core/database/app_database.dart';

void main() {
  test('migrates v1 schema to v6 while preserving rows', () async {
    final tempDir = await Directory.systemTemp.createTemp('resol_migration_');
    final dbFile = File(p.join(tempDir.path, 'migration_v1.sqlite'));

    addTearDown(() async {
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await _createV1Database(dbFile);

    final database = AppDatabase(executor: NativeDatabase(dbFile));
    addTearDown(database.close);

    final userVersionRow = await database
        .customSelect('PRAGMA user_version', readsFrom: {})
        .getSingle();
    expect(userVersionRow.read<int>('user_version'), 6);

    final attemptsRow = await database
        .customSelect('SELECT COUNT(*) AS count FROM attempts', readsFrom: {})
        .getSingle();
    expect(attemptsRow.read<int>('count'), 1);

    final dedupedAttempt = await database
        .customSelect(
          'SELECT id, user_answer_json FROM attempts',
          readsFrom: {database.attempts},
        )
        .getSingle();
    expect(dedupedAttempt.read<int>('id'), 2);
    expect(dedupedAttempt.read<String>('user_answer_json'), '"C"');

    final sessionsRow = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM daily_sessions',
          readsFrom: {},
        )
        .getSingle();
    expect(sessionsRow.read<int>('count'), 1);

    final migratedSession = await (database.select(
      database.dailySessions,
    )..where((tbl) => tbl.dayKey.equals(20260105))).getSingle();
    expect(migratedSession.track, 'M3');

    await database
        .into(database.dailySessions)
        .insert(
          DailySessionsCompanion.insert(
            dayKey: 20260105,
            track: const Value('H1'),
          ),
        );

    final updatedSessionsRow = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM daily_sessions WHERE day_key = 20260105',
          readsFrom: {},
        )
        .getSingle();
    expect(updatedSessionsRow.read<int>('count'), 2);

    final userSettingsRow = await database
        .customSelect(
          'SELECT role, display_name, birth_date, track FROM user_settings WHERE id = 1',
          readsFrom: {database.userSettings},
        )
        .getSingle();
    expect(userSettingsRow.read<String>('role'), 'STUDENT');
    expect(userSettingsRow.read<String>('display_name'), '');
    expect(userSettingsRow.read<String>('birth_date'), '');
    expect(userSettingsRow.read<String>('track'), 'M3');

    final sharedReportsCountRow = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM shared_reports',
          readsFrom: {database.sharedReports},
        )
        .getSingle();
    expect(sharedReportsCountRow.read<int>('count'), 0);
  });
}

Future<void> _createV1Database(File file) async {
  final executor = NativeDatabase(file);
  try {
    await executor.ensureOpen(const _NoopQueryExecutorUser());
    await executor.runCustom('PRAGMA foreign_keys = ON');

    await executor.runCustom('''
      CREATE TABLE content_packs (
        id TEXT NOT NULL PRIMARY KEY,
        version INTEGER NOT NULL,
        locale TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        checksum TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE passages (
        id TEXT NOT NULL PRIMARY KEY,
        pack_id TEXT NOT NULL REFERENCES content_packs(id) ON DELETE CASCADE,
        title TEXT,
        sentences_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE scripts (
        id TEXT NOT NULL PRIMARY KEY,
        pack_id TEXT NOT NULL REFERENCES content_packs(id) ON DELETE CASCADE,
        sentences_json TEXT NOT NULL,
        turns_json TEXT NOT NULL,
        tts_plan_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE questions (
        id TEXT NOT NULL PRIMARY KEY,
        skill TEXT NOT NULL,
        type_tag TEXT NOT NULL,
        track TEXT NOT NULL,
        difficulty INTEGER NOT NULL,
        passage_id TEXT REFERENCES passages(id) ON DELETE CASCADE,
        script_id TEXT REFERENCES scripts(id) ON DELETE CASCADE,
        prompt TEXT NOT NULL,
        options_json TEXT NOT NULL,
        answer_key TEXT NOT NULL,
        order_index INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE explanations (
        id TEXT NOT NULL PRIMARY KEY,
        question_id TEXT NOT NULL UNIQUE REFERENCES questions(id) ON DELETE CASCADE,
        evidence_sentence_ids_json TEXT NOT NULL,
        why_correct_ko TEXT NOT NULL,
        why_wrong_ko_json TEXT NOT NULL,
        vocab_notes_json TEXT,
        structure_notes_ko TEXT,
        gloss_ko_json TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE daily_sessions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        day_key INTEGER NOT NULL UNIQUE CHECK (day_key BETWEEN 19000101 AND 29991231),
        planned_items INTEGER NOT NULL DEFAULT 0,
        completed_items INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE attempts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
        session_id INTEGER REFERENCES daily_sessions(id) ON DELETE SET NULL,
        user_answer_json TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        response_time_ms INTEGER,
        attempted_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE vocab_master (
        id TEXT NOT NULL PRIMARY KEY,
        lemma TEXT NOT NULL,
        pos TEXT,
        meaning TEXT NOT NULL,
        example TEXT,
        ipa TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE vocab_user (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        vocab_id TEXT NOT NULL UNIQUE REFERENCES vocab_master(id) ON DELETE CASCADE,
        familiarity INTEGER NOT NULL DEFAULT 0,
        is_bookmarked INTEGER NOT NULL DEFAULT 0,
        last_seen_at INTEGER,
        updated_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom('''
      CREATE TABLE vocab_srs_state (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        vocab_id TEXT NOT NULL UNIQUE REFERENCES vocab_master(id) ON DELETE CASCADE,
        due_at INTEGER NOT NULL,
        interval_days INTEGER NOT NULL DEFAULT 1,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        repetition INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        suspended INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    await executor.runCustom(
      'CREATE INDEX idx_passages_pack_order ON passages(pack_id, order_index)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_scripts_pack_order ON scripts(pack_id, order_index)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_questions_skill_track_order ON questions(skill, track, order_index)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_questions_passage ON questions(passage_id)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_questions_script ON questions(script_id)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_attempts_question ON attempts(question_id)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_attempts_session ON attempts(session_id)',
    );
    await executor.runCustom(
      'CREATE INDEX idx_vocab_srs_due_at ON vocab_srs_state(due_at)',
    );

    final now = DateTime.utc(2026, 1, 5).millisecondsSinceEpoch;
    await executor.runCustom(
      "INSERT INTO content_packs (id, version, locale, title, description, checksum, created_at, updated_at) "
      "VALUES ('pack_v1', 1, 'en-US', 'V1 Pack', NULL, 'sha256:v1', $now, $now)",
    );
    await executor.runCustom(
      "INSERT INTO scripts (id, pack_id, sentences_json, turns_json, tts_plan_json, order_index, created_at) "
      "VALUES ('script_v1', 'pack_v1', '[{\"id\":\"s1\",\"text\":\"Hello\"}]', '[{\"speaker\":\"S1\",\"sentenceIds\":[\"s1\"]}]', '{\"repeatPolicy\":{\"mode\":\"per_turn\",\"repeatCount\":1},\"pauseRangeMs\":{\"min\":350,\"max\":650},\"rateRange\":{\"min\":0.95,\"max\":1.03},\"pitchRange\":{\"min\":0.0,\"max\":1.2},\"voiceRoles\":{\"S1\":\"en-US-Standard-C\",\"S2\":\"en-US-Standard-E\",\"N\":\"en-US-Standard-A\"}}', 0, $now)",
    );
    await executor.runCustom(
      "INSERT INTO questions (id, skill, type_tag, track, difficulty, passage_id, script_id, prompt, options_json, answer_key, order_index) "
      "VALUES ('question_v1', 'LISTENING', 'L1', 'M3', 2, NULL, 'script_v1', 'Question?', '{\"A\":\"A\",\"B\":\"B\",\"C\":\"C\",\"D\":\"D\",\"E\":\"E\"}', 'B', 0)",
    );
    await executor.runCustom(
      'INSERT INTO daily_sessions (id, day_key, planned_items, completed_items, created_at) '
      'VALUES (1, 20260105, 6, 1, $now)',
    );
    await executor.runCustom(
      'INSERT INTO attempts (id, question_id, session_id, user_answer_json, is_correct, response_time_ms, attempted_at) '
      "VALUES (1, 'question_v1', 1, '\"B\"', 1, 1200, $now)",
    );
    await executor.runCustom(
      'INSERT INTO attempts (id, question_id, session_id, user_answer_json, is_correct, response_time_ms, attempted_at) '
      "VALUES (2, 'question_v1', 1, '\"C\"', 0, 1000, ${now + 1})",
    );

    await executor.runCustom('PRAGMA user_version = 1');
  } finally {
    await executor.close();
  }
}

class _NoopQueryExecutorUser implements QueryExecutorUser {
  const _NoopQueryExecutorUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    // No-op: This helper only exists to bootstrap a hand-written v1 schema.
  }
}
