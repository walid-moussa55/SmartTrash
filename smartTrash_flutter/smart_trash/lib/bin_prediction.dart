// bin_prediction.dart

class BinPrediction {
  final String binName;
  final double currentLevel;
  final double predictedLevel;
  final DateTime timestamp;

  BinPrediction({
    required this.binName,
    required this.currentLevel,
    required this.predictedLevel,
    required this.timestamp,
  });

  factory BinPrediction.fromMap(Map<String, dynamic> map) {
    return BinPrediction(
      binName: map['bin_name'] ?? 'Unknown Bin',
      currentLevel: (map['current_level'] as num?)?.toDouble() ?? 0.0,
      predictedLevel: (map['predicted_level'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }
}

class DayBinPrediction {
  final String binId;
  final String binName;
  final double predictedLevel;

  DayBinPrediction({required this.binId, required this.binName, required this.predictedLevel});

  factory DayBinPrediction.fromMap(Map<String, dynamic> map) {
    return DayBinPrediction(
      binId: map['bin_id'] ?? '',
      binName: map['bin_name'] ?? 'Unknown',
      predictedLevel: (map['predicted_level'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DayResources {
  final int fullBins;
  final int trucksNeeded;
  final int workersNeeded;
  final int fuelLiters;

  DayResources({required this.fullBins, required this.trucksNeeded, required this.workersNeeded, required this.fuelLiters});

  factory DayResources.fromMap(Map<String, dynamic> map) {
    return DayResources(
      fullBins: (map['full_bins'] as num?)?.toInt() ?? 0,
      trucksNeeded: (map['trucks_needed'] as num?)?.toInt() ?? 0,
      workersNeeded: (map['workers_needed'] as num?)?.toInt() ?? 0,
      fuelLiters: (map['fuel_liters'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeeklyDayPrediction {
  final String dayName;
  final String date;
  final List<DayBinPrediction> bins;
  final DayResources resources;

  WeeklyDayPrediction({required this.dayName, required this.date, required this.bins, required this.resources});

  factory WeeklyDayPrediction.fromEntry(String dayName, Map<String, dynamic> map) {
    final binsList = (map['bins'] as List<dynamic>?)
        ?.map((b) => DayBinPrediction.fromMap(b as Map<String, dynamic>))
        .toList() ?? [];
    return WeeklyDayPrediction(
      dayName: dayName,
      date: map['date'] ?? '',
      bins: binsList,
      resources: DayResources.fromMap(map['resources'] as Map<String, dynamic>? ?? {}),
    );
  }
}