import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/hive_service.dart';
import 'providers/core_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final hiveService = HiveService();
  await hiveService.init();
  
  runApp(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(hiveService),
      ],
      child: const KumbhSathiApp(),
    ),
  );
}
