import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/my/presentation/my_settings_screen.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

void main() {
  testWidgets('support pages open and return without blank placeholders', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('STUDENT');
    await settingsRepository.updateName('민수');
    await settingsRepository.updateTrack('M3');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: MySettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('FAQ'));
    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();
    expect(find.text('루틴 문제는 어떻게 집계되나요?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('문의하기'));
    await tester.tap(find.text('문의하기'));
    await tester.pumpAndSettle();
    expect(find.text('문의 채널'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('개인정보처리방침'));
    await tester.tap(find.text('개인정보처리방침'));
    await tester.pumpAndSettle();
    expect(find.text('수집 항목'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('지원'), findsOneWidget);
  });

  testWidgets('copy email shows snackbar and writes to clipboard channel', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('STUDENT');
    await settingsRepository.updateName('민수');
    await settingsRepository.updateTrack('M3');

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            copiedText = arguments['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: MySettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('문의하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('이메일 복사'));
    await tester.pump();

    expect(copiedText, 'support@resolroutine.app');
    expect(find.text('문의 메일 주소를 복사했어요.'), findsOneWidget);
  });
}
