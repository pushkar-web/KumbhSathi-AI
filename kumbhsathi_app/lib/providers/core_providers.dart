import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/hive_service.dart';
import '../core/storage/secure_storage.dart';

/// App-wide singletons exposed through Riverpod.

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final hiveServiceProvider = Provider<HiveService>((ref) => HiveService());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    storage: storage,
    onAuthFailure: () async {
      // Clearing tokens flips authStateProvider to unauthenticated,
      // which the router redirect observes and sends the user to /login.
      await storage.clear();
    },
  );
});
