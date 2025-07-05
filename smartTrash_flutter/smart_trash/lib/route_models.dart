// lib/route_models.dart
import 'package:smart_trash/home_screen.dart' show Location; // Reuse Location

class ApiContainer {
  final String name;
  final Location location;
  final double volume; // Max volume capacity of the worker's container
  final double weight; // Max weight capacity of the worker's container

  ApiContainer({
    required this.name,
    required this.location,
    required this.volume,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': {'latitude': location.latitude, 'longitude': location.longitude},
    'volume': volume,
    'weight': weight,
  };
}

class ApiBin {
  final String name;
  final Location location;
  final double capacity; // Percentage full (0-100)
  final double volume;   // Physical volume of the bin
  final double weight;   // Current weight of trash in the bin

  ApiBin({
    required this.name,
    required this.location,
    required this.capacity,
    required this.volume,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': {'latitude': location.latitude, 'longitude': location.longitude},
    'capacity': capacity,
    'volume': volume,
    'weight': weight,
  };
}

class RouteOptimizationRequest {
  final ApiContainer container;
  final List<ApiBin> bins;

  RouteOptimizationRequest({required this.container, required this.bins});

  Map<String, dynamic> toJson() => {
    'container': container.toJson(),
    'bins': bins.map((bin) => bin.toJson()).toList(),
  };
}

// For the response
class OrderedBin {
  final String name;
  final Location location;
  final double capacity;
  final double volume;
  final double weight;
  final int? order; // Optional: if you want to explicitly store the order
  double? distance; // Optional: distance from worker's location, if provided

  OrderedBin({
    required this.name,
    required this.location,
    required this.capacity,
    required this.volume,
    required this.weight,
    this.order,
    this.distance,
  });

  factory OrderedBin.fromJson(Map<String, dynamic> json, {int? order}) {
    return OrderedBin(
      name: json['name'],
      location: Location.fromMap(json['location']),
      capacity: (json['capacity'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      order: order,
      distance: json.containsKey('distance') ? (json['distance'] as num).toDouble() : null,
    );
  }
}

class OptimizedRouteResponse {
  final List<OrderedBin> orderedBins;
  final double totalVolume;
  final double totalWeight;

  OptimizedRouteResponse({
    required this.orderedBins,
    required this.totalVolume,
    required this.totalWeight,
  });

  factory OptimizedRouteResponse.fromJson(Map<String, dynamic> json) {
    var binList = json['ordered_bins'] as List;
    List<OrderedBin> bins = [];
    for(int i=0; i < binList.length; i++) {
      bins.add(OrderedBin.fromJson(binList[i], order: i + 1));
    }
    // List<OrderedBin> bins = binList.map((i) => OrderedBin.fromJson(i)).toList();
    return OptimizedRouteResponse(
      orderedBins: bins,
      totalVolume: (json['total_volume'] as num).toDouble(),
      totalWeight: (json['total_weight'] as num).toDouble(),
    );
  }
}