import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';

void main() {
  group('SharedReportsRepository', () {
    late AppDatabase database;
    late SharedReportsRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = SharedReportsRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('imports report JSON and exposes list/detail summaries', () async {
      final report = ReportSchema.v1(
        generatedAt: DateTime.utc(2026, 2, 21, 9, 0),
        appVersion: '1.0.0+1',
        student: const ReportStudent(
          role: 'STUDENT',
          displayName: '민수',
          track: Track.m3,
        ),
        days: <ReportDay>[
          ReportDay(
            dayKey: '20260221',
            track: Track.m3,
            solvedCount: 2,
            wrongCount: 1,
            listeningCorrect: 1,
            readingCorrect: 0,
            wrongReasonCounts: const <WrongReasonTag, int>{
              WrongReasonTag.vocab: 1,
            },
            questions: const <ReportQuestionResult>[
              ReportQuestionResult(
                questionId: 'Q-L-1',
                skill: Skill.listening,
                typeTag: 'L1',
                isCorrect: true,
                wrongReasonTag: null,
              ),
              ReportQuestionResult(
                questionId: 'Q-R-1',
                skill: Skill.reading,
                typeTag: 'R1',
                isCorrect: false,
                wrongReasonTag: WrongReasonTag.vocab,
              ),
            ],
          ),
        ],
      );

      final importedId = await repository.importFromJson(
        source: '/tmp/resolroutine_report_20260221_M3.json',
        payloadJson: report.encodePretty(),
      );

      final summaries = await repository.listSummaries();
      expect(summaries, hasLength(1));
      expect(summaries.first.id, importedId);
      expect(summaries.first.source, 'resolroutine_report_20260221_M3.json');
      expect(summaries.first.track, 'M3');
      expect(summaries.first.dayCount, 1);
      expect(summaries.first.totalSolvedCount, 2);
      expect(summaries.first.totalWrongCount, 1);
      expect(summaries.first.topWrongReasonTag, 'VOCAB');

      final detail = await repository.loadById(importedId);
      expect(detail.report.schemaVersion, 1);
      expect(detail.report.days.first.dayKey, '20260221');
      expect(detail.report.days.first.questions, hasLength(2));
    });

    test('rejects malformed payload during import', () async {
      const malformed =
          '{"schemaVersion":2,"generatedAt":"2026-02-21T00:00:00Z"}';

      await expectLater(
        repository.importFromJson(source: 'bad.json', payloadJson: malformed),
        throwsA(isA<FormatException>()),
      );
    });

    test('deleteById removes imported row', () async {
      final report = ReportSchema.v1(
        generatedAt: DateTime.utc(2026, 2, 21, 9, 0),
        student: const ReportStudent(
          role: 'STUDENT',
          displayName: '민수',
          track: Track.m3,
        ),
        days: <ReportDay>[
          ReportDay(
            dayKey: '20260221',
            track: Track.m3,
            solvedCount: 1,
            wrongCount: 0,
            listeningCorrect: 1,
            readingCorrect: 0,
            wrongReasonCounts: const <WrongReasonTag, int>{},
            questions: const <ReportQuestionResult>[
              ReportQuestionResult(
                questionId: 'Q-L-1',
                skill: Skill.listening,
                typeTag: 'L1',
                isCorrect: true,
                wrongReasonTag: null,
              ),
            ],
          ),
        ],
      );

      final importedId = await repository.importFromJson(
        source: 'delete_target.json',
        payloadJson: report.encodeCompact(),
      );
      expect((await repository.listSummaries()), hasLength(1));

      final deleted = await repository.deleteById(importedId);
      expect(deleted, isTrue);
      expect((await repository.listSummaries()), isEmpty);

      final deletedAgain = await repository.deleteById(importedId);
      expect(deletedAgain, isFalse);
    });
  });
}
