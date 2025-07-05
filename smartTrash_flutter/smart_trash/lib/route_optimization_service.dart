// lib/route_optimization_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:smart_trash/app_settings.dart';
import 'package:smart_trash/home_screen.dart' show TrashBin, Location; // For TrashBin, Location
import 'package:smart_trash/route_models.dart';
import 'package:smart_trash/debug_utils.dart';

class RouteOptimizationService {
  final AppSettings _appSettings = AppSettings();

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      DebugLogger.addDebugMessage('Location services are disabled.');
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        DebugLogger.addDebugMessage('Location permissions are denied.');
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      DebugLogger.addDebugMessage('Location permissions are permanently denied.');
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
    DebugLogger.addDebugMessage('Fetching current location...');
    return await Geolocator.getCurrentPosition();
  }

  Future<OptimizedRouteResponse?> getOptimizedRoute({
    required List<TrashBin> allBins,
  }) async {
    await _appSettings.loadSettings(); // Ensure latest settings are loaded

    final String? serverUrl = _appSettings.rotageServerUrl;
    final double? containerMaxVolume = _appSettings.containerVolume;
    final double? containerMaxWeight = _appSettings.containerWeight;

    if (serverUrl == null || serverUrl.isEmpty) {
      DebugLogger.addDebugMessage("Error: Rotage Server URL is not set in AppSettings.");
      throw Exception("Rotage Server URL is not configured.");
    }
    if (containerMaxVolume == null || containerMaxWeight == null) {
      DebugLogger.addDebugMessage("Error: Container volume or weight is not set in AppSettings.");
      throw Exception("Container capacity (volume/weight) not configured.");
    }

    final String apiUrl = serverUrl.endsWith('/') ? '${serverUrl}optimize' : '$serverUrl/optimize';
    DebugLogger.addDebugMessage("API URL for optimization: $apiUrl");

    try {
      Position currentPosition = await _getCurrentLocation();
      Location workerLocation = Location(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
      );
      DebugLogger.addDebugMessage("Worker current location: Lat: ${workerLocation.latitude}, Lon: ${workerLocation.longitude}");


      ApiContainer container = ApiContainer(
        name: "worker_container_1", // Or derive from worker ID/profile
        location: workerLocation,
        volume: containerMaxVolume,
        weight: containerMaxWeight,
      );

      List<ApiBin> apiBins = allBins.map((bin) {
        return ApiBin(
          name: bin.name,
          location: bin.location,
          capacity: bin.trashLevel, // This is the fullness percentage
          volume: bin.volume ?? 100.0, // Use bin's volume or default (e.g. 100L)
          weight: bin.weight,
        );
      }).toList();

      // Filter out bins with invalid locations before sending
      apiBins.removeWhere((apiBin) => apiBin.location.latitude == 0.0 && apiBin.location.longitude == 0.0);


      if (apiBins.isEmpty) {
        DebugLogger.addDebugMessage("No valid bins to send for optimization after filtering.");
        throw Exception("No valid bins available for routing.");
      }

      RouteOptimizationRequest requestPayload = RouteOptimizationRequest(
        container: container,
        bins: apiBins,
      );

      String jsonPayload = jsonEncode(requestPayload.toJson());
      DebugLogger.addDebugMessage("Sending payload to optimization API: $jsonPayload");


      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonPayload,
      );

      DebugLogger.addDebugMessage("API Response Status: ${response.statusCode}");
      DebugLogger.addDebugMessage("API Response Body: ${response.body}");


      if (response.statusCode == 200) {
        return OptimizedRouteResponse.fromJson(jsonDecode(response.body));
      } else {
        DebugLogger.addDebugMessage("Error from optimization API: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to get optimized route: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.addDebugMessage("Exception in getOptimizedRoute: $e");
      // Re-throw the exception to be caught by the UI layer
      rethrow;
    }
  }
}