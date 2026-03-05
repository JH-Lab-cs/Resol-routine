import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/user_settings_providers.dart';

final devToolsVisibleProvider = Provider<bool>((Ref ref) {
  final settings = ref.watch(userSettingsProvider).valueOrNull;
  final persistedEnabled = settings?.devToolsEnabled ?? false;
  return !kReleaseMode || persistedEnabled;
});
