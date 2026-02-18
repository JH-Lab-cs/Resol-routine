import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    Attempts,
    VocabMaster,
    VocabUser,
    VocabSrsState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
      'CREATE INDEX IF NOT EXISTS idx_vocab_srs_due_at '
      'ON vocab_srs_state(due_at)',
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
