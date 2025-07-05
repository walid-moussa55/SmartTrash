// prediction_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'bin_prediction.dart';
import 'app_settings.dart';
import 'package:intl/intl.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({Key? key}) : super(key: key);

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  Map<String, BinPrediction> _predictions = {};
  bool _isLoading = true;
  String? _error;
  final AppSettings _appSettings = AppSettings();

  @override
  void initState() {
    super.initState();
    _fetchPredictions();
  }

  Future<void> _fetchPredictions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final serverUrl = _appSettings.rotageServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) {
        throw Exception('Server URL not configured');
      }

      // Fetch both predictions in parallel
      final levelResponseFuture = http.get(Uri.parse('$serverUrl/prediction'));
      final htResponseFuture = http.get(Uri.parse('$serverUrl/prediction/ht'));

      final responses = await Future.wait([levelResponseFuture, htResponseFuture]);

      final levelResponse = responses[0];
      final htResponse = responses[1];

      if (levelResponse.statusCode != 200) {
        throw Exception('Failed to load trash level predictions: ${levelResponse.statusCode}');
      }
      if (htResponse.statusCode != 200) {
        throw Exception('Failed to load temperature/humidity predictions: ${htResponse.statusCode}');
      }
      
      final levelData = json.decode(levelResponse.body) as Map<String, dynamic>;
      final htData = json.decode(htResponse.body) as Map<String, dynamic>;
      
      final predictions = <String, BinPrediction>{};
      
      levelData.forEach((binId, predictionData) {
        predictions[binId] = BinPrediction.fromMap(
          predictionData as Map<String, dynamic>
        );
      });

      htData.forEach((binId, htPredictionData) {
        if (predictions.containsKey(binId)) {
          final existingPrediction = predictions[binId]!;
          predictions[binId] = existingPrediction.copyWith(
            avgTemp: (htPredictionData['avg_temp'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
            avgRhum: (htPredictionData['avg_rhum'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
            minTemp: (htPredictionData['min_temp'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
            maxTemp: (htPredictionData['max_temp'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
          );
        }
      });

      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildPredictionCard(String binId, BinPrediction prediction) {
    final currentColor = _getLevelColor(prediction.currentLevel);
    final predictedColor = _getLevelColor(prediction.predictedLevel);
    final trend = prediction.predictedLevel > prediction.currentLevel;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    prediction.binName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  trend ? Icons.trending_up : Icons.trending_down,
                  color: trend ? Colors.red : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLevelIndicator(
              'Current Level',
              prediction.currentLevel,
              currentColor,
            ),
            const SizedBox(height: 8),
            _buildLevelIndicator(
              'Predicted Level',
              prediction.predictedLevel,
              predictedColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Updated: ${_formatDateTime(prediction.timestamp)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildForecast(prediction),
          ),
        ],
      ),
    );
  }
  
  Widget _buildForecast(BinPrediction prediction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '7-Day Forecast',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDay(i)),
                Row(
                  children: [
                    Icon(Icons.thermostat, color: Colors.orange, size: 16),
                    Text('${prediction.maxTemp[i].toStringAsFixed(1)}°'),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.water_drop, color: Colors.blue, size: 16),
                    Text('${prediction.avgRhum[i].toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDay(int dayIndex) {
    if (dayIndex == 0) return 'Today';
    if (dayIndex == 1) return 'Tomorrow';
    final day = DateTime.now().add(Duration(days: dayIndex));
    return DateFormat('EEE').format(day); // e.g., 'Mon', 'Tue'
  }

  Widget _buildLevelIndicator(String label, double level, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: level / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 10,
        ),
        const SizedBox(height: 4),
        Text(
          '${level.toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _getLevelColor(double level) {
    if (level <= 25) return Colors.green;
    if (level <= 50) return Colors.yellow.shade700;
    if (level <= 75) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash Level Predictions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPredictions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _fetchPredictions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPredictions,
                  child: ListView(
                    children: _predictions.entries
                        .map((e) => _buildPredictionCard(e.key, e.value))
                        .toList(),
                  ),
                ),
    );
  }
}