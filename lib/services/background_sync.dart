import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../config/api_config.dart';
import 'api_service.dart';
import 'offline_store.dart';
import 'offline_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
void syncDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final storage = StorageService();
    final owner = await storage.getSyncOwner();
    if (owner == null ||
        !owner.startsWith('${ApiConfig.baseUrl}|') ||
        !await storage.hasToken()) {
      return true;
    }
    final store = await OfflineStore.open();
    final api = ApiService(storage);
    final queue = OfflineService(
      store,
      (method, path, body) => api.sendOnline(method, path, body),
    );
    try {
      await queue.activate(owner);
      if (await storage.getSyncOwner() != owner) return true;
      await queue.sync();
      return queue.pendingCount == 0 || queue.hasFailures || queue.needsLogin;
    } finally {
      queue.dispose();
      api.dispose();
      await store.db.close();
    }
  });
}

class BackgroundSync {
  static bool _ready = false;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> initialize() async {
    if (!supported) return;
    try {
      await Workmanager().initialize(syncDispatcher);
      _ready = true;
      await Workmanager().registerPeriodicTask(
        'vesta-sync-periodic',
        'vesta-outbox',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('Background initialization unavailable: $e');
    }
  }

  static Future<void> schedule() async {
    if (!supported || !_ready) return;
    try {
      await Workmanager().registerOneOffTask(
        'vesta-sync-pending',
        'vesta-outbox',
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (e) {
      debugPrint('Background scheduling unavailable: $e');
    }
  }
}
