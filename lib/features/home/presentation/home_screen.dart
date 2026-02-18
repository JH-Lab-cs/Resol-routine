import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';

final learningOverviewProvider = FutureProvider<LearningOverview>((
  Ref ref,
) async {
  final database = ref.watch(appDatabaseProvider);

  return LearningOverview(
    packCount: await database.countContentPacks(),
    passageCount: await database.countPassages(),
    questionCount: await database.countQuestions(),
    vocabCount: await database.countVocabMaster(),
    scheduledReviewCount: await database.countVocabSrsState(),
  );
});

class LearningOverview {
  const LearningOverview({
    required this.packCount,
    required this.passageCount,
    required this.questionCount,
    required this.vocabCount,
    required this.scheduledReviewCount,
  });

  final int packCount;
  final int passageCount;
  final int questionCount;
  final int vocabCount;
  final int scheduledReviewCount;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(learningOverviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resol Routine')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Unable to load your learning data.\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (LearningOverview data) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Learning Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _MetricTile(label: 'Content Packs', value: data.packCount),
            _MetricTile(label: 'Passages', value: data.passageCount),
            _MetricTile(label: 'Questions', value: data.questionCount),
            _MetricTile(label: 'Vocabulary Terms', value: data.vocabCount),
            _MetricTile(
              label: 'Scheduled Reviews',
              value: data.scheduledReviewCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
