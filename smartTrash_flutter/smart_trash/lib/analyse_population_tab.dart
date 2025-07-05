import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_trash/app_settings.dart';

// --- Data Models for API Responses ---

// Model for the correlation scatter plot data {x, y}
class CorrelationPoint {
  final double x;
  final double y;

  CorrelationPoint({required this.x, required this.y});

  factory CorrelationPoint.fromJson(Map<String, dynamic> json) {
    return CorrelationPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

// --- API Service to Fetch Data ---

class AnalysisApiService {
  final String apiBaseUrl;
  AnalysisApiService(this.apiBaseUrl);

  Future<Map<String, int>> getPopulationByBin() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/population-by-bin'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data.map((key, value) => MapEntry(key, (value as num).toInt()));
    } else {
      throw Exception('Failed to load population data');
    }
  }

  Future<Map<String, Map<String, int>>> getUsageByRegion() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/usage-by-region'));
    if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data.map((region, bins) => MapEntry(
            region,
            (bins as Map<String, dynamic>).map(
                (binId, count) => MapEntry(binId, (count as num).toInt()))));
    } else {
        throw Exception('Failed to load usage by region data');
    }
  }

  Future<List<CorrelationPoint>> getTrashWeightCorrelation() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/trash-weight-correlation'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((point) => CorrelationPoint.fromJson(point)).toList();
    } else {
      throw Exception('Failed to load correlation data');
    }
  }

  Future<Map<String, double>> getFillRateByBin() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/fill-rate-by-bin'));
    if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } else {
        throw Exception('Failed to load fill rate data');
    }
  }
}

// --- Main Widget for the "Analyse de Population" Tab ---

class AnalysePopulationTab extends StatefulWidget {
  const AnalysePopulationTab({super.key});

  @override
  _AnalysePopulationTabState createState() => _AnalysePopulationTabState();
}

class _AnalysePopulationTabState extends State<AnalysePopulationTab> {
  late AnalysisApiService _apiService;
  late Future<Map<String, dynamic>> _dashboardData;

  @override
  void initState() {
    super.initState();
    _dashboardData = _initAndFetchAllData();
  }

  Future<Map<String, dynamic>> _initAndFetchAllData() async {
    final appSettings = AppSettings();
    await appSettings.loadSettings();
    final apiBaseUrl = appSettings.rotageServerUrl ?? "http://10.0.2.2:8000";
    _apiService = AnalysisApiService(apiBaseUrl);
    return _fetchAllData();
  }

  Future<Map<String, dynamic>> _fetchAllData() async {
    final results = await Future.wait([
      _apiService.getPopulationByBin(),
      _apiService.getUsageByRegion(),
      _apiService.getTrashWeightCorrelation(),
      _apiService.getFillRateByBin(),
    ]);

    return {
      'popByBin': results[0],
      'usageByRegion': results[1],
      'correlation': results[2],
      'fillRates': results[3],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A3A), Color(0xFF2C3E50)],
        ),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9b59b6)),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erreur de chargement: ${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF0F8FF)),
              ),
            );
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            final popByBin = data['popByBin'] as Map<String, int>;
            final usageByRegion = data['usageByRegion'] as Map<String, Map<String, int>>;
            final correlation = data['correlation'] as List<CorrelationPoint>;
            final fillRates = data['fillRates'] as Map<String, double>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PopulationByBinCard(data: popByBin),
                  const SizedBox(height: 20),
                  ...usageByRegion.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: UsageByRegionCard(region: entry.key, data: entry.value),
                  )),
                  CorrelationCard(data: correlation),
                  const SizedBox(height: 20),
                  FillRateCard(data: fillRates),
                ],
              ),
            );
          }
          return const Center(
            child: Text(
              "Aucune donnée disponible.",
              style: TextStyle(color: Color(0xFFF0F8FF)),
            ),
          );
        },
      ),
    );
  }
}

// --- Reusable Dashboard Card Widget ---

class DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;

  const DashboardCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9b59b6),
              ),
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }
}

// --- Specific Chart and Table Widgets ---

class PopulationByBinCard extends StatelessWidget {
    final Map<String, int> data;
    const PopulationByBinCard({super.key, required this.data});

    @override
    Widget build(BuildContext context) {
        return DashboardCard(
            title: "1. Utilisateurs par poubelle",
            child: Column(
              children: [
                SizedBox(
                    height: 250,
                    child: BarChart(
                        BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: data.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                            barGroups: data.entries.toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final dataEntry = entry.value;
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: dataEntry.value.toDouble(),
                                      color: const Color(0xFF9b59b6),
                                      width: 20,
                                      borderRadius: BorderRadius.zero,
                                    )
                                  ],
                                );
                            }).toList(),
                            titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 1,
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final keys = data.keys.toList();
                                      if (value.toInt() < keys.length) {
                                        return Text(
                                          keys[value.toInt()],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFF0F8FF),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              drawHorizontalLine: true,
                              horizontalInterval: 1,
                            ),
                            backgroundColor: Colors.transparent,
                        ),
                    ),
                ),
                const SizedBox(height: 20),
                _buildStyledTable(["ID Poubelle", "Nombre d'utilisateurs"], data),
              ],
            ),
        );
    }
}

class UsageByRegionCard extends StatelessWidget {
  final String region;
  final Map<String, int> data;
  const UsageByRegionCard({super.key, required this.region, required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: "2. Utilisation - $region",
      child: _buildStyledTable(["ID Poubelle", "Nombre d'utilisations"], data),
    );
  }
}

class CorrelationCard extends StatelessWidget {
    final List<CorrelationPoint> data;
    const CorrelationCard({super.key, required this.data});

    @override
    Widget build(BuildContext context) {
        return DashboardCard(
            title: "3. Corrélation : Remplissage (%) vs Poids (kg)",
            child: SizedBox(
                height: 300,
                child: ScatterChart(
                    ScatterChartData(
                        scatterSpots: data.map((point) => ScatterSpot(
                          point.x,
                          point.y,
                          dotPainter: FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF9b59b6),
                          ),
                        )).toList(),
                        titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                              ),
                              axisNameWidget: Text(
                                "Poids (kg)",
                                style: TextStyle(color: Color(0xFFF0F8FF)),
                              ),
                            ),
                            bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                              ),
                              axisNameWidget: Text(
                                "Niveau de remplissage (%)",
                                style: TextStyle(color: Color(0xFFF0F8FF)),
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          drawHorizontalLine: true,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Colors.white10,
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return const FlLine(
                              color: Colors.white10,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        backgroundColor: Colors.transparent,
                    ),
                ),
            ),
        );
    }
}

class FillRateCard extends StatelessWidget {
    final Map<String, double> data;
    const FillRateCard({super.key, required this.data});
    
    @override
    Widget build(BuildContext context) {
        return DashboardCard(
            title: "4. Vitesse de remplissage (%/heure)",
            child: Column(
              children: [
                SizedBox(
                    height: 250,
                    child: BarChart(
                         BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: data.values.reduce((a, b) => a > b ? a : b) * 1.2,
                            barGroups: data.entries.toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final dataEntry = entry.value;
                                return BarChartGroupData(
                                  x: index,
                                  barRods: [
                                    BarChartRodData(
                                      toY: dataEntry.value,
                                      color: const Color(0xFF00BCD4),
                                      width: 20,
                                      borderRadius: BorderRadius.zero,
                                    )
                                  ],
                                );
                            }).toList(),
                             titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                  ),
                                  axisNameWidget: Text(
                                    "Pourcentage par heure",
                                    style: TextStyle(color: Color(0xFFF0F8FF)),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final keys = data.keys.toList();
                                      if (value.toInt() < keys.length) {
                                        return Text(
                                          keys[value.toInt()],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFF0F8FF),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              drawHorizontalLine: true,
                            ),
                            backgroundColor: Colors.transparent,
                        ),
                    ),
                ),
                const SizedBox(height: 20),
                _buildStyledTable(
                  ["ID Poubelle", "Vitesse Moyenne (%/heure)"],
                  data.map((key, value) => MapEntry(key, value.toStringAsFixed(2))),
                ),
              ],
            ),
        );
    }
}

// Helper function to create styled data tables matching the HTML design
Widget _buildStyledTable<T>(List<String> headers, Map<String, T> data) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF9b59b6).withOpacity(0.4)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        border: TableBorder.all(
          color: const Color(0xFF9b59b6).withOpacity(0.4),
          width: 1,
        ),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
        },
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              color: const Color(0xFF9b59b6).withOpacity(0.4),
            ),
            children: headers.map((header) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                header,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF0F8FF),
                  fontSize: 14,
                ),
              ),
            )).toList(),
          ),
          // Data rows
          ...data.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final dataEntry = entry.value;
            return TableRow(
              decoration: BoxDecoration(
                color: index % 2 == 1 
                  ? Colors.white.withOpacity(0.05)
                  : Colors.transparent,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    dataEntry.key,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF0F8FF),
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    dataEntry.value.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF0F8FF),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    ),
  );
}