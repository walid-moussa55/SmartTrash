import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
// Assuming Location and TrashBin models are accessible from home_screen.dart
import 'package:smart_trash/home_screen.dart' show Location, TrashBin;
import 'package:smart_trash/debug_utils.dart'; // For logging

/// A service class to handle fetching user location and searching for trash bins.
class BinSearchService {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('trash_bins');

  /// Fetches the user's current location.
  /// Throws an exception if permissions are denied or location cannot be obtained.
  Future<Location> getUserCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        // timeout: const Duration(seconds: 10), // Added timeout
      );
      DebugLogger.addDebugMessage("User location obtained: ${position.latitude}, ${position.longitude}");
      return Location(latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      DebugLogger.addDebugMessage("Error getting user location: $e");
      throw Exception('Failed to get user location: $e');
    }
  }

  /// Fetches all trash bins from Firebase Realtime Database.
  Future<List<TrashBin>> fetchAllTrashBins() async {
    try {
      DataSnapshot snapshot = await _databaseRef.get();
      List<TrashBin> bins = [];
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            try {
              bins.add(TrashBin.fromMap(key.toString(), value));
            } catch (e) {
              DebugLogger.addDebugMessage("Error parsing bin data for $key: $e");
              print("Error parsing bin data: $e for bin $key");
            }
          }
        });
      }
      DebugLogger.addDebugMessage("Fetched ${bins.length} trash bins from Firebase.");
      return bins;
    } catch (e) {
      DebugLogger.addDebugMessage("Error fetching trash bins from Firebase: $e");
      throw Exception('Failed to fetch trash bins: $e');
    }
  }

  /// Finds and returns a list of trash bins matching a specific type,
  /// sorted by proximity to the user's current location.
  /// Returns an empty list if no bins are found or if location/data fails.
  Future<List<TrashBin>> findNearestBinsOfType(String targetTrashType) async {
    try {
      Location userLocation = await getUserCurrentLocation();
      List<TrashBin> allBins = await fetchAllTrashBins();

      // Filter bins by type (case-insensitive) and validate location
      List<TrashBin> filteredBins = allBins
          .where((bin) =>
              bin.trashType.toLowerCase() == targetTrashType.toLowerCase() &&
              (bin.location.latitude != 0.0 || bin.location.longitude != 0.0))
          .toList();

      if (filteredBins.isEmpty) {
        DebugLogger.addDebugMessage("No bins found for type '$targetTrashType'.");
        return [];
      }

      // Calculate distances and sort (closest first)
      filteredBins.sort((a, b) {
        double distA = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          a.location.latitude,
          a.location.longitude,
        );
        double distB = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          b.location.latitude,
          b.location.longitude,
        );
        return distA.compareTo(distB);
      });

      DebugLogger.addDebugMessage("Found ${filteredBins.length} bins for type '$targetTrashType' near user.");
      return filteredBins;
    } catch (e) {
      DebugLogger.addDebugMessage("Error in BinSearchService.findNearestBinsOfType: $e");
      rethrow; // Re-throw the specific exception
    }
  }
}
