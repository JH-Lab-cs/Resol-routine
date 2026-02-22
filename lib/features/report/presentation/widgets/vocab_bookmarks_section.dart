import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_tokens.dart';
import '../../application/report_providers.dart';

class VocabBookmarksSection extends ConsumerStatefulWidget {
  const VocabBookmarksSection({
    super.key,
    required this.bookmarkedVocabIds,
    this.title = '북마크 단어장',
  });

  final List<String> bookmarkedVocabIds;
  final String title;

  @override
  ConsumerState<VocabBookmarksSection> createState() =>
      _VocabBookmarksSectionState();
}

class _VocabBookmarksSectionState extends ConsumerState<VocabBookmarksSection> {
  static const double _itemExtent = 40;
  static const double _maxListHeight = 240;

  bool _expanded = false;
  Future<Map<String, String>>? _lemmaMapFuture;

  @override
  void didUpdateWidget(covariant VocabBookmarksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIds(oldWidget.bookmarkedVocabIds, widget.bookmarkedVocabIds)) {
      _lemmaMapFuture = _expanded ? _loadLemmaMap() : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.bookmarkedVocabIds.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: AppTypography.section),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '북마크 $count개',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                if (count == 0)
                  Text(
                    '북마크 단어가 없습니다.',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  FutureBuilder<Map<String, String>>(
                    future: _lemmaMapFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final lemmaMap =
                          snapshot.data ?? const <String, String>{};
                      return SizedBox(
                        height: _listHeight(count),
                        child: ListView.builder(
                          itemCount: count,
                          itemExtent: _itemExtent,
                          itemBuilder: (context, index) {
                            final id = widget.bookmarkedVocabIds[index];
                            final label = lemmaMap[id] ?? id;
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _lemmaMapFuture ??= _loadLemmaMap();
      }
    });
  }

  Future<Map<String, String>> _loadLemmaMap() {
    return ref
        .read(vocabLemmaRepositoryProvider)
        .loadLemmaMapByVocabIds(widget.bookmarkedVocabIds);
  }

  double _listHeight(int count) {
    final raw = count * _itemExtent;
    if (raw <= _itemExtent) {
      return _itemExtent;
    }
    if (raw > _maxListHeight) {
      return _maxListHeight;
    }
    return raw;
  }

  bool _sameIds(List<String> left, List<String> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }
}
