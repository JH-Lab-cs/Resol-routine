import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/section_title.dart';
import '../application/vocab_providers.dart';
import '../data/vocab_repository.dart';

enum VocabCollectionTab { today, mine }

final vocabSearchProvider = StateProvider<String>((Ref ref) => '');
final vocabCollectionTabProvider = StateProvider<VocabCollectionTab>(
  (Ref ref) => VocabCollectionTab.today,
);

final vocabListProvider =
    FutureProvider.family<
      List<VocabListItem>,
      ({VocabCollectionTab tab, String query})
    >((Ref ref, ({VocabCollectionTab tab, String query}) request) async {
      final repository = ref.watch(vocabRepositoryProvider);
      if (request.tab == VocabCollectionTab.today) {
        return repository.listTodayVocabulary(
          searchTerm: request.query,
          count: 20,
        );
      }
      return repository.listMyVocabulary(searchTerm: request.query);
    });

class VocabScreen extends ConsumerStatefulWidget {
  const VocabScreen({super.key});

  @override
  ConsumerState<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends ConsumerState<VocabScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(vocabCollectionTabProvider);
    final query = ref.watch(vocabSearchProvider);
    final request = (tab: selectedTab, query: query);
    final vocabAsync = ref.watch(vocabListProvider(request));

    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: '단어장',
            subtitle: selectedTab == VocabCollectionTab.today
                ? '오늘 학습할 단어를 확인해 보세요.'
                : '직접 저장한 단어와 북마크를 관리해 보세요.',
            trailing: selectedTab == VocabCollectionTab.mine
                ? IconButton(
                    onPressed: _showAddVocabularySheet,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: '단어 추가',
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _CollectionTabSelector(
            selectedTab: selectedTab,
            onChanged: (tab) {
              ref.read(vocabCollectionTabProvider.notifier).state = tab;
              setState(_expandedIds.clear);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              ref.read(vocabSearchProvider.notifier).state = value;
            },
            decoration: InputDecoration(
              hintText: selectedTab == VocabCollectionTab.today
                  ? '오늘 단어 검색'
                  : '나만의 단어 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: vocabAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('단어를 불러오지 못했습니다.\n$error')),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      selectedTab == VocabCollectionTab.today
                          ? '오늘의 단어가 없습니다.'
                          : '나만의 단어가 없습니다.',
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final expanded = _expandedIds.contains(item.id);

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (expanded) {
                              _expandedIds.remove(item.id);
                            } else {
                              _expandedIds.add(item.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.lemma,
                                      style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      item.isBookmarked
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      color: item.isBookmarked
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(vocabRepositoryProvider)
                                          .toggleBookmark(item.id);
                                      ref.invalidate(
                                        vocabListProvider(request),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                item.meaning,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (expanded && item.example != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '예문: ${item.example!}',
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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

  Future<void> _showAddVocabularySheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _AddVocabularySheet(
          onSubmit: (draft) {
            return ref
                .read(vocabRepositoryProvider)
                .addVocabulary(
                  lemma: draft.lemma,
                  meaning: draft.meaning,
                  pos: draft.pos,
                  example: draft.example,
                );
          },
        );
      },
    );

    if (!mounted || saved != true) {
      return;
    }

    ref.read(vocabCollectionTabProvider.notifier).state =
        VocabCollectionTab.mine;
    final query = ref.read(vocabSearchProvider);
    final tab = ref.read(vocabCollectionTabProvider);
    ref.invalidate(vocabListProvider((tab: tab, query: query)));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('단어를 저장했습니다.')));
  }
}

class _AddVocabularyDraft {
  const _AddVocabularyDraft({
    required this.lemma,
    required this.meaning,
    required this.pos,
    required this.example,
  });

  final String lemma;
  final String meaning;
  final String? pos;
  final String? example;
}

class _AddVocabularySheet extends StatefulWidget {
  const _AddVocabularySheet({required this.onSubmit});

  final Future<void> Function(_AddVocabularyDraft draft) onSubmit;

  @override
  State<_AddVocabularySheet> createState() => _AddVocabularySheetState();
}

class _AddVocabularySheetState extends State<_AddVocabularySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _lemmaController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final TextEditingController _posController = TextEditingController();
  final TextEditingController _exampleController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _lemmaController.dispose();
    _meaningController.dispose();
    _posController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('단어 추가', style: AppTypography.section),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '새 단어를 저장하면 단어장에 바로 추가됩니다.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _lemmaController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '단어',
                  hintText: '예: analyze',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '단어를 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _meaningController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '뜻',
                  hintText: '예: 분석하다',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '뜻을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _posController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '품사 (선택)',
                  hintText: '예: verb',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _exampleController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '예문 (선택)',
                  hintText: '예: We need to analyze the results.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSubmit(
        _AddVocabularyDraft(
          lemma: _lemmaController.text,
          meaning: _meaningController.text,
          pos: _posController.text,
          example: _exampleController.text,
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('단어 저장에 실패했습니다.')));
      setState(() {
        _isSaving = false;
      });
    }
  }
}

class _CollectionTabSelector extends StatelessWidget {
  const _CollectionTabSelector({
    required this.selectedTab,
    required this.onChanged,
  });

  final VocabCollectionTab selectedTab;
  final ValueChanged<VocabCollectionTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: '오늘의 단어장',
              selected: selectedTab == VocabCollectionTab.today,
              onTap: () => onChanged(VocabCollectionTab.today),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: '나만의 단어장',
              selected: selectedTab == VocabCollectionTab.mine,
              onTap: () => onChanged(VocabCollectionTab.mine),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.buttonPill),
          color: selected ? AppColors.primary : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
