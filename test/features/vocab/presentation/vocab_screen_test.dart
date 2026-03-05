import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/vocab/presentation/vocab_screen.dart';

void main() {
  testWidgets(
    'shows custom vocabulary menu and removes custom item after delete',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      await _seedVocabulary(database);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: Scaffold(body: VocabScreen())),
        ),
      );

      await tester.tap(find.text('나만의 단어장'));
      await tester.pumpAndSettle();

      expect(find.text('custom_word'), findsOneWidget);
      expect(find.text('bookmarked_word'), findsOneWidget);
      expect(find.byTooltip('단어 메뉴'), findsOneWidget);

      await tester.tap(find.byTooltip('단어 메뉴'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('custom_word'), findsNothing);
      expect(find.text('bookmarked_word'), findsOneWidget);
      expect(find.text('단어를 삭제했습니다.'), findsOneWidget);
    },
  );
}

Future<void> _seedVocabulary(AppDatabase database) async {
  await database
      .into(database.vocabMaster)
      .insert(
        VocabMasterCompanion.insert(
          id: 'user_custom_word',
          lemma: 'custom_word',
          meaning: '사용자 단어',
        ),
      );
  await database
      .into(database.vocabMaster)
      .insert(
        VocabMasterCompanion.insert(
          id: 'seed_bookmarked',
          lemma: 'bookmarked_word',
          meaning: '북마크 단어',
        ),
      );
  await database
      .into(database.vocabUser)
      .insert(
        VocabUserCompanion.insert(
          vocabId: 'seed_bookmarked',
          isBookmarked: const Value(true),
        ),
      );
}
