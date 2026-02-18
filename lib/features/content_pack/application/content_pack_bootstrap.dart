import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/content_pack_seeder.dart';

const String _starterPackAssetPath = 'assets/content_packs/starter_pack.json';

final contentPackSeederProvider = Provider<ContentPackSeeder>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return ContentPackSeeder(
    database: database,
    source: const AssetContentPackSource(_starterPackAssetPath),
  );
});

final appBootstrapProvider = FutureProvider<void>((Ref ref) async {
  final seeder = ref.watch(contentPackSeederProvider);
  await seeder.seedOnFirstLaunch();
});
