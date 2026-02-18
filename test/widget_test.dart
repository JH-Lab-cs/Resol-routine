import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/app/app.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';

void main() {
  testWidgets('shows dashboard after bootstrap', (WidgetTester tester) async {
    final testDatabase = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(testDatabase.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDatabase)],
        child: const ResolRoutineApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Learning Dashboard'), findsOneWidget);
    expect(find.text('Content Packs'), findsOneWidget);
  });
}
