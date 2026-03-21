// prediction_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'bin_prediction.dart';
import 'app_settings.dart';
import 'package:naqi_ai/level_utils.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> with SingleTickerProviderStateMixin {
  Map<String, BinPrediction> _predictions = {};
  List<WeeklyDayPrediction> _weeklyData = [];
  int _selectedDayIndex = 0;
  bool _isLoading = true;
  bool _isWeeklyLoading = true;
  String? _error;
  String? _weeklyError;
  final AppSettings _appSettings = AppSettings();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPredictions();
    _fetchWeeklyPredictions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPredictions() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final serverUrl = _appSettings.rotageServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) throw Exception('Server URL not configured');

      final levelResponse = await http.get(Uri.parse('$serverUrl/prediction'));
      if (levelResponse.statusCode != 200) throw Exception('Failed to load predictions: ${levelResponse.statusCode}');

      final levelData = json.decode(levelResponse.body) as Map<String, dynamic>;
      final predictions = <String, BinPrediction>{};
      levelData.forEach((binId, predictionData) {
        predictions[binId] = BinPrediction.fromMap(predictionData as Map<String, dynamic>);
      });

      if (!mounted) return;
      setState(() { _predictions = predictions; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _fetchWeeklyPredictions() async {
    try {
      setState(() { _isWeeklyLoading = true; _weeklyError = null; });
      final serverUrl = _appSettings.rotageServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) throw Exception('Server URL not configured');

      final response = await http.get(Uri.parse('$serverUrl/prediction/weekly'));
      if (response.statusCode != 200) throw Exception('Failed to load weekly predictions: ${response.statusCode}');

      final data = json.decode(response.body) as Map<String, dynamic>;
      final dayOrder = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
      final weekly = <WeeklyDayPrediction>[];
      for (final dayName in dayOrder) {
        if (data.containsKey(dayName)) {
          weekly.add(WeeklyDayPrediction.fromEntry(dayName, data[dayName] as Map<String, dynamic>));
        }
      }

      if (!mounted) return;
      setState(() { _weeklyData = weekly; _isWeeklyLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _weeklyError = e.toString(); _isWeeklyLoading = false; });
    }
  }

  // ─── Current predictions tab ───

  Widget _buildPredictionCard(String binId, BinPrediction prediction) {
    final currentColor = getLevelColor(prediction.currentLevel);
    // Enforce: predicted level can never be below current level (no spontaneous emptying)
    final safePredicted = prediction.predictedLevel < prediction.currentLevel
        ? prediction.currentLevel
        : prediction.predictedLevel;
    final predictedColor = getLevelColor(safePredicted);
    final trend = safePredicted > prediction.currentLevel;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(prediction.binName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Icon(trend ? Icons.trending_up : Icons.trending_down, color: trend ? Colors.red : Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            _buildLevelIndicator('Current Level', prediction.currentLevel, currentColor),
            const SizedBox(height: 8),
            _buildLevelIndicator('Predicted Level', safePredicted, predictedColor),
            const SizedBox(height: 8),
            Text('Updated: ${_formatDateTime(prediction.timestamp)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelIndicator(String label, double level, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: level / 100, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 10),
        const SizedBox(height: 4),
        Text('${level.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCurrentPredictionsTab() {
    final theme = Theme.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchPredictions, child: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _fetchPredictions,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _predictions.entries.map((e) => _buildPredictionCard(e.key, e.value)).toList(),
      ),
    );
  }

  // ─── Weekly planner tab ───

  Widget _buildWeeklyPlannerTab() {
    final theme = Theme.of(context);
    if (_isWeeklyLoading) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    if (_weeklyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Error: $_weeklyError', style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchWeeklyPredictions, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_weeklyData.isEmpty) return const Center(child: Text('No weekly data available.'));

    final selectedDay = _weeklyData[_selectedDayIndex];
    final res = selectedDay.resources;
    final dayAbbr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return RefreshIndicator(
      onRefresh: _fetchWeeklyPredictions,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ─── Day selector row ───
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weeklyData.length,
              itemBuilder: (context, i) {
                final day = _weeklyData[i];
                final isSelected = i == _selectedDayIndex;
                final isToday = i == 0;
                final hasFullBins = day.resources.fullBins > 0;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  child: Container(
                    width: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : (hasFullBins ? const Color(0xFFfff3e0) : theme.colorScheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(14),
                      border: isToday && !isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                      boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayAbbr[i % 7], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : theme.textTheme.bodySmall?.color)),
                        const SizedBox(height: 4),
                        Text(day.date.substring(8), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color)),
                        if (hasFullBins) Icon(Icons.warning_amber_rounded, size: 14, color: isSelected ? Colors.white : Colors.orange),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ─── Resource summary cards ───
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  Text('${selectedDay.dayName} – ${selectedDay.date}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildResourceTile(Icons.delete, '${res.fullBins}', 'Pleines\n(≥80%)', const Color(0xFFe74c3c)),
                      _buildResourceTile(Icons.local_shipping, '${res.trucksNeeded}', 'Camions', const Color(0xFF3498db)),
                      _buildResourceTile(Icons.people, '${res.workersNeeded}', 'Employés', const Color(0xFF2ecc71)),
                      _buildResourceTile(Icons.local_gas_station, '${res.fuelLiters}L', 'Gasoil', const Color(0xFFf39c12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Bin predictions for selected day ───
          Text('Prédictions par poubelle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 8),
          ...selectedDay.bins.map((bin) {
            final color = getLevelColor(bin.predictedLevel);
            final isFull = bin.predictedLevel >= 80;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.delete_outline, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bin.binName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: bin.predictedLevel / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Text('${bin.predictedLevel.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                        if (isFull) const Text('⚠ PLEINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFe74c3c))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResourceTile(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Predictions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchPredictions();
              _fetchWeeklyPredictions();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Prédictions'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Planification'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentPredictionsTab(),
          _buildWeeklyPlannerTab(),
        ],
      ),
    );
  }
}