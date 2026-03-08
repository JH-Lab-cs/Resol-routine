import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/vocab/domain/vocab_banding_policy.dart';

void main() {
  group('vocabBandingPolicyForTrack', () {
    test('returns the frozen rule for each track', () {
      final m3 = vocabBandingPolicyForTrack(Track.m3);
      final h1 = vocabBandingPolicyForTrack(Track.h1);
      final h2 = vocabBandingPolicyForTrack(Track.h2);
      final h3 = vocabBandingPolicyForTrack(Track.h3);

      expect(m3.primarySources, <VocabSourceTag>[VocabSourceTag.schoolCore]);
      expect(m3.minDifficultyBand, 1);
      expect(m3.maxDifficultyBand, 2);

      expect(
        h1.primarySources,
        <VocabSourceTag>[VocabSourceTag.schoolCore, VocabSourceTag.csat],
      );
      expect(h1.minDifficultyBand, 2);
      expect(h1.maxDifficultyBand, 3);

      expect(h2.primarySources, <VocabSourceTag>[VocabSourceTag.csat]);
      expect(h2.carryOverSources, <VocabSourceTag>[VocabSourceTag.schoolCore]);
      expect(h2.minDifficultyBand, 3);
      expect(h2.maxDifficultyBand, 4);

      expect(h3.primarySources, <VocabSourceTag>[VocabSourceTag.csat]);
      expect(h3.minDifficultyBand, 4);
      expect(h3.maxDifficultyBand, 5);
    });
  });

  group('vocabSupportsTrackBand', () {
    test('accepts null bounds as globally eligible', () {
      expect(
        vocabSupportsTrackBand(
          track: Track.h2,
          targetMinTrack: null,
          targetMaxTrack: null,
        ),
        isTrue,
      );
    });

    test('accepts tracks inside the declared band and rejects outside tracks', () {
      expect(
        vocabSupportsTrackBand(
          track: Track.h1,
          targetMinTrack: 'M3',
          targetMaxTrack: 'H2',
        ),
        isTrue,
      );
      expect(
        vocabSupportsTrackBand(
          track: Track.h3,
          targetMinTrack: 'M3',
          targetMaxTrack: 'H2',
        ),
        isFalse,
      );
    });
  });
}
