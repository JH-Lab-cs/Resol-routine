import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resol_routine/core/database/db_text_limits.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';

void main() {
  group('ReportSchema', () {
    test('accepts valid v1 payload as-is', () {
      final payload = <String, Object?>{
        'schemaVersion': 1,
        'generatedAt': '2026-02-21T10:30:00.000Z',
        'appVersion': '1.0.0+1',
        'student': <String, Object?>{
          'role': 'STUDENT',
          'displayName': '민수',
          'track': 'M3',
        },
        'days': <Object?>[
          <String, Object?>{
            'dayKey': '20260220',
            'track': 'M3',
            'solvedCount': 2,
            'wrongCount': 1,
            'listeningCorrect': 1,
            'readingCorrect': 0,
            'wrongReasonCounts': <String, Object?>{'VOCAB': 1},
            'questions': <Object?>[
              <String, Object?>{
                'questionId': 'Q-L-1',
                'skill': 'LISTENING',
                'typeTag': 'L2',
                'isCorrect': true,
              },
              <String, Object?>{
                'questionId': 'Q-R-1',
                'skill': 'READING',
                'typeTag': 'R1',
                'isCorrect': false,
                'wrongReasonTag': 'VOCAB',
              },
            ],
          },
        ],
      };

      final schema = ReportSchema.decode(jsonEncode(payload));

      expect(schema.schemaVersion, reportSchemaV1);
      expect(schema.student.role, 'STUDENT');
      expect(schema.student.track, Track.m3);
      expect(schema.days, hasLength(1));
      expect(schema.days.first.solvedCount, 2);
      expect(schema.days.first.wrongReasonCounts[WrongReasonTag.vocab], 1);
      expect(schema.days.first.questions.first.typeTag, 'L_DETAIL');
      expect(schema.days.first.questions.last.typeTag, 'R_MAIN_IDEA');
    });

    test('accepts valid v2 payload with vocabQuiz summary', () {
      final payload = <String, Object?>{
        'schemaVersion': 2,
        'generatedAt': '2026-02-21T10:30:00.000Z',
        'student': <String, Object?>{
          'role': 'STUDENT',
          'displayName': '민수',
          'track': 'M3',
        },
        'days': <Object?>[
          <String, Object?>{
            'dayKey': '20260221',
            'track': 'M3',
            'solvedCount': 1,
            'wrongCount': 0,
            'listeningCorrect': 1,
            'readingCorrect': 0,
            'wrongReasonCounts': <String, Object?>{},
            'questions': <Object?>[
              <String, Object?>{
                'questionId': 'Q-L-1',
                'skill': 'LISTENING',
                'typeTag': 'L2',
                'isCorrect': true,
              },
            ],
            'vocabQuiz': <String, Object?>{
              'totalCount': 20,
              'correctCount': 18,
              'wrongVocabIds': <Object?>['vocab_a', 'vocab_b'],
            },
          },
        ],
      };

      final schema = ReportSchema.decode(jsonEncode(payload));
      expect(schema.schemaVersion, reportSchemaV2);
      expect(schema.days.first.vocabQuiz, isNotNull);
      expect(schema.days.first.vocabQuiz!.totalCount, 20);
      expect(schema.days.first.vocabQuiz!.correctCount, 18);
      expect(schema.days.first.vocabQuiz!.wrongVocabIds, <String>[
        'vocab_a',
        'vocab_b',
      ]);
    });

    test('accepts valid v3 payload with vocabBookmarks', () {
      final payload = <String, Object?>{
        'schemaVersion': 3,
        'generatedAt': '2026-02-21T10:30:00.000Z',
        'student': <String, Object?>{
          'role': 'STUDENT',
          'displayName': '민수',
          'track': 'M3',
        },
        'days': <Object?>[
          <String, Object?>{
            'dayKey': '20260221',
            'track': 'M3',
            'solvedCount': 1,
            'wrongCount': 0,
            'listeningCorrect': 1,
            'readingCorrect': 0,
            'wrongReasonCounts': <String, Object?>{},
            'questions': <Object?>[
              <String, Object?>{
                'questionId': 'Q-L-1',
                'skill': 'LISTENING',
                'typeTag': 'L2',
                'isCorrect': true,
              },
            ],
          },
        ],
        'vocabBookmarks': <String, Object?>{
          'bookmarkedVocabIds': <Object?>['vocab_a', 'vocab_b'],
        },
      };

      final schema = ReportSchema.decode(jsonEncode(payload));
      expect(schema.schemaVersion, reportSchemaV3);
      expect(schema.vocabBookmarks, isNotNull);
      expect(schema.vocabBookmarks!.bookmarkedVocabIds, <String>[
        'vocab_a',
        'vocab_b',
      ]);
    });

    test('accepts valid v4 payload with custom vocab lemmas', () {
      final payload = <String, Object?>{
        'schemaVersion': 4,
        'generatedAt': '2026-02-21T10:30:00.000Z',
        'student': <String, Object?>{
          'role': 'STUDENT',
          'displayName': '민수',
          'track': 'M3',
        },
        'days': <Object?>[
          <String, Object?>{
            'dayKey': '20260221',
            'track': 'M3',
            'solvedCount': 1,
            'wrongCount': 0,
            'listeningCorrect': 1,
            'readingCorrect': 0,
            'wrongReasonCounts': <String, Object?>{},
            'questions': <Object?>[
              <String, Object?>{
                'questionId': 'Q-L-1',
                'skill': 'LISTENING',
                'typeTag': 'L2',
                'isCorrect': true,
              },
            ],
            'vocabQuiz': <String, Object?>{
              'totalCount': 20,
              'correctCount': 19,
              'wrongVocabIds': <Object?>['user_vocab_a'],
            },
          },
        ],
        'vocabBookmarks': <String, Object?>{
          'bookmarkedVocabIds': <Object?>['user_vocab_a', 'user_vocab_b'],
        },
        'customVocab': <String, Object?>{
          'lemmasById': <String, Object?>{
            'user_vocab_a': 'glimmer',
            'user_vocab_b': 'spark',
          },
        },
      };

      final schema = ReportSchema.decode(jsonEncode(payload));
      expect(schema.schemaVersion, reportSchemaV4);
      expect(schema.vocabBookmarks, isNotNull);
      expect(schema.customVocab, isNotNull);
      expect(schema.customVocab!.lemmasById['user_vocab_a'], 'glimmer');
      expect(schema.customVocab!.lemmasById['user_vocab_b'], 'spark');
    });

    test('accepts valid v5 payload with mock exam summaries', () {
      final payload = <String, Object?>{
        'schemaVersion': 5,
        'generatedAt': '2026-02-21T10:30:00.000Z',
        'student': <String, Object?>{
          'role': 'STUDENT',
          'displayName': '민수',
          'track': 'M3',
        },
        'days': <Object?>[
          <String, Object?>{
            'dayKey': '20260221',
            'track': 'M3',
            'solvedCount': 1,
            'wrongCount': 0,
            'listeningCorrect': 1,
            'readingCorrect': 0,
            'wrongReasonCounts': <String, Object?>{},
            'questions': <Object?>[
              <String, Object?>{
                'questionId': 'Q-L-1',
                'skill': 'LISTENING',
                'typeTag': 'L2',
                'isCorrect': true,
              },
            ],
          },
        ],
        'vocabBookmarks': <String, Object?>{
          'bookmarkedVocabIds': <Object?>['user_vocab_a'],
        },
        'customVocab': <String, Object?>{
          'lemmasById': <String, Object?>{'user_vocab_a': 'glimmer'},
        },
        'mockExams': <String, Object?>{
          'weekly': <Object?>[
            <String, Object?>{
              'periodKey': '2026W08',
              'track': 'M3',
              'totalCount': 20,
              'listeningCorrect': 7,
              'readingCorrect': 8,
              'correctCount': 15,
              'wrongCount': 5,
              'completedAt': '2026-02-21T10:30:00.000Z',
            },
          ],
          'monthly': <Object?>[
            <String, Object?>{
              'periodKey': '202602',
              'track': 'M3',
              'totalCount': 45,
              'listeningCorrect': 13,
              'readingCorrect': 24,
              'correctCount': 37,
              'wrongCount': 8,
              'completedAt': '2026-02-21T10:30:00.000Z',
            },
          ],
        },
      };

      final schema = ReportSchema.decode(jsonEncode(payload));
      expect(schema.schemaVersion, reportSchemaV5);
      expect(schema.mockExams, isNotNull);
      expect(schema.mockExams!.weekly, hasLength(1));
      expect(schema.mockExams!.monthly, hasLength(1));
      expect(schema.mockExams!.weekly.first.correctCount, 15);
      expect(schema.mockExams!.monthly.first.correctCount, 37);
    });

    test('rejects invalid weekly totalCount in v5 mock exam summary', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 5;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['user_vocab_a'],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{'user_vocab_a': 'glimmer'},
      };
      payload['mockExams'] = <String, Object?>{
        'weekly': <Object?>[
          <String, Object?>{
            'periodKey': '2026W08',
            'track': 'M3',
            'totalCount': 45,
            'listeningCorrect': 7,
            'readingCorrect': 8,
            'correctCount': 15,
            'wrongCount': 30,
            'completedAt': '2026-02-21T10:30:00.000Z',
          },
        ],
        'monthly': <Object?>[],
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicated periodKey-track in v5 mock exam summaries', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 5;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['user_vocab_a'],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{'user_vocab_a': 'glimmer'},
      };
      payload['mockExams'] = <String, Object?>{
        'weekly': <Object?>[
          <String, Object?>{
            'periodKey': '2026W08',
            'track': 'M3',
            'totalCount': 20,
            'listeningCorrect': 7,
            'readingCorrect': 8,
            'correctCount': 15,
            'wrongCount': 5,
            'completedAt': '2026-02-21T10:30:00.000Z',
          },
          <String, Object?>{
            'periodKey': '2026W08',
            'track': 'M3',
            'totalCount': 20,
            'listeningCorrect': 6,
            'readingCorrect': 8,
            'correctCount': 14,
            'wrongCount': 6,
            'completedAt': '2026-02-20T10:30:00.000Z',
          },
        ],
        'monthly': <Object?>[],
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown keys in v5 mockExams', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 5;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['user_vocab_a'],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{'user_vocab_a': 'glimmer'},
      };
      payload['mockExams'] = <String, Object?>{
        'weekly': <Object?>[],
        'monthly': <Object?>[],
        'details': 'not_allowed',
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown keys for strict schema guard', () {
      final payload = _basePayload();
      final day =
          (payload['days'] as List<Object?>).first as Map<String, Object?>;
      final questions = day['questions'] as List<Object?>;
      final firstQuestion = questions.first as Map<String, Object?>;
      firstQuestion['prompt'] = 'This field must not be exported.';

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects inconsistent counters against question list', () {
      final payload = _basePayload();
      final day =
          (payload['days'] as List<Object?>).first as Map<String, Object?>;
      day['solvedCount'] = 2;

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported enum mapping', () {
      final payload = _basePayload();
      final day =
          (payload['days'] as List<Object?>).first as Map<String, Object?>;
      day['track'] = 'H4';

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown keys in v2 vocabQuiz', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 2;
      final day =
          (payload['days'] as List<Object?>).first as Map<String, Object?>;
      day['vocabQuiz'] = <String, Object?>{
        'totalCount': 20,
        'correctCount': 19,
        'wrongVocabIds': <Object?>['vocab_a'],
        'options': 'not_allowed',
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects inconsistent v2 vocabQuiz counts', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 2;
      final day =
          (payload['days'] as List<Object?>).first as Map<String, Object?>;
      day['vocabQuiz'] = <String, Object?>{
        'totalCount': 20,
        'correctCount': 19,
        'wrongVocabIds': <Object?>['vocab_a', 'vocab_b'],
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown keys in v3 vocabBookmarks', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 3;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['vocab_a'],
        'lemma': 'not_allowed',
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicated bookmarked vocab ids in v3', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 3;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['vocab_a', 'vocab_a'],
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects hidden unicode in v3 bookmarked vocab ids', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 3;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['vocab_a\u200B'],
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects id length overflow in v3 bookmarked vocab ids', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 3;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['x' * (DbTextLimits.idMax + 1)],
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects bookmarked vocab ids list overflow in v3', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 3;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': List<Object?>.generate(
          reportMaxBookmarkedVocabIds + 1,
          (index) => 'vocab_$index',
        ),
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects hidden unicode in v4 custom vocab lemma values', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 4;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['user_vocab_a'],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{'user_vocab_a': 'gleam\u200B'},
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-user id keys in v4 custom vocab map', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 4;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': <Object?>['user_vocab_a'],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{'vocab_a': 'glimmer'},
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects custom vocab map overflow in v4', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 4;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': const <Object?>[],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{
          for (var i = 0; i <= reportMaxCustomVocabLemmaEntries; i++)
            'user_vocab_$i': 'lemma_$i',
        },
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects custom vocab key and value length overflow in v4', () {
      final payload = _basePayload();
      payload['schemaVersion'] = 4;
      payload['vocabBookmarks'] = <String, Object?>{
        'bookmarkedVocabIds': const <Object?>[],
      };
      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{
          'user_${'x' * DbTextLimits.idMax}': 'lemma',
        },
      };

      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );

      payload['customVocab'] = <String, Object?>{
        'lemmasById': <String, Object?>{
          'user_vocab_a': 'l' * (DbTextLimits.lemmaMax + 1),
        },
      };
      expect(
        () => ReportSchema.decode(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, Object?> _basePayload() {
  return <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': '2026-02-21T10:30:00.000Z',
    'student': <String, Object?>{
      'role': 'PARENT',
      'displayName': 'Parent',
      'track': 'M3',
    },
    'days': <Object?>[
      <String, Object?>{
        'dayKey': '20260220',
        'track': 'M3',
        'solvedCount': 1,
        'wrongCount': 0,
        'listeningCorrect': 1,
        'readingCorrect': 0,
        'wrongReasonCounts': <String, Object?>{},
        'questions': <Object?>[
          <String, Object?>{
            'questionId': 'Q-L-1',
            'skill': 'LISTENING',
            'typeTag': 'L2',
            'isCorrect': true,
          },
        ],
      },
    ],
  };
}
