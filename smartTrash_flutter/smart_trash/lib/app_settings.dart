// lib/app_settings.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'debug_utils.dart';

class AppSettings with ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  final DatabaseReference _settingsRef = FirebaseDatabase.instance.ref().child('app_settings');

  double? _containerVolume;
  double? _containerWeight;
  String? _rotageServerUrl;

  // Keys for Firebase RTDB
  static const String _volumeKey = 'containerVolume';
  static const String _weightKey = 'containerWeight';
  static const String _serverUrlKey = 'rotageServerUrl';

  // Getters
  double? get containerVolume => _containerVolume;
  double? get containerWeight => _containerWeight;
  String? get rotageServerUrl => _rotageServerUrl;

  Future<void> loadSettings() async {
    try {
      DataSnapshot snapshot = await _settingsRef.get();
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        _containerVolume = (data[_volumeKey] as num?)?.toDouble();
        _containerWeight = (data[_weightKey] as num?)?.toDouble();
        _rotageServerUrl = data[_serverUrlKey] as String?;
        DebugLogger.addDebugMessage("App settings loaded from Firebase: Volume: $_containerVolume, Weight: $_containerWeight, URL: $_rotageServerUrl");
      } else {
        DebugLogger.addDebugMessage("No app settings found in Firebase. Using defaults (null).");
        // Initialize with defaults or leave as null
        _containerVolume = null;
        _containerWeight = null;
        _rotageServerUrl = null;
      }
    } catch (e) {
      DebugLogger.addDebugMessage("Error loading app settings from Firebase: $e. Using defaults (null).");
      _containerVolume = null;
      _containerWeight = null;
      _rotageServerUrl = null;
    }
    notifyListeners();
  }

  Future<void> saveContainerVolume(double? volume) async {
    try {
      await _settingsRef.update({_volumeKey: volume});
      _containerVolume = volume;
      notifyListeners();
      DebugLogger.addDebugMessage("Saved Container Volume to Firebase: $_containerVolume");
    } catch (e) {
      DebugLogger.addDebugMessage("Error saving Container Volume to Firebase: $e");
      // Optionally re-throw or handle
    }
  }

  Future<void> saveContainerWeight(double? weight) async {
    try {
      await _settingsRef.update({_weightKey: weight});
      _containerWeight = weight;
      notifyListeners();
      DebugLogger.addDebugMessage("Saved Container Weight to Firebase: $_containerWeight");
    } catch (e) {
      DebugLogger.addDebugMessage("Error saving Container Weight to Firebase: $e");
    }
  }

  Future<void> saveRotageServerUrl(String? url) async {
    try {
      await _settingsRef.update({_serverUrlKey: (url != null && url.isNotEmpty) ? url : null});
      _rotageServerUrl = (url != null && url.isNotEmpty) ? url : null;
      notifyListeners();
      DebugLogger.addDebugMessage("Saved Rotage Server URL to Firebase: $_rotageServerUrl");
    } catch (e) {
      DebugLogger.addDebugMessage("Error saving Rotage Server URL to Firebase: $e");
    }
  }
}