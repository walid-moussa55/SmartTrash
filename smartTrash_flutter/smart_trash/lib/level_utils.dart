// lib/level_utils.dart
import 'package:flutter/material.dart';

/// Shared color utility for trash level indicators.
/// Used across home_screen, map_screen, prediction_screen, route_map_screen.
Color getLevelColor(double level) {
  if (level <= 25) return Colors.green;
  if (level <= 50) return Colors.yellow.shade700;
  if (level <= 75) return Colors.orange;
  return Colors.red;
}

/// Returns a human-readable status string for a given trash level.
String getTrashStatus(double level) {
  if (level < 50) return "Okay";
  if (level < 85) return "Getting Full";
  return "Needs Emptying Soon";
}
