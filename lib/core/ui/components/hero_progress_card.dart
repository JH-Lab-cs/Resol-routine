import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'primary_pill_button.dart';

class HeroProgressCard extends StatelessWidget {
  const HeroProgressCard({
    super.key,
    required this.completed,
    required this.total,
    required this.listeningCompleted,
    required this.readingCompleted,
    required this.ctaLabel,
    required this.onTap,
  });

  final int completed;
  final int total;
  final int listeningCompleted;
  final int readingCompleted;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressPercent = total <= 0 ? 0 : (completed / total * 100).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF5B61F5), Color(0xFF757BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘 루틴 진행도',
              style: AppTypography.label.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$completed',
                  style: AppTypography.display.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  ' / $total',
                  style: AppTypography.title.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '$progressPercent%',
                    style: AppTypography.label.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '듣기 3문제 + 독해 3문제를 매일 완주해요.',
              style: AppTypography.body.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: AppSpacing.mdLg),
            _SegmentedProgress(
              listeningCompleted: listeningCompleted,
              readingCompleted: readingCompleted,
            ),
            const SizedBox(height: AppSpacing.mdLg),
            Theme(
              data: Theme.of(context).copyWith(
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.buttonPill),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              child: PrimaryPillButton(label: ctaLabel, onPressed: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.listeningCompleted,
    required this.readingCompleted,
  });

  final int listeningCompleted;
  final int readingCompleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressRow(
          label: '듣기',
          completed: listeningCompleted,
          activeColor: Colors.white,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ProgressRow(
          label: '독해',
          completed: readingCompleted,
          activeColor: AppColors.streak,
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.completed,
    required this.activeColor,
  });

  final String label;
  final int completed;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final safeCompleted = completed.clamp(0, 3);
    final percent = safeCompleted >= 3
        ? 100
        : ((safeCompleted * 100) / 3).floor();

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: AppTypography.label.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Row(
            children: List<Widget>.generate(3, (index) {
              final active = index < safeCompleted;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == 2 ? 0 : AppSpacing.xs,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      color: active ? activeColor : Colors.white30,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$percent%',
          style: AppTypography.label.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
