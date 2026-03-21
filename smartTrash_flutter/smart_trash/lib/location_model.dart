// lib/location_model.dart

class Location {
  final double latitude;
  final double longitude;

  const Location({required this.latitude, required this.longitude});

  factory Location.fromMap(Map<dynamic, dynamic> data) {
    return Location(
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}
