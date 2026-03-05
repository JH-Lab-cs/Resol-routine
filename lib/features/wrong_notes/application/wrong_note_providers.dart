import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/wrong_note_repository.dart';

final wrongNoteRepositoryProvider = Provider<WrongNoteRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return WrongNoteRepository(database: database);
});

final wrongNoteListProvider = FutureProvider<List<WrongNoteListItem>>((
  Ref ref,
) {
  final repository = ref.watch(wrongNoteRepositoryProvider);
  return repository.listIncorrectAttempts();
});

final wrongNoteDetailProvider = FutureProvider.family<WrongNoteDetail, int>((
  Ref ref,
  int attemptId,
) {
  final repository = ref.watch(wrongNoteRepositoryProvider);
  return repository.loadDetail(attemptId);
});
