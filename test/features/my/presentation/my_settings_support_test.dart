import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/family/application/family_providers.dart';
import 'package:resol_routine/features/my/presentation/my_settings_screen.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';
import '../../../test_helpers/fake_auth_session.dart';
import '../../../test_helpers/fake_family_repository.dart';

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

    await tester.scrollUntilVisible(
      find.text('FAQ'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();
    expect(find.text('루틴 문제는 어떻게 집계되나요?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final contactTile = find.widgetWithText(ListTile, '문의하기');
    await tester.scrollUntilVisible(
      contactTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<ListTile>(contactTile).onTap!.call();
    await tester.pumpAndSettle();
    expect(find.text('문의 채널'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('개인정보처리방침'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('개인정보처리방침'));
    await tester.pumpAndSettle();
    expect(find.text('수집 항목'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('지원'), findsOneWidget);
  });

  testWidgets('shows student profile card and allows copying student code', (
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
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(),
          familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
        ],
        child: const MaterialApp(home: MySettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('민수 님'), findsOneWidget);
    expect(find.text('내 정보 수정'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-copy-student-code')),
    );
    await tester.pump();

    expect(copiedText, isNotNull);
    expect(copiedText, '654321');
    expect(find.text('자녀 코드를 복사했어요.'), findsOneWidget);
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
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(),
          familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
        ],
        child: const MaterialApp(home: MySettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final contactTile = find.widgetWithText(ListTile, '문의하기');
    await tester.scrollUntilVisible(
      contactTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(contactTile);
    tester.widget<ListTile>(contactTile).onTap!.call();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '이메일 복사'));
    await tester.pump();

    expect(copiedText, 'support@resolroutine.app');
    expect(find.text('문의 메일 주소를 복사했어요.'), findsOneWidget);
  });

  testWidgets(
    'toggles dev tools setting after tapping app version seven times',
    (WidgetTester tester) async {
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

      final versionRow = find.byKey(
        const ValueKey<String>('settings-app-version-row'),
      );
      await tester.scrollUntilVisible(
        versionRow,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(versionRow, findsOneWidget);

      for (var i = 0; i < 7; i += 1) {
        await tester.tap(versionRow);
        await tester.pump();
      }
      expect((await settingsRepository.get()).devToolsEnabled, isTrue);
      expect(find.text('개발자 메뉴를 활성화했습니다.'), findsOneWidget);

      for (var i = 0; i < 7; i += 1) {
        await tester.tap(versionRow);
        await tester.pump();
      }
      expect((await settingsRepository.get()).devToolsEnabled, isFalse);
    },
  );
}
