import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';

void main() {
  group('ReportSchema', () {
    test('parses valid v1 schema and preserves normalized values', () {
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
