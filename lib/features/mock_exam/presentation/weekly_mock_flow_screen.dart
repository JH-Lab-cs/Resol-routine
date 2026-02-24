import 'package:flutter/material.dart';

import 'mock_exam_flow_screen.dart';

export 'mock_exam_flow_screen.dart' show MockExamFlowExitAction;

class WeeklyMockFlowScreen extends StatelessWidget {
  const WeeklyMockFlowScreen({super.key, required this.track, this.nowLocal});

  final String track;
  final DateTime? nowLocal;

  @override
  Widget build(BuildContext context) {
    return MockExamFlowScreen(
      track: track,
      nowLocal: nowLocal,
      config: weeklyMockExamFlowConfig,
    );
  }
}
