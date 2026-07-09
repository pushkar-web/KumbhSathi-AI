import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline-first database service using Hive.
/// Caches server responses and queues offline operations for synchronization.
class HiveService {
  static const String _kCacheBoxName = 'kumbhsathi_cache';
  static const String _kQueueBoxName = 'kumbhsathi_sync_queue';

  late final Box _cacheBox;
  late final Box _queueBox;

  /// Initializes Hive and opens required boxes.
  Future<void> init() async {
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox(_kCacheBoxName);
    _queueBox = await Hive.openBox(_kQueueBoxName);
  }

  // ============================================================
  // Caching Methods (GET response caching)
  // ============================================================

  /// Save API response data locally.
  Future<void> cacheResponse(String endpoint, dynamic data) async {
    try {
      await _cacheBox.put(endpoint, data);
      if (kDebugMode) {
        print('💾 Cached response for endpoint: $endpoint');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to cache response: $e');
      }
    }
  }

  /// Retrieve cached API response data.
  dynamic getCachedResponse(String endpoint) {
    return _cacheBox.get(endpoint);
  }

  /// Clear all cached responses.
  Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  // ============================================================
  // Offline Sync Queue Methods (POST/PATCH/DELETE)
  // ============================================================

  /// Queue a write operation when the device is offline.
  Future<void> queueRequest({
    required String path,
    required String method,
    required Map<String, dynamic> body,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final queueItem = {
      'path': path,
      'method': method,
      'body': body,
      'queuedAt': DateTime.now().toIso8601String(),
    };
    
    await _queueBox.put(timestamp, queueItem);
    if (kDebugMode) {
      print('📤 Queued offline request to $path ($method)');
    }
  }

  /// Retrieve all queued requests.
  List<Map<String, dynamic>> getQueuedRequests() {
    final list = <Map<String, dynamic>>[];
    for (var key in _queueBox.keys) {
      final raw = _queueBox.get(key);
      if (raw is Map) {
        list.add({
          'key': key,
          ...Map<String, dynamic>.from(raw),
        });
      }
    }
    // Sort by queued time
    list.sort((a, b) => (a['queuedAt'] as String).compareTo(b['queuedAt'] as String));
    return list;
  }

  /// Remove a request from the queue after successful synchronization.
  Future<void> dequeueRequest(dynamic key) async {
    await _queueBox.delete(key);
    if (kDebugMode) {
      print('✅ Dequeued request key: $key');
    }
  }

  /// Check if there are any pending queued requests.
  bool get hasPendingRequests => _queueBox.isNotEmpty;

  /// Clear the synchronization queue.
  Future<void> clearQueue() async {
    await _queueBox.clear();
  }
}
