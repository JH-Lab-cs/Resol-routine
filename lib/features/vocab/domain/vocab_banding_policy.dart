import '../../../core/domain/domain_enums.dart';

class VocabBandingPolicy {
  const VocabBandingPolicy({
    required this.track,
    required this.primarySources,
    required this.carryOverSources,
    required this.minDifficultyBand,
    required this.maxDifficultyBand,
    required this.progressionRule,
  });

  final Track track;
  final List<VocabSourceTag> primarySources;
  final List<VocabSourceTag> carryOverSources;
  final int minDifficultyBand;
  final int maxDifficultyBand;
  final String progressionRule;
}

VocabBandingPolicy vocabBandingPolicyForTrack(Track track) {
  switch (track) {
    case Track.m3:
      return const VocabBandingPolicy(
        track: Track.m3,
        primarySources: <VocabSourceTag>[VocabSourceTag.schoolCore],
        carryOverSources: <VocabSourceTag>[],
        minDifficultyBand: 1,
        maxDifficultyBand: 2,
        progressionRule: 'foundational / high-frequency academic',
      );
    case Track.h1:
      return const VocabBandingPolicy(
        track: Track.h1,
        primarySources: <VocabSourceTag>[
          VocabSourceTag.schoolCore,
          VocabSourceTag.csat,
        ],
        carryOverSources: <VocabSourceTag>[VocabSourceTag.schoolCore],
        minDifficultyBand: 2,
        maxDifficultyBand: 3,
        progressionRule: 'lower-band CSAT / school core',
      );
    case Track.h2:
      return const VocabBandingPolicy(
        track: Track.h2,
        primarySources: <VocabSourceTag>[VocabSourceTag.csat],
        carryOverSources: <VocabSourceTag>[VocabSourceTag.schoolCore],
        minDifficultyBand: 3,
        maxDifficultyBand: 4,
        progressionRule: 'mid-band CSAT + carry-over review',
      );
    case Track.h3:
      return const VocabBandingPolicy(
        track: Track.h3,
        primarySources: <VocabSourceTag>[VocabSourceTag.csat],
        carryOverSources: <VocabSourceTag>[
          VocabSourceTag.schoolCore,
          VocabSourceTag.csat,
        ],
        minDifficultyBand: 4,
        maxDifficultyBand: 5,
        progressionRule: 'upper-band CSAT + spaced review of lower bands',
      );
  }
}

bool vocabSupportsTrackBand({
  required Track track,
  required String? targetMinTrack,
  required String? targetMaxTrack,
}) {
  if (targetMinTrack == null && targetMaxTrack == null) {
    return true;
  }

  final lowerBound = targetMinTrack == null ? 0 : _trackRank(trackFromDb(targetMinTrack));
  final upperBound = targetMaxTrack == null ? 3 : _trackRank(trackFromDb(targetMaxTrack));
  final targetRank = _trackRank(track);
  return lowerBound <= targetRank && targetRank <= upperBound;
}

int _trackRank(Track track) {
  switch (track) {
    case Track.m3:
      return 0;
    case Track.h1:
      return 1;
    case Track.h2:
      return 2;
    case Track.h3:
      return 3;
  }
}
