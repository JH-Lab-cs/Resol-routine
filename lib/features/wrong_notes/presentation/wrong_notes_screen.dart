import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/section_title.dart';
import '../application/wrong_note_providers.dart';
import '../data/wrong_note_repository.dart';

final wrongNoteListProvider = FutureProvider<List<WrongNoteListItem>>((
  Ref ref,
) {
  final repository = ref.watch(wrongNoteRepositoryProvider);
  return repository.listIncorrectAttempts();
});

final wrongNoteDetailProvider = FutureProvider.family<WrongNoteDetail, int>((
  Ref ref,
  int attemptId,
) {
  final repository = ref.watch(wrongNoteRepositoryProvider);
  return repository.loadDetail(attemptId);
});

class WrongNotesScreen extends ConsumerWidget {
  const WrongNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrongNotesAsync = ref.watch(wrongNoteListProvider);

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: '오답노트',
            subtitle: '최근 오답을 확인하고 근거 문장을 복습하세요.',
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: wrongNotesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('오답을 불러오지 못했습니다.\n$error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('아직 오답이 없습니다.'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WrongNoteDetailScreen(
                                attemptId: item.attemptId,
                              ),
                            ),
                          );
                        },
                        title: Text(
                          '${item.dayKey} · ${item.track} · ${item.typeTag}',
                        ),
                        subtitle: Text('${item.skill} · 오답'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WrongNoteDetailScreen extends ConsumerWidget {
  const WrongNoteDetailScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(wrongNoteDetailProvider(attemptId));

    return Scaffold(
      appBar: AppBar(title: const Text('오답 상세')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('상세를 불러오지 못했습니다.\n$error')),
        data: (detail) {
          final evidenceIds = detail.question.evidenceSentenceIds.toSet();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                '${detail.dayKey} · ${detail.question.track} · ${detail.question.typeTag}',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(detail.question.prompt, style: AppTypography.section),
              const SizedBox(height: AppSpacing.md),
              ..._optionKeys.map((key) {
                final isCorrect = key == detail.question.answerKey;
                final isSelected = key == detail.userAnswer;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFFD8F3DE)
                        : isSelected
                        ? const Color(0xFFFFE3E7)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('$key. ${detail.question.options.byKey(key)}'),
                );
              }),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '정답: ${detail.question.answerKey}',
                style: AppTypography.body,
              ),
              if (detail.wrongReasonTag != null)
                Text(
                  '오답 태그: ${detail.wrongReasonTag}',
                  style: AppTypography.label.copyWith(color: AppColors.warning),
                ),
              const SizedBox(height: AppSpacing.md),
              Text('해설', style: AppTypography.section),
              const SizedBox(height: AppSpacing.xs),
              Text(detail.question.whyCorrectKo),
              const SizedBox(height: AppSpacing.sm),
              ..._optionKeys.map(
                (key) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('$key: ${detail.question.whyWrongKo.byKey(key)}'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('근거 문장', style: AppTypography.section),
              const SizedBox(height: AppSpacing.xs),
              ...detail.question.sourceLines.map((line) {
                final highlighted = line.containsEvidence(evidenceIds);
                final prefix = detail.question.skill == 'READING'
                    ? '${line.index + 1}. '
                    : '${line.speaker}: ';
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: highlighted ? const Color(0xFFFFF2C2) : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('$prefix${line.text}'),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

const List<String> _optionKeys = <String>['A', 'B', 'C', 'D', 'E'];
