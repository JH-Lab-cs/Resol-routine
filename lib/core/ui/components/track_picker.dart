import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../label_maps.dart';

const List<String> kTrackOptions = <String>['M3', 'H1', 'H2', 'H3'];

class TrackPickerChip extends StatelessWidget {
  const TrackPickerChip({
    super.key,
    required this.track,
    required this.onChanged,
  });

  final String track;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      onTap: () async {
        final selected = await showTrackPickerBottomSheet(
          context,
          selectedTrack: track,
        );
        if (selected == null || selected == track) {
          return;
        }
        onChanged(selected);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.buttonPill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTrack(track),
              style: AppTypography.label.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showTrackPickerBottomSheet(
  BuildContext context, {
  required String selectedTrack,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('트랙 선택', style: AppTypography.section),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '현재 학년에 맞는 트랙을 선택하세요.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...kTrackOptions.map((track) {
                final selected = track == selectedTrack;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    tileColor: selected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    title: Text(
                      displayTrack(track),
                      style: AppTypography.body.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(track, style: AppTypography.label),
                    trailing: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(track),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
