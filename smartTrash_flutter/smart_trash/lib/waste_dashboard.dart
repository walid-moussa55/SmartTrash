import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Import for Timer
import 'package:smart_trash/app_settings.dart'; // Import AppSettings
import 'analyse_population_tab.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> resourceData = [];
  List<dynamic> analyticsData = [];
  bool isLoading = true;
  int currentTabIndex = 0;
  String? _serverUrl; // To store the server URL from AppSettings
  String? _errorMessage; // To store error messages
  Timer? _refreshTimer; // Timer for periodic refresh

  final AppSettings appSettings = AppSettings(); // Instance of AppSettings to access server URL

  @override
  void initState() {
    super.initState();
    _loadServerUrlAndFetchData();
    // Set up a periodic timer for refreshing data
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (Timer t) {
      if (mounted) { // Only fetch if the widget is still in the tree
        fetchData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _loadServerUrlAndFetchData() async {
    await appSettings.loadSettings(); // Ensure settings are loaded
    if (mounted) {
      setState(() {
        _serverUrl = appSettings.rotageServerUrl;
        if (_serverUrl == null || _serverUrl!.isEmpty) {
          _errorMessage = "Server URL is not configured in app settings.";
          // Do not proceed with fetch if URL is missing
          isLoading = false;
        } else {
          fetchData(); // Fetch data only if URL is available
        }
      });
    }
  }


  Future<void> fetchData() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      setState(() {
        isLoading = false;
        _errorMessage = "Server URL is missing. Cannot fetch data.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null; // Clear previous errors
    });
    
    try {
      final resourceResponse = await http.get(Uri.parse('$_serverUrl/resource-management'));
      final analyticsResponse = await http.get(Uri.parse('$_serverUrl/bin-analytics'));
      
      if (resourceResponse.statusCode == 200 && analyticsResponse.statusCode == 200) {
        setState(() {
          resourceData = json.decode(resourceResponse.body);
          analyticsData = json.decode(analyticsResponse.body);
          isLoading = false;
        });
      } else {
        String errorDetail = 'Failed to load data. ';
        if (resourceResponse.statusCode != 200) {
          errorDetail += 'Resource Management Error: ${resourceResponse.statusCode} ${resourceResponse.reasonPhrase}';
        }
        if (analyticsResponse.statusCode != 200) {
          if (resourceResponse.statusCode == 200) errorDetail += 'Bin Analytics Error: ';
          errorDetail += '${analyticsResponse.statusCode} ${analyticsResponse.reasonPhrase}';
        }
        throw Exception(errorDetail);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        _errorMessage = 'Erreur: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181818), // Dark background
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.recycling, color: Color(0xFF9b59b6)),
            SizedBox(width: 10),
            Text(
              'Gestion Dynamique des Ressources de Collecte',
              style: TextStyle(color: Colors.white), // Set text color here
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoadingContent(), // Use a helper for content based on loading/error
      floatingActionButton: FloatingActionButton(
        onPressed: fetchData,
        backgroundColor: const Color(0xFF9b59b6),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _isLoadingContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF9b59b6)));
    } else if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (resourceData.isEmpty && analyticsData.isEmpty) {
      return const Center(
        child: Text(
          "No data available. Check server connection or generate data.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildKPICards(),
              const SizedBox(height: 20),
              _buildTabBar(),
              const SizedBox(height: 20),
              _buildCurrentTabContent(),
            ],
          ),
        ),
      );
    }
  }


  Widget _buildKPICards() {
    // Ensure data is not empty before accessing
    if (resourceData.isEmpty) {
      return const SizedBox.shrink(); // Or a placeholder
    }
    final fullBins = resourceData.where((bin) => bin['trash_level'] != null && bin['trash_level'] >= 80).length;
    final trucksNeeded = (fullBins / 3).ceil();
    final workersNeeded = trucksNeeded * 2;
    final fuelNeeded = trucksNeeded * 50; // Example calculation

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
      _buildKPICard(
        icon: Icons.delete,
        title: 'Poubelles pleines (>80%)',
        value: fullBins.toString(),
        color: const Color(0xFFe74c3c),
      ),
      _buildKPICard(
        icon: Icons.local_shipping,
        title: 'Camions nécessaires',
        value: trucksNeeded.toString(),
        color: const Color(0xFFFFAB40),
        subtitle: '(3 poubelles/camion)',
        extraInfo: 'Gasoil: ${fuelNeeded}L',
        extraColor: const Color(0xFFFFD700),
      ),
      _buildKPICard(
        icon: Icons.people,
        title: 'Employés requis',
        value: workersNeeded.toString(),
        color: const Color(0xFF1abc9c),
        subtitle: '(2 employés/camion)',
      ),
      ],
    );
  }

  Widget _buildKPICard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
    String? extraInfo,
    Color? extraColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: 250, // Fixed width for consistency
          child: Column(
            children: [
              Icon(icon, size: 36, color: const Color(0xFF9b59b6)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(value, 
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
              if (extraInfo != null) ...[
                const SizedBox(height: 8),
                Text(extraInfo, 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: extraColor)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      {'icon': Icons.bar_chart, 'label': 'Niveaux de remplissage'},
      {'icon': Icons.thermostat, 'label': 'Environnement'},
      {'icon': Icons.delete, 'label': 'Types de déchets'},
      {'icon': Icons.air, 'label': 'Analyse des gaz'},
      {'icon': Icons.people, 'label': 'Analyse de la population'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(tabs.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Row(
                children: [
                  Icon(tabs[index]['icon'] as IconData, size: 18),
                  const SizedBox(width: 6),
                  Text(tabs[index]['label'] as String),
                ],
              ),
              selected: currentTabIndex == index,
              onSelected: (selected) {
                setState(() => currentTabIndex = index);
              },
              selectedColor: const Color(0xFF9b59b6),
              backgroundColor: const Color(0xFF1e1e1e),
              labelStyle: TextStyle(
                color: currentTabIndex == index ? Colors.white : const Color(0xFF9b59b6),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: const BorderSide(color: Color(0xFF9b59b6)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    // Ensure analyticsData is not empty before building charts
    if (analyticsData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "No analytics data to display charts.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    switch (currentTabIndex) {
      case 0:
        return _buildFillLevelTab();
      case 1:
        return _buildEnvironmentTab();
      case 2:
        return _buildTrashTypesTab();
      case 3:
        return _buildGasAnalysisTab();
      case 4:
        return const AnalysePopulationTab(); // <-- Show your population analysis graphs here
      default:
        return Container();
    }
  }

  Widget _buildFillLevelTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Niveaux de remplissage',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: 100,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<dynamic, String>(
                name: 'Niveau de remplissage', // <-- Add a name
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['trash_level'],
                color: const Color(0xFF9b59b6),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelAlignment: ChartDataLabelAlignment.top,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'État des poubelles',
          chart: SfCircularChart(
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CircularSeries>[
              DoughnutSeries<dynamic, String>(
                dataSource: [
                  {'status': 'Poubelles pleines', 'count': analyticsData.where((bin) => bin['trash_level'] != null && bin['trash_level'] >= 80).length},
                  {'status': 'Gaz élevé', 'count': analyticsData.where((bin) => bin['gaz_level'] != null && bin['gaz_level'] >= 10).length},
                  {'status': 'Normal', 'count': analyticsData.length - analyticsData.where((bin) => (bin['trash_level'] != null && bin['trash_level'] >= 80) || (bin['gaz_level'] != null && bin['gaz_level'] >= 10)).length},
                ],
                xValueMapper: (data, _) => data['status'],
                yValueMapper: (data, _) => data['count'],
                pointColorMapper: (data, _) {
                  if (data['status'] == 'Poubelles pleines') return const Color(0xFFe74c3c);
                  if (data['status'] == 'Gaz élevé') return const Color(0xFFf39c12);
                  return const Color(0xFF2ecc71);
                },
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Poids moyen par type',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<Map<String, dynamic>, String>(
                name: 'Poids moyen', // <-- Add this
                dataSource: _calculateAverageWeightByType(),
                xValueMapper: (data, _) => data['type'],
                yValueMapper: (data, _) => data['avgWeight'],
                color: const Color(0xFF9b59b6),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Répartition géographique',
          chart: SfCartesianChart(
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Longitude', textStyle: const TextStyle(color: Color(0xFF9b59b6))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Latitude', textStyle: const TextStyle(color: Color(0xFF3498db))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: _buildTrashTypeLocationSeries(),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'point.x, point.y',
              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${data['name']}\nPosition: ${point.y.toStringAsFixed(4)}°N, ${point.x.toStringAsFixed(4)}°E\nRemplissage: ${data['trash_level']}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Température et humidité',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Température (°C)', textStyle: const TextStyle(color: Color(0xFFe74c3c))),
              labelStyle: const TextStyle(color: Color(0xFFe74c3c)),
            ),
            axes: [
              NumericAxis(
                name: 'HumidityAxis',
                opposedPosition: true,
                title: AxisTitle(text: 'Humidité (%)', textStyle: const TextStyle(color: Color(0xFF3498db))),
                labelStyle: const TextStyle(color: Color(0xFF3498db)),
                minimum: 0,
                maximum: 100,
              ),
            ],
            series: <CartesianSeries>[
              LineSeries<dynamic, String>(
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['temperature'],
                name: 'Température',
                color: const Color(0xFFe74c3c),
              ),
              LineSeries<dynamic, String>(
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['humidity'],
                name: 'Humidité',
                yAxisName: 'HumidityAxis',
                color: const Color(0xFF3498db),
              ),
            ],
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.top,
              textStyle: TextStyle(color: Colors.white),
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Distribution des températures',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<Map<String, dynamic>, String>(
                name: 'Distribution température', // <-- Add this
                dataSource: [
                  {'range': '<0°C', 'count': analyticsData.where((bin) => bin['temperature'] != null && bin['temperature'] < 0).length},
                  {'range': '0-10°C', 'count': analyticsData.where((bin) => bin['temperature'] != null && bin['temperature'] >= 0 && bin['temperature'] < 10).length},
                  {'range': '10-20°C', 'count': analyticsData.where((bin) => bin['temperature'] != null && bin['temperature'] >= 10 && bin['temperature'] < 20).length},
                  {'range': '20-30°C', 'count': analyticsData.where((bin) => bin['temperature'] != null && bin['temperature'] >= 20 && bin['temperature'] < 30).length},
                  {'range': '>30°C', 'count': analyticsData.where((bin) => bin['temperature'] != null && bin['temperature'] >= 30).length},
                ],
                xValueMapper: (data, _) => data['range'],
                yValueMapper: (data, _) => data['count'],
                color: const Color(0xFF9b59b6),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Niveaux d\'humidité',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: 100,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<dynamic, String>(
                name: 'Niveau d\'humidité', // <-- Add this
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['humidity'],
                color: const Color(0xFF1abc9c),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Corrélation Temp/Humidité',
          chart: SfCartesianChart(
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Température (°C)', textStyle: const TextStyle(color: Color(0xFF9b59b6))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Humidité (%)', textStyle: const TextStyle(color: Color(0xFF3498db))),
              minimum: 0,
              maximum: 100,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ScatterSeries<dynamic, num>(
                name: 'Température vs Humidité', // <-- Add this
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['temperature'],
                yValueMapper: (data, _) => data['humidity'],
                color: const Color(0xFF9b59b6),
                markerSettings: const MarkerSettings(isVisible: true, height: 8, width: 8),
                dataLabelMapper: (data, _) => data['name'],
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${data['name']}\nTempérature: ${point.x}°C\nHumidité: ${point.y}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrashTypesTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Types de déchets',
          chart: SfCircularChart(
            series: <CircularSeries>[
              PieSeries<Map<String, dynamic>, String>(
                dataSource: _countTrashTypes(),
                xValueMapper: (data, _) => data['type'],
                yValueMapper: (data, _) => data['count'],
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
                pointColorMapper: (data, index) {
                  final colors = [
                    const Color(0xFF9b59b6),
                    const Color(0xFF3498db),
                    const Color(0xFF2ecc71),
                    const Color(0xFFf39c12),
                    const Color(0xFFe74c3c),
                    const Color(0xFF1abc9c),
                  ];
                  return colors[index % colors.length];
                },
              ),
            ],
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Poids moyen par type',
          chart: SfCircularChart(
            series: <CircularSeries>[
              PieSeries<Map<String, dynamic>, String>(
                dataSource: _calculateAverageWeightByType(),
                xValueMapper: (data, _) => data['type'],
                yValueMapper: (data, _) => data['avgWeight'],
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
                pointColorMapper: (data, index) {
                  final colors = [
                    const Color(0xFF9b59b6),
                    const Color(0xFF3498db),
                    const Color(0xFF2ecc71),
                    const Color(0xFFf39c12),
                    const Color(0xFFe74c3c),
                    const Color(0xFF1abc9c),
                  ];
                  return colors[index % colors.length];
                },
              ),
            ],
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Répartition par volume',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<Map<String, dynamic>, String>(
                name: 'Volume moyen', // <-- Add this
                dataSource: _calculateAverageVolumeByType(),
                xValueMapper: (data, _) => data['type'],
                yValueMapper: (data, _) => data['avgVolume'],
                color: const Color(0xFF9b59b6),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Localisation par type',
          chart: SfCartesianChart(
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Longitude', textStyle: const TextStyle(color: Color(0xFF9b59b6))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Latitude', textStyle: const TextStyle(color: Color(0xFF3498db))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            series: _buildTrashTypeLocationSeries(),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${data['name']}\nType: ${series.name}\nPosition: ${point.y.toStringAsFixed(4)}°N, ${point.x.toStringAsFixed(4)}°E',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGasAnalysisTab() {
    return Column(
      children: [
        _buildChartCard(
          title: 'Niveaux de gaz',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<dynamic, String>(
                name: 'Niveau de gaz', // <-- Add this
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['gaz_level'],
                color: const Color(0xFFf39c12),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Remplissage vs Gaz',
          chart: SfCartesianChart(
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Remplissage (%)', textStyle: const TextStyle(color: Color(0xFF9b59b6))),
              minimum: 0,
              maximum: 100,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Niveau de Gaz (%)', textStyle: const TextStyle(color: Color(0xFF3498db))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ScatterSeries<dynamic, num>(
                name: 'Remplissage vs Gaz', // <-- Add this
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['trash_level'],
                yValueMapper: (data, _) => data['gaz_level'],
                pointColorMapper: (data, _) {
                  if ((data['trash_level'] != null && data['trash_level'] >= 80) && (data['gaz_level'] != null && data['gaz_level'] >= 10)) return const Color(0xFFe74c3c);
                  if (data['trash_level'] != null && data['trash_level'] >= 80) return const Color(0xFFf39c12);
                  if (data['gaz_level'] != null && data['gaz_level'] >= 10) return const Color(0xFF1abc9c);
                  return const Color(0xFF2ecc71);
                },
                markerSettings: const MarkerSettings(isVisible: true, height: 8, width: 8),
                dataLabelMapper: (data, _) => data['name'],
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${data['name']}\nRemplissage: ${point.x}%\nGaz: ${point.y}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Gaz vs Température',
          chart: SfCartesianChart(
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Température (°C)', textStyle: const TextStyle(color: Color(0xFF9b59b6))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Niveau de Gaz (%)', textStyle: const TextStyle(color: Color(0xFF3498db))),
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ScatterSeries<dynamic, num>(
                name: 'Gaz vs Température', // <-- Add this
                dataSource: analyticsData,
                xValueMapper: (data, _) => data['temperature'],
                yValueMapper: (data, _) => data['gaz_level'],
                pointColorMapper: (data, _) => 
                  (data['gaz_level'] != null && data['gaz_level'] >= 10) ? const Color(0xFFf39c12) : const Color(0xFF2ecc71),
                markerSettings: const MarkerSettings(isVisible: true, height: 8, width: 8),
                dataLabelMapper: (data, _) => data['name'],
                dataLabelSettings: const DataLabelSettings(isVisible: false),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${data['name']}\nTempérature: ${point.x}°C\nGaz: ${point.y}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildChartCard(
          title: 'Alertes gaz critiques',
          chart: SfCartesianChart(
            primaryXAxis: CategoryAxis(
              labelStyle: const TextStyle(color: Colors.white),
            ),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: 100,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              textStyle: TextStyle(color: Colors.white),
            ),
            series: <CartesianSeries>[
              ColumnSeries<dynamic, String>(
                name: 'Gaz critique', // <-- Add this
                dataSource: analyticsData.where((bin) => bin['gaz_level'] != null && bin['gaz_level'] >= 10).toList(),
                xValueMapper: (data, _) => data['name'],
                yValueMapper: (data, _) => data['gaz_level'],
                pointColorMapper: (data, _) => 
                  (data['gaz_level'] != null && data['gaz_level'] > 20) ? const Color(0xFFe74c3c) : const Color(0xFFf39c12),
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  textStyle: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      color: const Color(0xFF232323), // Slightly lighter dark background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, 
              style: const TextStyle(fontSize: 18, color: Color(0xFF9b59b6), fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 300, child: chart),
          ],
        ),
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
