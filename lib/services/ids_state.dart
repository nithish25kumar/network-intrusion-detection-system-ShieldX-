import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/alert.dart';
import 'api_service.dart';
import 'websocket_service.dart';

class IdsState extends ChangeNotifier {
  final ApiService api = ApiService();
  final WebSocketService _ws = WebSocketService();
  Timer? _pollTimer;

  List<IdsAlert> alerts = [];
  Map<String, dynamic> stats = {};
  bool monitoringActive = false;
  bool loading = false;
  String? error;

  void startListening() {
    _ws.connect();
    _ws.alertStream.listen((alert) {
      alerts.insert(0, alert);
      if (alerts.length > 500) alerts.removeLast(); // cap in-memory list
      notifyListeners();
    });

    // Backup polling: refresh from the REST API every 4 seconds regardless
    // of whether the WebSocket push is working. This guarantees the UI
    // stays up to date even if a live push is dropped or delayed.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshAll();
    });
  }

  Future<void> refreshAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final fetched = await api.fetchAlerts(limit: 100);
      final fetchedStats = await api.fetchStats();
      alerts = fetched;
      stats = fetchedStats;
      monitoringActive = fetchedStats['monitoring_active'] == true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleMonitoring({String mode = 'live', String? csvPath}) async {
    try {
      if (monitoringActive) {
        await api.stopMonitoring();
      } else {
        await api.startMonitoring(mode: mode, csvPath: csvPath);
      }
      monitoringActive = !monitoringActive;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ws.dispose();
    super.dispose();
  }
}
