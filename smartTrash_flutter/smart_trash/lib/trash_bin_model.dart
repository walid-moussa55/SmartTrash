// lib/trash_bin_model.dart
import 'location_model.dart';
import 'debug_utils.dart';

class TrashBin {
  final String id;
  final String name;
  final double humidity;
  final double temperature;
  final double trashLevel;
  final double gazLevel;
  final Location location;
  final String trashType;
  final double weight;
  final double? volume;
  final double waterLevel;

  TrashBin({
    required this.id,
    required this.name,
    required this.humidity,
    required this.trashLevel,
    required this.gazLevel,
    required this.location,
    required this.trashType,
    required this.weight,
    this.volume,
    this.temperature = 0.0,
    this.waterLevel = 0.0,
  });

  factory TrashBin.fromMap(String id, Map<dynamic, dynamic> data) {
    const defaultLocation = Location(latitude: 0.0, longitude: 0.0);
    Location parsedLocation = defaultLocation;
    if (data['location'] != null && data['location'] is Map) {
      try {
        parsedLocation = Location.fromMap(data['location']);
      } catch (e) {
        DebugLogger.addDebugMessage("Error parsing location for $id: $e");
      }
    } else {
      DebugLogger.addDebugMessage("Location data missing or invalid for $id.");
    }

    return TrashBin(
      id: id,
      name: data['name']?.toString() ?? 'Trash Bin ${id.split('_').last}',
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      trashLevel: (data['trash_level'] as num?)?.toDouble() ?? 0.0,
      gazLevel: (data['gaz_level'] as num?)?.toDouble() ?? 0.0,
      location: parsedLocation,
      trashType: data['trash_type']?.toString() ?? 'Unknown',
      weight: (data['weight'] as num?)?.toDouble() ?? 0.0,
      volume: (data['volume'] as num?)?.toDouble(),
      waterLevel: (data['water_level'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
