import 'package:drift/drift.dart';

class ContentPacks extends Table {
  @override
  String get tableName => 'content_packs';

  TextColumn get id => text().withLength(min: 1, max: 80)();
  IntColumn get version =>
      integer().customConstraint('NOT NULL CHECK (version >= 1)')();
  TextColumn get locale => text().withLength(min: 2, max: 16)();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().nullable()();
  TextColumn get checksum => text().withLength(min: 1, max: 150)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Passages extends Table {
  @override
  String get tableName => 'passages';

  TextColumn get id => text().withLength(min: 1, max: 80)();
  TextColumn get packId =>
      text().references(ContentPacks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  TextColumn get body => text().withLength(min: 1, max: 4000)();
  IntColumn get orderIndex =>
      integer().customConstraint('NOT NULL CHECK (order_index >= 0)')();
  IntColumn get difficulty => integer().customConstraint(
    'NOT NULL CHECK (difficulty BETWEEN 1 AND 5)',
  )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Scripts extends Table {
  @override
  String get tableName => 'scripts';

  TextColumn get id => text().withLength(min: 1, max: 80)();
  TextColumn get passageId =>
      text().references(Passages, #id, onDelete: KeyAction.cascade)();
  TextColumn get speaker => text().withLength(min: 1, max: 80)();
  TextColumn get textBody =>
      text().named('text').withLength(min: 1, max: 2000)();
  IntColumn get orderIndex =>
      integer().customConstraint('NOT NULL CHECK (order_index >= 0)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Questions extends Table {
  @override
  String get tableName => 'questions';

  TextColumn get id => text().withLength(min: 1, max: 80)();
  TextColumn get passageId =>
      text().references(Passages, #id, onDelete: KeyAction.cascade)();
  TextColumn get prompt => text().withLength(min: 1, max: 2000)();
  TextColumn get questionType => text().withLength(min: 1, max: 40)();
  TextColumn get optionsJson => text().nullable()();
  TextColumn get answerJson => text()();
  IntColumn get orderIndex =>
      integer().customConstraint('NOT NULL CHECK (order_index >= 0)')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Explanations extends Table {
  @override
  String get tableName => 'explanations';

  TextColumn get id => text().withLength(min: 1, max: 80)();
  TextColumn get questionId =>
      text().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text().withLength(min: 1, max: 4000)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DailySessions extends Table {
  @override
  String get tableName => 'daily_sessions';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get sessionDate => dateTime().unique()();
  IntColumn get plannedItems => integer().withDefault(const Constant(0))();
  IntColumn get completedItems => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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

  TextColumn get id => text().withLength(min: 1, max: 80)();
  TextColumn get lemma => text().withLength(min: 1, max: 120)();
  TextColumn get pos => text().nullable()();
  TextColumn get meaning => text().withLength(min: 1, max: 400)();
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
