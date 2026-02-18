import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/app/app.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/content_pack/application/content_pack_bootstrap.dart';

void main() {
  testWidgets('shows dashboard after bootstrap', (WidgetTester tester) async {
    final testDatabase = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(testDatabase.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDatabase),
          appBootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('Learning Dashboard'));

    expect(find.text('Learning Dashboard'), findsOneWidget);
    expect(find.text('Content Packs'), findsOneWidget);
  });
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Did not find expected widget after ${maxPumps * 50}ms.');
}
