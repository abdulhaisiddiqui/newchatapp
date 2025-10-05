import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  online,
  offline,
  unknown;

  String get displayName {
    switch (this) {
      case ConnectionStatus.online:
        return 'Online';
      case ConnectionStatus.offline:
        return 'Offline';
      case ConnectionStatus.unknown:
        return 'Checking...';
    }
  }

  bool get isOnline => this == ConnectionStatus.online;
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _currentStatus = ConnectionStatus.unknown;

  ConnectionStatus get currentStatus => _currentStatus;
  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Failed to get connectivity: $e');
      _updateConnectionStatus([]);
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn,
    );

    final newStatus = hasConnection
        ? ConnectionStatus.online
        : ConnectionStatus.offline;

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _connectionStatusController.add(_currentStatus);
      debugPrint('Connection status changed: ${_currentStatus.displayName}');
    }
  }

  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any(
        (r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
