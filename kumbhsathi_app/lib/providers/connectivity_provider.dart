import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live connectivity stream (connectivity_plus 6.x emits a list of results).
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// True when any usable network transport is up. Defaults to `true` before
/// the first event so app start never flashes the offline banner spuriously.
final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).valueOrNull;
  if (results == null) return true;
  return results.any((r) =>
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.vpn);
});
