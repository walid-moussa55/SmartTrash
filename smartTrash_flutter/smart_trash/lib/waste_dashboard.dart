import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:async'; // Import for Timer
import 'package:naqi_ai/app_settings.dart'; // Import AppSettings

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── DESIGN SYSTEM CONSTANTS ──
  static const Color _kBg        = Color(0xFFF5F3EE);
  static const Color _kSurface   = Color(0xFFFFFFFF);
  static const Color _kBorder    = Color(0xFFE2DDD5);
  static const Color _kPale      = Color(0xFFDCF0E0);
  static const Color _kLight     = Color(0xFF8EBF93);
  static const Color _kMid       = Color(0xFF5C8E60);
  static const Color _kPrimary   = Color(0xFF2A4A30);
  static const Color _kAlertPale = Color(0xFFF0E8DC);
  static const Color _kAlert     = Color(0xFFB86B2A);
  static const Color _kTextSec   = Color(0xFF7A8A7C);
  static const Color _kTextDark  = Color(0xFF2A4A30);

  List<dynamic> resourceData = [];
  List<dynamic> analyticsData = [];
  bool isLoading = true;
  int currentTabIndex = 0;
  String? _serverUrl;
  String? _errorMessage;
  Timer? _refreshTimer;

  final AppSettings appSettings = AppSettings();

  @override
  void initState() {
    super.initState();
    _loadServerUrlAndFetchData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (Timer t) {
      if (mounted) fetchData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadServerUrlAndFetchData() async {
    await appSettings.loadSettings();
    if (mounted) {
      setState(() {
        _serverUrl = appSettings.rotageServerUrl;
        if (_serverUrl == null || _serverUrl!.isEmpty) {
          _errorMessage = "Server URL is not configured.";
          isLoading = false;
        } else {
          fetchData();
        }
      });
    }
  }

  Future<void> fetchData() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) return;
    setState(() { isLoading = true; _errorMessage = null; });
    
    try {
      final resourceResponse = await http.get(Uri.parse('$_serverUrl/resource-management'));
      final analyticsResponse = await http.get(Uri.parse('$_serverUrl/bin-analytics'));
      
      if (resourceResponse.statusCode == 200 && analyticsResponse.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          resourceData = json.decode(resourceResponse.body);
          analyticsData = json.decode(analyticsResponse.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { isLoading = false; _errorMessage = 'Erreur de connexion'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ANALYTIQUES IA',
          style: TextStyle(color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
      body: _isLoadingContent(),
      floatingActionButton: FloatingActionButton(
        elevation: 4,
        backgroundColor: _kPrimary,
        onPressed: fetchData,
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  Widget _isLoadingContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    } else if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: _kAlert, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: _kTextSec)),
          ],
        ),
      );
    } else if (resourceData.isEmpty && analyticsData.isEmpty) {
      return const Center(child: Text("Aucune donnée disponible", style: TextStyle(color: _kTextSec)));
    } else {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              _buildKPICards(),
              const SizedBox(height: 30),
              _buildTabBar(),
              const SizedBox(height: 25),
              _buildCurrentTabContent(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildKPICards() {
    if (resourceData.isEmpty) return const SizedBox.shrink();

    final fullBins = resourceData.where((bin) => bin['trash_level'] != null && bin['trash_level'] >= 80).length;
    const int binsPerTruck = 25;
    const int workersPerTruck = 3;
    const int fuelPerTruck = 35;
    final trucksNeeded = (fullBins / binsPerTruck).ceil();
    final workersNeeded = trucksNeeded * workersPerTruck;
    final fuelNeeded = trucksNeeded * fuelPerTruck;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildKPICard(
          icon: Icons.auto_delete_rounded,
          title: 'Poubelles Pleines',
          value: '$fullBins',
          caption: '>80% Remplissage',
          color: _kAlert,
          bgColor: _kAlertPale,
        ),
        _buildKPICard(
          icon: Icons.local_shipping_rounded,
          title: 'Logistique Camions',
          value: '$trucksNeeded',
          caption: '$binsPerTruck bins/camion',
          extra: 'Gasoil: ${fuelNeeded}L',
          color: _kMid,
          bgColor: _kPale,
        ),
        _buildKPICard(
          icon: Icons.engineering_rounded,
          title: 'Main d\'œuvre',
          value: '$workersNeeded',
          caption: '$workersPerTruck pers/camion',
          color: _kPrimary,
          bgColor: _kPale,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
    String? extra,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSec)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kTextDark)),
                    const SizedBox(width: 6),
                    if (extra != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(extra, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kAlert)),
                      ),
                  ],
                ),
                Text(caption, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _kTextSec.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      {'icon': Icons.analytics_rounded, 'label': 'Remplissage'},
      {'icon': Icons.thermostat_auto_rounded, 'label': 'Environnement'},
      {'icon': Icons.category_rounded, 'label': 'Déchets'},
      {'icon': Icons.air_rounded, 'label': 'Gaz'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(tabs.length, (index) {
          final isSelected = currentTabIndex == index;
          return GestureDetector(
            onTap: () => setState(() => currentTabIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _kPrimary : _kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? _kPrimary : _kBorder.withOpacity(0.5)),
                boxShadow: isSelected ? [
                  BoxShadow(color: _kPrimary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                ] : [],
              ),
              child: Row(
                children: [
                  Icon(
                    tabs[index]['icon'] as IconData, 
                    size: 18, 
                    color: isSelected ? Colors.white : _kTextSec
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tabs[index]['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _kTextDark,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    if (analyticsData.isEmpty) return const SizedBox.shrink();
    switch (currentTabIndex) {
      case 0: return _buildFillLevelTab();
      case 1: return _buildEnvironmentTab();
      case 2: return _buildTrashTypesTab();
      case 3: return _buildGasAnalysisTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildFillLevelTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Niveaux de Remplissage',
          chart: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: const TextStyle(color: _kTextSec, fontWeight: FontWeight.w600),
            ),
            primaryYAxis: NumericAxis(
              minimum: 0, maximum: 100, axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              labelStyle: const TextStyle(color: _kTextSec),
            ),
            series: <CartesianSeries>[
              ColumnSeries<dynamic, String>(
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['trash_level'],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                gradient: const LinearGradient(
                  colors: [_kMid, _kLight],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kPrimary),
                ),
              ),
            ],
          ),
        ),
        _buildChartCard(
          title: 'État Global du Parc',
          chart: SfCircularChart(
            margin: EdgeInsets.zero,
            legend: const Legend(
              isVisible: true, 
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            series: <CircularSeries>[
              DoughnutSeries<dynamic, String>(
                innerRadius: '65%',
                dataSource: [
                  {'status': 'Pleine', 'count': analyticsData.where((b) => b['trash_level'] != null && b['trash_level'] >= 80).length},
                  {'status': 'Gaz Alerte', 'count': analyticsData.where((b) => b['gaz_level'] != null && b['gaz_level'] >= 10).length},
                  {'status': 'Normal', 'count': analyticsData.length - analyticsData.where((b) => (b['trash_level'] != null && b['trash_level'] >= 80) || (b['gaz_level'] != null && b['gaz_level'] >= 10)).length},
                ],
                xValueMapper: (data, _) => data['status'],
                yValueMapper: (data, _) => data['count'],
                pointColorMapper: (d, _) {
                  if (d['status'] == 'Pleine') return const Color(0xFFD35400); // Orange foncé vibrant
                  if (d['status'] == 'Gaz Alerte') return _kPrimary; // Vert très foncé
                  return _kLight; // Vert clair Naqi
                },
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: _kTextDark, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Température et Humidité',
          chart: SfCartesianChart(
            plotAreaBorderWidth: 0,
            legend: const Legend(isVisible: true, position: LegendPosition.top),
            primaryXAxis: CategoryAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: const TextStyle(color: _kTextSec, fontWeight: FontWeight.w700, fontSize: 11),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Temp (°C)', textStyle: const TextStyle(color: _kAlert, fontWeight: FontWeight.bold, fontSize: 10)),
              axisLine: const AxisLine(width: 0),
              labelStyle: const TextStyle(color: _kAlert, fontWeight: FontWeight.w600),
            ),
            axes: [
              NumericAxis(
                name: 'H', 
                opposedPosition: true, 
                title: AxisTitle(text: 'Hum (%)', textStyle: const TextStyle(color: _kMid, fontWeight: FontWeight.bold, fontSize: 10)), 
                labelStyle: const TextStyle(color: _kMid, fontWeight: FontWeight.w600), 
                minimum: 0, 
                maximum: 100
              ),
            ],
            series: <CartesianSeries>[
              SplineSeries<dynamic, String>(
                dataSource: analyticsData, 
                xValueMapper: (d, _) => d['name'], 
                yValueMapper: (d, _) => d['temperature'], 
                name: 'Temp', 
                color: _kAlert, 
                width: 4,
                markerSettings: const MarkerSettings(isVisible: true, borderWidth: 2, borderColor: Colors.white),
                dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _kAlert)),
              ),
              SplineSeries<dynamic, String>(
                dataSource: analyticsData, 
                xValueMapper: (d, _) => d['name'], 
                yValueMapper: (d, _) => d['humidity'], 
                name: 'Hum', 
                yAxisName: 'H', 
                color: _kMid, 
                width: 4,
                markerSettings: const MarkerSettings(isVisible: true, borderWidth: 2, borderColor: Colors.white),
                dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _kMid)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrashTypesTab() {
    final types = _countTrashTypes();
    return Column(
      children: [
        _buildChartCard(
          title: 'Répartition par Type',
          chart: SfCircularChart(
            legend: const Legend(
              isVisible: true, 
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: _kTextDark, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            series: <CircularSeries>[
              PieSeries<Map<String, dynamic>, String>(
                dataSource: types,
                xValueMapper: (d, _) => d['type'],
                yValueMapper: (d, _) => d['count'],
                explode: true,
                explodeOffset: '10%',
                pointColorMapper: (d, i) {
                  // Palette plus contrastée et variée
                  final colors = [
                    _kPrimary, 
                    const Color(0xFFD35400), // Orange
                    const Color(0xFF2E86C1), // Bleu pro
                    _kMid, 
                    const Color(0xFF8E44AD), // Violet
                    const Color(0xFFF1C40F), // Jaune
                  ];
                  return colors[i % colors.length];
                },
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: _kTextDark, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGasAnalysisTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Niveaux de Gaz (MQ-135)',
          chart: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(majorGridLines: const MajorGridLines(width: 0)),
            series: <CartesianSeries>[
              AreaSeries<dynamic, String>(
                dataSource: analyticsData,
                xValueMapper: (d, _) => d['name'],
                yValueMapper: (d, _) => d['gaz_level'],
                color: _kAlert.withOpacity(0.2),
                borderColor: _kAlert,
                borderWidth: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _kBorder.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 13, color: _kPrimary, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 20),
          SizedBox(height: 280, child: chart),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _countTrashTypes() {
    final typeCounts = <String, int>{};
    for (final bin in analyticsData) {
      final type = bin['trash_type'] ?? 'mixed';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    return typeCounts.entries.map((e) => {'type': e.key, 'count': e.value}).toList();
  }

  List<Map<String, dynamic>> _calculateAverageWeightByType() {
    final typeWeights = <String, List<num>>{};
    for (final bin in analyticsData) {
      final type = bin['trash_type'] ?? 'mixed';
      if (!typeWeights.containsKey(type)) {
        typeWeights[type] = [];
      }
      final weight = bin['weight'];
      if (weight != null) {
        typeWeights[type]?.add(weight is num ? weight : num.tryParse(weight.toString()) ?? 0);
      }
    }
    return typeWeights.entries.map((e) => {
      'type': e.key,
      'avgWeight': e.value.isNotEmpty
          ? (e.value.reduce((a, b) => a + b) / e.value.length)
          : 0
    }).toList();
  }

  List<Map<String, dynamic>> _calculateAverageVolumeByType() {
    final typeVolumes = <String, List<num>>{};
    for (final bin in analyticsData) {
      final type = bin['trash_type'] ?? 'mixed';
      if (!typeVolumes.containsKey(type)) {
        typeVolumes[type] = [];
      }
      final volume = bin['volume'];
      if (volume != null) {
        typeVolumes[type]?.add(volume is num ? volume : num.tryParse(volume.toString()) ?? 0);
      }
    }
    return typeVolumes.entries.map((e) => {
      'type': e.key,
      'avgVolume': e.value.isNotEmpty
          ? (e.value.reduce((a, b) => a + b) / e.value.length)
          : 0
    }).toList();
  }

  List<ScatterSeries<dynamic, num>> _buildTrashTypeLocationSeries() {
    final types = _countTrashTypes().map((e) => e['type'] as String).toList();
    final colors = [
      const Color(0xFF9b59b6),
      const Color(0xFF3498db),
      const Color(0xFF2ecc71),
      const Color(0xFFf39c12),
      const Color(0xFFe74c3c),
      const Color(0xFF1abc9c),
    ];

    return List.generate(types.length, (index) {
      final type = types[index];
      return ScatterSeries<dynamic, num>(
        name: type,
        dataSource: analyticsData.where((bin) => (bin['trash_type'] ?? 'mixed') == type).toList(),
        xValueMapper: (data, _) => data['location']?['longitude'] ?? 0,
        yValueMapper: (data, _) => data['location']?['latitude'] ?? 0,
        color: colors[index % colors.length],
        markerSettings: const MarkerSettings(isVisible: true, height: 8, width: 8),
        dataLabelMapper: (data, _) => data['name'],
        dataLabelSettings: const DataLabelSettings(isVisible: false),
      );
    });
  }
}
