// bin_prediction.dart

class BinPrediction {
  final String binName;
  final double currentLevel;
  final double predictedLevel;
  final DateTime timestamp;
  final List<double> avgTemp;
  final List<double> avgRhum;
  final List<double> minTemp;
  final List<double> maxTemp;

  BinPrediction({
    required this.binName,
    required this.currentLevel,
    required this.predictedLevel,
    required this.timestamp,
    this.avgTemp = const [],
    this.avgRhum = const [],
    this.minTemp = const [],
    this.maxTemp = const [],
  });

  factory BinPrediction.fromMap(Map<String, dynamic> map) {
    return BinPrediction(
      binName: map['bin_name'] ?? 'Unknown Bin',
      currentLevel: (map['current_level'] as num?)?.toDouble() ?? 0.0,
      predictedLevel: (map['predicted_level'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      avgTemp: (map['avg_temp'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      avgRhum: (map['avg_rhum'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      minTemp: (map['min_temp'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      maxTemp: (map['max_temp'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }

  BinPrediction copyWith({
    String? binName,
    double? currentLevel,
    double? predictedLevel,
    DateTime? timestamp,
    List<double>? avgTemp,
    List<double>? avgRhum,
    List<double>? minTemp,
    List<double>? maxTemp,
  }) {
    return BinPrediction(
      binName: binName ?? this.binName,
      currentLevel: currentLevel ?? this.currentLevel,
      predictedLevel: predictedLevel ?? this.predictedLevel,
      timestamp: timestamp ?? this.timestamp,
      avgTemp: avgTemp ?? this.avgTemp,
      avgRhum: avgRhum ?? this.avgRhum,
      minTemp: minTemp ?? this.minTemp,
      maxTemp: maxTemp ?? this.maxTemp,
    );
  }
}