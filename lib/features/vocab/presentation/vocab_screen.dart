import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/section_title.dart';
import '../application/vocab_providers.dart';
import '../data/vocab_repository.dart';

final vocabSearchProvider = StateProvider<String>((Ref ref) => '');

final vocabListProvider = FutureProvider.family<List<VocabListItem>, String>((
  Ref ref,
  String query,
) async {
  final repository = ref.watch(vocabRepositoryProvider);
  return repository.listVocabulary(searchTerm: query);
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
    final query = ref.watch(vocabSearchProvider);
    final vocabAsync = ref.watch(vocabListProvider(query));

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '단어장', subtitle: '뜻과 예문을 확인하고 북마크로 모아보세요.'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              ref.read(vocabSearchProvider.notifier).state = value;
            },
            decoration: const InputDecoration(
              hintText: '단어 검색 (lemma)',
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
                  return const Center(child: Text('검색 결과가 없습니다.'));
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
                                      ref.invalidate(vocabListProvider(query));
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
                                  'Example: ${item.example!}',
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
}
