import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/hero_progress_card.dart';
import '../../../core/ui/components/routine_card.dart';
import '../../../core/ui/components/section_title.dart';
import '../../../core/ui/label_maps.dart';
import '../../today/application/today_session_providers.dart';
import '../application/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuiz,
    required this.onOpenVocab,
    required this.onOpenTodayVocabQuiz,
    required this.onOpenWrongNotes,
    required this.onOpenMy,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenVocab;
  final VoidCallback onOpenTodayVocabQuiz;
  final VoidCallback onOpenWrongNotes;
  final VoidCallback onOpenMy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTrack = ref.watch(selectedTrackProvider);
    final displayName = ref.watch(displayNameProvider);
    final summary = ref.watch(homeRoutineSummaryProvider(selectedTrack));

    return AppPageBody(
      showDecorativeBackground: true,
      child: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('홈 데이터를 불러오지 못했어요.\n$error', textAlign: TextAlign.center),
        ),
        data: (data) {
          final completed = data.progress.completed;
          final ctaLabel = _ctaLabel(completed: completed, total: 6);

          return ListView(
            children: [
              Text('오늘도 화이팅, $displayName! 👋', style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '매일 6문제로 완성하는 1등급 습관',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    '현재 트랙 ${displayTrack(selectedTrack)}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onOpenMy,
                    borderRadius: BorderRadius.circular(AppRadius.buttonPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppRadius.buttonPill,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTrack(selectedTrack),
                            style: AppTypography.label.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.mdLg),
              HeroProgressCard(
                completed: completed,
                total: 6,
                listeningCompleted: data.progress.listeningCompleted,
                readingCompleted: data.progress.readingCompleted,
                ctaLabel: ctaLabel,
                onTap: onOpenQuiz,
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionTitle(title: '나의 학습 루틴'),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.12,
                children: [
                  RoutineCard(
                    title: '하루 루틴 문제풀기',
                    subtitle: '오늘 6문제 학습',
                    icon: Icons.play_circle_fill_rounded,
                    onTap: onOpenQuiz,
                  ),
                  RoutineCard(
                    title: '오늘의 단어 암기',
                    subtitle: '핵심 단어 복습',
                    icon: Icons.menu_book_rounded,
                    onTap: onOpenVocab,
                  ),
                  RoutineCard(
                    title: '오답 복습',
                    subtitle: '실수 원인 점검',
                    icon: Icons.assignment_late_rounded,
                    onTap: onOpenWrongNotes,
                  ),
                  RoutineCard(
                    title: '오늘의 단어 시험',
                    subtitle: '20문제 5지선다',
                    icon: Icons.quiz_rounded,
                    onTap: onOpenTodayVocabQuiz,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _ctaLabel({required int completed, required int total}) {
    if (completed <= 0) {
      return '오늘 루틴 시작하기';
    }
    if (completed < total) {
      return '지금까지 푼 문제 이어하기';
    }
    return '오늘 루틴 완료 🎉';
  }
}
