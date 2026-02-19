import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/wrong_note_repository.dart';

final wrongNoteRepositoryProvider = Provider<WrongNoteRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return WrongNoteRepository(database: database);
});
