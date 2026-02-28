import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/ui/components/routine_card.dart';

void main() {
  testWidgets('RoutineCard stays stable in compact grid constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 131,
              height: 112.5,
              child: RoutineCard(
                title: '오늘의 단어 암기',
                subtitle: '핵심 단어 복습',
                icon: Icons.menu_book_rounded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('오늘의 단어 암기'), findsOneWidget);
  });
}
