import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/time/day_key.dart';
import '../../report/application/report_providers.dart';
import '../../today/application/today_session_providers.dart';
import '../application/vocab_providers.dart';
import '../data/vocab_repository.dart';

enum VocabQuizExitAction { home, vocab }

final todayVocabQuizProvider = FutureProvider<List<VocabQuizQuestion>>((
  Ref ref,
) async {
  final repository = ref.watch(vocabRepositoryProvider);
  return repository.loadTodayQuizQuestions(count: 20);
});

class TodayVocabQuizScreen extends ConsumerStatefulWidget {
  const TodayVocabQuizScreen({super.key});

  @override
  ConsumerState<TodayVocabQuizScreen> createState() =>
      _TodayVocabQuizScreenState();
}

class _TodayVocabQuizScreenState extends ConsumerState<TodayVocabQuizScreen> {
  static const List<String> _optionLabels = <String>['A', 'B', 'C', 'D', 'E'];

  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _submitted = false;
  bool _currentCorrect = false;
  int _correctCount = 0;
  final Set<String> _wrongVocabIds = <String>{};
  bool _completionPersistAttempted = false;

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(todayVocabQuizProvider);

    return AppScaffold(
      appBar: AppBar(title: const Text('오늘의 단어 시험')),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('단어 시험을 불러오지 못했습니다.\n$error')),
        data: (questions) {
          if (questions.isEmpty) {
            return _buildEmptyState();
          }
          if (_currentIndex >= questions.length) {
            return _buildCompletionState(total: questions.length);
          }

          final question = questions[_currentIndex];
          return ListView(
            children: [
              Row(
                children: [
                  Text(
                    '문제 ${_currentIndex + 1} / ${questions.length}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '정답 $_correctCount',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '아래 영어 단어의 뜻을 고르세요.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        question.lemma,
                        style: AppTypography.display.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...List<Widget>.generate(5, (index) {
                final selected = _selectedOptionIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _QuizOptionTile(
                    label: _optionLabels[index],
                    text: question.options[index],
                    selected: selected,
                    enabled: !_submitted,
                    onTap: () {
                      setState(() {
                        _selectedOptionIndex = index;
                      });
                    },
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
              if (!_submitted)
                PrimaryPillButton(
                  label: '제출하기',
                  onPressed: _selectedOptionIndex == null
                      ? null
                      : () {
                          final isCorrect =
                              _selectedOptionIndex ==
                              question.correctOptionIndex;
                          setState(() {
                            _submitted = true;
                            _currentCorrect = isCorrect;
                            if (isCorrect) {
                              _correctCount += 1;
                            } else {
                              _wrongVocabIds.add(question.vocabId);
                            }
                          });
                        },
                ),
              if (_submitted) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _currentCorrect
                        ? const Color(0xFFE5F6EA)
                        : const Color(0xFFFFE7EA),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    _currentCorrect
                        ? '정답입니다.'
                        : '오답입니다. 정답: ${question.options[question.correctOptionIndex]}',
                    style: AppTypography.body,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryPillButton(
                  label: _currentIndex == questions.length - 1 ? '완료' : '다음',
                  onPressed: () => _goNextOrComplete(questions),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _goNextOrComplete(List<VocabQuizQuestion> questions) async {
    final isLastQuestion = _currentIndex == questions.length - 1;
    setState(() {
      _currentIndex += 1;
      _selectedOptionIndex = null;
      _submitted = false;
      _currentCorrect = false;
    });

    if (!isLastQuestion) {
      return;
    }

    await _persistCompletionResult(questions);
  }

  Future<void> _persistCompletionResult(
    List<VocabQuizQuestion> questions,
  ) async {
    if (_completionPersistAttempted) {
      return;
    }
    _completionPersistAttempted = true;

    final track = ref.read(selectedTrackProvider);
    final dayKey = formatDayKey(DateTime.now());
    final container = ProviderScope.containerOf(context, listen: false);

    try {
      await ref
          .read(vocabQuizResultsRepositoryProvider)
          .upsertDailyResult(
            dayKey: dayKey,
            track: track,
            totalCount: questions.length,
            correctCount: _correctCount,
            wrongVocabIds: _wrongVocabIds.toList(growable: false),
          );
      container.invalidate(studentCumulativeReportProvider(track));
      container.invalidate(studentTodayReportProvider(track));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('단어시험 결과 저장에 실패했습니다.\n$error')));
    }
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('단어 데이터가 아직 없습니다.', style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '단어장에 단어를 추가한 뒤 다시 시도해 주세요.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        PrimaryPillButton(
          label: '단어장으로',
          onPressed: () {
            Navigator.of(context).pop(VocabQuizExitAction.vocab);
          },
        ),
      ],
    );
  }

  Widget _buildCompletionState({required int total}) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            gradient: const LinearGradient(
              colors: <Color>[AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppShadows.floating,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 단어 시험 완료',
                style: AppTypography.title.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '점수: $_correctCount / $total',
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryPillButton(
          label: '홈으로',
          onPressed: () {
            Navigator.of(context).pop(VocabQuizExitAction.home);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop(VocabQuizExitAction.vocab);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.buttonPill),
            ),
          ),
          child: const Text('단어장 보기'),
        ),
      ],
    );
  }
}

class _QuizOptionTile extends StatelessWidget {
  const _QuizOptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryContainer : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            '$label. $text',
            style: AppTypography.body.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
