import 'package:flutter/material.dart';

import 'mock_exam_flow_screen.dart';

class MonthlyMockFlowScreen extends StatelessWidget {
  const MonthlyMockFlowScreen({super.key, required this.track, this.nowLocal});

  final String track;
  final DateTime? nowLocal;

  @override
  Widget build(BuildContext context) {
    return MockExamFlowScreen(
      track: track,
      nowLocal: nowLocal,
      config: monthlyMockExamFlowConfig,
    );
  }
}
