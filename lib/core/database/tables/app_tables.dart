import 'package:drift/drift.dart';

import '../converters/json_converters.dart';
import '../db_text_limits.dart';

class ContentPacks extends Table {
  @override
  String get tableName => 'content_packs';

  TextColumn get id => text().withLength(min: 1, max: DbTextLimits.idMax)();
  IntColumn get version =>
      integer().customConstraint('NOT NULL CHECK (version >= 1)')();
  TextColumn get locale =>
      text().withLength(min: 2, max: DbTextLimits.localeMax)();
  TextColumn get title =>
      text().withLength(min: 1, max: DbTextLimits.titleMax)();
  TextColumn get description => text().nullable()();
  TextColumn get checksum =>
      text().withLength(min: 1, max: DbTextLimits.checksumMax)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Passages extends Table {
  @override
  String get tableName => 'passages';

  TextColumn get id => text().withLength(min: 1, max: DbTextLimits.idMax)();
  TextColumn get packId =>
      text().references(ContentPacks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get sentencesJson => text().map(const SentencesConverter())();
  IntColumn get orderIndex =>
      integer().customConstraint('NOT NULL CHECK (order_index >= 0)')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Scripts extends Table {
  @override
  String get tableName => 'scripts';

  TextColumn get id => text().withLength(min: 1, max: DbTextLimits.idMax)();
  TextColumn get packId =>
      text().references(ContentPacks, #id, onDelete: KeyAction.cascade)();
  TextColumn get sentencesJson => text().map(const SentencesConverter())();
  TextColumn get turnsJson => text().map(const TurnsConverter())();
  TextColumn get ttsPlanJson => text().map(const TtsPlanConverter())();
  IntColumn get orderIndex =>
      integer().customConstraint('NOT NULL CHECK (order_index >= 0)')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Questions extends Table {
  @override
  String get tableName => 'questions';

  TextColumn get id => text().withLength(min: 1, max: DbTextLimits.idMax)();
  TextColumn get skill => text().customConstraint(
    "NOT NULL CHECK (skill IN ('LISTENING', 'READING'))",
  )();
  TextColumn get typeTag =>
      text().withLength(min: 2, max: DbTextLimits.typeTagMax)();
  TextColumn get track => text().customConstraint(
    "NOT NULL CHECK (track IN ('M3', 'H1', 'H2', 'H3'))",
  )();
  IntColumn get difficulty => integer().customConstraint(
    'NOT NULL CHECK (difficulty BETWEEN 1 AND 5)',
  )();
  TextColumn get passageId => text().nullable().references(
    Passages,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get scriptId =>
      text().nullable().references(Scripts, #id, onDelete: KeyAction.cascade)();
  TextColumn get prompt =>
      text().withLength(min: 1, max: DbTextLimits.promptMax)();
  TextColumn get optionsJson => text().map(const OptionMapConverter())();
  TextColumn get answerKey => text().customConstraint(
    "NOT NULL CHECK (answer_key IN ('A', 'B', 'C', 'D', 'E'))",
  )();
  IntColumn get orderIndex =>
      integer().customConstraint('NOT NULL CHECK (order_index >= 0)')();

  @override
  List<String> get customConstraints => [
    "CHECK ("
        "(skill = 'LISTENING' AND script_id IS NOT NULL AND passage_id IS NULL) OR "
        "(skill = 'READING' AND passage_id IS NOT NULL AND script_id IS NULL)"
        ")",
    "CHECK ((skill != 'LISTENING') OR (type_tag GLOB 'L[0-9]*'))",
    "CHECK ((skill != 'READING') OR (type_tag GLOB 'R[0-9]*'))",
  ];

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Explanations extends Table {
  @override
  String get tableName => 'explanations';

  TextColumn get id => text().withLength(min: 1, max: DbTextLimits.idMax)();
  TextColumn get questionId =>
      text().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get evidenceSentenceIdsJson =>
      text().map(const StringListConverter())();
  TextColumn get whyCorrectKo =>
      text().withLength(min: 1, max: DbTextLimits.whyCorrectKoMax)();
  TextColumn get whyWrongKoJson => text().map(const OptionMapConverter())();
  TextColumn get vocabNotesJson => text().nullable()();
  TextColumn get structureNotesKo => text().nullable()();
  TextColumn get glossKoJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {questionId},
  ];
}

class DailySessions extends Table {
  @override
  String get tableName => 'daily_sessions';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayKey => integer().customConstraint(
    'NOT NULL CHECK (day_key BETWEEN 19000101 AND 29991231)',
  )();
  TextColumn get track => text()
      .withLength(min: 2, max: 2)
      .customConstraint(
        "NOT NULL DEFAULT 'M3' CHECK (track IN ('M3', 'H1', 'H2', 'H3'))",
      )();
  IntColumn get plannedItems => integer().withDefault(const Constant(0))();
  IntColumn get completedItems => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {dayKey, track},
  ];
}

class DailySessionItems extends Table {
  @override
  String get tableName => 'daily_session_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(DailySessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer().customConstraint(
    'NOT NULL CHECK (order_index BETWEEN 0 AND 5)',
  )();
  TextColumn get questionId =>
      text().references(Questions, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sessionId, orderIndex},
    {sessionId, questionId},
  ];
}

class UserSettings extends Table {
  @override
  String get tableName => 'user_settings';

  IntColumn get id => integer()();
  TextColumn get role => text().customConstraint(
    "NOT NULL DEFAULT 'STUDENT' CHECK (role IN ('STUDENT', 'PARENT'))",
  )();
  TextColumn get displayName => text()
      .withLength(min: 0, max: DbTextLimits.displayNameMax)
      .customConstraint("NOT NULL DEFAULT ''")();
  TextColumn get birthDate => text()
      .withLength(min: 0, max: 10)
      .customConstraint(
        "NOT NULL DEFAULT '' CHECK (birth_date = '' OR birth_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
      )();
  TextColumn get track => text().customConstraint(
    "NOT NULL DEFAULT 'M3' CHECK (track IN ('M3', 'H1', 'H2', 'H3'))",
  )();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get studyReminderEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const <String>['CHECK (id = 1)'];
}

class Attempts extends Table {
  @override
  String get tableName => 'attempts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionId =>
      text().references(Questions, #id, onDelete: KeyAction.cascade)();
  IntColumn get sessionId => integer().nullable().references(
    DailySessions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get userAnswerJson => text()();
  BoolColumn get isCorrect => boolean()();
  IntColumn get responseTimeMs => integer().nullable()();
  DateTimeColumn get attemptedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class VocabMaster extends Table {
  @override
  String get tableName => 'vocab_master';

  TextColumn get id => text().withLength(min: 1, max: DbTextLimits.idMax)();
  TextColumn get lemma =>
      text().withLength(min: 1, max: DbTextLimits.lemmaMax)();
  TextColumn get pos => text().nullable()();
  TextColumn get meaning =>
      text().withLength(min: 1, max: DbTextLimits.meaningMax)();
  TextColumn get example => text().nullable()();
  TextColumn get ipa => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class VocabUser extends Table {
  @override
  String get tableName => 'vocab_user';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get vocabId =>
      text().references(VocabMaster, #id, onDelete: KeyAction.cascade)();
  IntColumn get familiarity => integer().withDefault(const Constant(0))();
  BoolColumn get isBookmarked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {vocabId},
  ];
}

class VocabSrsState extends Table {
  @override
  String get tableName => 'vocab_srs_state';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get vocabId =>
      text().references(VocabMaster, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get dueAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get repetition => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {vocabId},
  ];
}
