import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/hero_progress_card.dart';
import '../../../core/ui/components/routine_card.dart';
import '../../../core/ui/components/section_title.dart';
import '../../today/application/today_session_providers.dart';
import '../application/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onOpenQuiz,
    required this.onOpenVocab,
    required this.onOpenWrongNotes,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenVocab;
  final VoidCallback onOpenWrongNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTrack = ref.watch(selectedTrackProvider);
    final displayName = ref.watch(displayNameProvider);
    final summary = ref.watch(homeRoutineSummaryProvider(selectedTrack));

    return AppScaffold(
      body: summary.when(
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
              _TrackSelector(selectedTrack: selectedTrack),
              const SizedBox(height: AppSpacing.md),
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

class _TrackSelector extends ConsumerWidget {
  const _TrackSelector({required this.selectedTrack});

  final String selectedTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tracks = <String>['M3', 'H1', 'H2', 'H3'];

    return Wrap(
      spacing: AppSpacing.xs,
      children: tracks
          .map((track) {
            final selected = track == selectedTrack;
            return ChoiceChip(
              label: Text(track),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              labelStyle: AppTypography.label.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              shape: const StadiumBorder(),
              onSelected: (_) {
                ref.read(selectedTrackProvider.notifier).state = track;
              },
            );
          })
          .toList(growable: false),
    );
  }
}
