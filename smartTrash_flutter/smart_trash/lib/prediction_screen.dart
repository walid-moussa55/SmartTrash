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
  // ── DESIGN SYSTEM CONSTANTS ──
  static const Color _kBg        = Color(0xFFF5F3EE);
  static const Color _kSurface   = Color(0xFFFFFFFF);
  static const Color _kBorder    = Color(0xFFE2DDD5);
  static const Color _kPale      = Color(0xFFDCF0E0);
  static const Color _kLight     = Color(0xFF8EBF93);
  static const Color _kMid       = Color(0xFF5C8E60);
  static const Color _kPrimary   = Color(0xFF2A4A30);
  static const Color _kAlert     = Color(0xFFB86B2A);
  static const Color _kTextSec   = Color(0xFF7A8A7C);
  static const Color _kTextDark  = Color(0xFF2A4A30);

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
    _tabController.addListener(() => setState(() {}));
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
      final response = await http.get(Uri.parse('$serverUrl/prediction'));
      if (response.statusCode != 200) throw Exception('Failed to load predictions');
      final levelData = json.decode(response.body) as Map<String, dynamic>;
      final predictions = <String, BinPrediction>{};
      levelData.forEach((binId, d) => predictions[binId] = BinPrediction.fromMap(d as Map<String, dynamic>));
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
      if (response.statusCode != 200) throw Exception('Failed to load weekly data');
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
        title: const Text('IA ANALYTICS', style: TextStyle(color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: _kPrimary), onPressed: () { _fetchPredictions(); _fetchWeeklyPredictions(); }),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildCustomTabBar(),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentPredictionsTab(),
                _buildWeeklyPlannerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _kBorder.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildTabItem(0, 'Prévisions', Icons.trending_up_rounded),
          _buildTabItem(1, 'Calendrier', Icons.calendar_month_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    bool isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? _kPrimary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : _kTextSec),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : _kTextSec, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPredictionsTab() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    if (_error != null) return _buildErrorState(_error!, _fetchPredictions);

    final entries = _predictions.entries.toList();

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _fetchPredictions,
      child: isDesktop 
        ? GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20, mainAxisExtent: 280,
            ),
            itemCount: entries.length,
            itemBuilder: (context, i) => _buildPredictionCard(entries[i].value),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) => _buildPredictionCard(entries[i].value),
          ),
    );
  }

  Widget _buildPredictionCard(BinPrediction prediction) {
    final curLvl = prediction.currentLevel;
    final prdLvl = prediction.predictedLevel < curLvl ? curLvl : prediction.predictedLevel;
    final isRising = prdLvl > curLvl;

    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (isRising ? _kAlert : _kMid).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(isRising ? Icons.auto_graph_rounded : Icons.check_circle_rounded, color: isRising ? _kAlert : _kMid, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(prediction.binName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kTextDark))),
              Text(isRising ? 'Hausse' : 'Stable', style: TextStyle(color: isRising ? _kAlert : _kMid, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          _buildGaugeStack('Actuel', curLvl, _kMid),
          const SizedBox(height: 16),
          _buildGaugeStack('Prévision (IA)', prdLvl, isRising ? _kAlert : _kMid, isPrediction: true),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.update_rounded, size: 14, color: _kTextSec),
              const SizedBox(width: 6),
              Text('Mise à jour: ${_formatDateTime(prediction.timestamp)}', style: const TextStyle(color: _kTextSec, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeStack(String label, double level, Color color, {bool isPrediction = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label, style: const TextStyle(color: _kTextSec, fontWeight: FontWeight.w700, fontSize: 11)),
                if (isPrediction) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF5C8E60)),
                ]
              ],
            ),
            Text('${level.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 10, width: double.infinity,
          decoration: BoxDecoration(color: _kBorder.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: level / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: isPrediction 
                  ? const LinearGradient(colors: [Color(0xFF8EBF93), Color(0xFF2A4A30)])
                  : LinearGradient(colors: [color.withOpacity(0.7), color]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isPrediction ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: -1)] : [],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyPlannerTab() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    if (_isWeeklyLoading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    if (_weeklyError != null) return _buildErrorState(_weeklyError!, _fetchWeeklyPredictions);
    if (_weeklyData.isEmpty) return const Center(child: Text('Aucune donnée.'));

    final day = _weeklyData[_selectedDayIndex];
    final dayAbbr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _weeklyData.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, i) {
              bool isSel = i == _selectedDayIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 65,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSel ? _kPrimary : _kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSel ? _kPrimary : _kBorder.withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayAbbr[i % 7], style: TextStyle(fontSize: 12, color: isSel ? Colors.white70 : _kTextSec, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(_weeklyData[i].date.substring(8), style: TextStyle(fontSize: 18, color: isSel ? Colors.white : _kTextDark, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        Column(
          children: [
            Row(
              children: [
                Expanded(child: Divider(color: _kBorder, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${day.dayName.toUpperCase()} – PRÉVISIONS', style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                ),
                Expanded(child: Divider(color: _kBorder, thickness: 1)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildColoredResTile(Icons.delete_rounded, '${day.resources.fullBins}', 'Pleines', _kAlert),
                const SizedBox(width: 12),
                _buildColoredResTile(Icons.local_shipping_rounded, '${day.resources.trucksNeeded}', 'Camions', _kPrimary),
                const SizedBox(width: 12),
                _buildColoredResTile(Icons.engineering_rounded, '${day.resources.workersNeeded}', 'Équipe', _kMid),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        const Text('DÉTAILS PAR POUBELLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: _kTextSec, letterSpacing: 1)),
        const SizedBox(height: 16),
        isDesktop 
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 12, mainAxisExtent: 70,
              ),
              itemCount: day.bins.length,
              itemBuilder: (context, i) => _buildBinMiniCard(day.bins[i]),
            )
          : Column(children: day.bins.map((b) => _buildBinMiniCard(b)).toList()),
        const SizedBox(height: 40),
      ],
    );
  }


  Widget _buildColoredResTile(IconData icon, String val, String lab, Color color) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Expanded(
      child: Container(
        height: isDesktop ? 140 : 100,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(isDesktop ? 28 : 20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: Colors.white.withOpacity(0.3), 
              size: isDesktop ? 80 : 40, // Slightly smaller on mobile to save space
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isDesktop ? 32 : 24)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      lab.toUpperCase(), 
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: isDesktop ? 11 : 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBinMiniCard(DayBinPrediction bin) {
    final color = getLevelColor(bin.predictedLevel);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _kBorder.withOpacity(0.3))),
      child: Row(
        children: [
          Container(height: 12, width: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(child: Text(bin.binName, style: const TextStyle(fontWeight: FontWeight.w700, color: _kTextDark))),
          Text('${bin.predictedLevel.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: _kAlert, size: 48),
          const SizedBox(height: 16),
          Text('Erreur de chargement', style: TextStyle(color: _kTextSec, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('RÉESSAYER'), style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) => '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, "0")}';
}