import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_tokens.dart';
import '../../application/report_providers.dart';

class VocabWrongWordsSection extends ConsumerStatefulWidget {
  const VocabWrongWordsSection({
    super.key,
    required this.wrongVocabIds,
    this.customLemmaById,
    this.maxVisible = 6,
  });

  final List<String> wrongVocabIds;
  final Map<String, String>? customLemmaById;
  final int maxVisible;

  @override
  ConsumerState<VocabWrongWordsSection> createState() =>
      _VocabWrongWordsSectionState();
}

class _VocabWrongWordsSectionState
    extends ConsumerState<VocabWrongWordsSection> {
  late Future<Map<String, String>> _lemmaMapFuture;

  @override
  void initState() {
    super.initState();
    _lemmaMapFuture = _loadLemmaMap();
  }

  @override
  void didUpdateWidget(covariant VocabWrongWordsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameIds(oldWidget.wrongVocabIds, widget.wrongVocabIds) ||
        !_sameLemmaMap(oldWidget.customLemmaById, widget.customLemmaById)) {
      _lemmaMapFuture = _loadLemmaMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wrongVocabIds.isEmpty) {
      return Text(
        '틀린 단어 없음',
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      );
    }

    final visibleCount = widget.maxVisible
        .clamp(1, widget.wrongVocabIds.length)
        .toInt();
    final visibleIds = widget.wrongVocabIds
        .take(visibleCount)
        .toList(growable: false);
    final overflowCount = widget.wrongVocabIds.length - visibleIds.length;

    return FutureBuilder<Map<String, String>>(
      future: _lemmaMapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final lemmaMap = snapshot.data ?? const <String, String>{};
        final labels = <String>[
          for (final id in visibleIds) lemmaMap[id] ?? id,
        ];

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final label in labels) _chip(label),
            if (overflowCount > 0) _chip('외 $overflowCount개'),
          ],
        );
      },
    );
  }

  Future<Map<String, String>> _loadLemmaMap() async {
    final customMap = _resolveCustomLemmas(widget.wrongVocabIds);
    final missingIds = <String>[
      for (final id in widget.wrongVocabIds)
        if (!customMap.containsKey(id)) id,
    ];
    if (missingIds.isEmpty) {
      return customMap;
    }

    final repositoryMap = await ref
        .read(vocabLemmaRepositoryProvider)
        .loadLemmaMapByVocabIds(missingIds);
    return <String, String>{...repositoryMap, ...customMap};
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
      ),
    );
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

  Map<String, String> _resolveCustomLemmas(List<String> ids) {
    final customLemmaById = widget.customLemmaById;
    if (customLemmaById == null || customLemmaById.isEmpty) {
      return const <String, String>{};
    }

    final resolved = <String, String>{};
    for (final id in ids) {
      final lemma = customLemmaById[id];
      if (lemma == null) {
        continue;
      }
      resolved[id] = lemma;
    }
    return resolved;
  }

  bool _sameLemmaMap(Map<String, String>? left, Map<String, String>? right) {
    if (identical(left, right)) {
      return true;
    }
    if (left == null || right == null) {
      return left == right;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
