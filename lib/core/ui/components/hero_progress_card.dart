import 'package:flutter/material.dart';

import '../app_tokens.dart';

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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          colors: [Color(0xFF5E51D3), Color(0xFF7F70F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332C2374),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘 루틴 진행도',
              style: AppTypography.label.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$completed / $total 완료',
              style: AppTypography.title.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SegmentedProgress(
              listeningCompleted: listeningCompleted,
              readingCompleted: readingCompleted,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: Text(
                  ctaLabel,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
          color: const Color(0xFFBFD0FF),
        ),
        const SizedBox(height: AppSpacing.xs),
        _ProgressRow(
          label: '독해',
          completed: readingCompleted,
          color: const Color(0xFFFFD6A3),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.completed,
    required this.color,
  });

  final String label;
  final int completed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: AppTypography.label.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            children: List<Widget>.generate(3, (index) {
              final active = index < completed;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 24,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  color: active ? color : Colors.white24,
                ),
              );
            }),
          ),
        ),
        Text(
          '$completed/3',
          style: AppTypography.label.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
