import 'package:flutter/material.dart';
import 'package:naqi_ai/home_screen.dart' show TrashBin;
import 'package:naqi_ai/route_models.dart';
import 'package:naqi_ai/route_optimization_service.dart';
import 'package:naqi_ai/route_map_screen.dart'; 
import 'package:naqi_ai/map_screen.dart';
import 'package:naqi_ai/user_model.dart';
import 'package:http/http.dart' as http;

// --- Visual Constants (NaqiAI System) ---
const _kBg = Color(0xFFF5F3EE);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2DDD5);
const _kPale = Color(0xFFDCF0E0);
const _kMid = Color(0xFF5C8E60);
const _kPrimary = Color(0xFF2A4A30);
const _kTextSec = Color(0xFF7A8A7C);
const _kAlert = Color(0xFFB86B2A);

class OptimizedRouteScreen extends StatefulWidget {
  final List<TrashBin> allAvailableBins; 
  final AppUser currentUser;

  const OptimizedRouteScreen({
    super.key,
    required this.allAvailableBins,
    required this.currentUser,
  });

  @override
  State<OptimizedRouteScreen> createState() => _OptimizedRouteScreenState();
}

class _OptimizedRouteScreenState extends State<OptimizedRouteScreen> {
  final RouteOptimizationService _routeService = RouteOptimizationService();
  OptimizedRouteResponse? _routeResponse;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOptimizedRoute();
  }

  Future<void> _fetchOptimizedRoute() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await _routeService.getOptimizedRoute(allBins: widget.allAvailableBins);
      if (mounted) setState(() { _routeResponse = response; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is http.ClientException ? "Erreur réseau" : "Optimisation échouée";
          _isLoading = false;
        });
      }
    }
  }

  void _viewRouteOnMap() {
    if (_routeResponse == null || _routeResponse!.orderedBins.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => RouteMapScreen(orderedBins: _routeResponse!.orderedBins)));
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
        title: const Text("ROUTE OPTIMISÉE", style: TextStyle(color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        actions: [
          if (_routeResponse != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.map_outlined, color: _kPrimary),
                onPressed: _viewRouteOnMap,
              ),
            )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2));
    if (_error != null) return _buildErrorState();
    if (_routeResponse == null || _routeResponse!.orderedBins.isEmpty) return _buildEmptyState();

    final route = _routeResponse!;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            _buildSummaryHero(route),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: route.orderedBins.length,
                itemBuilder: (context, index) => _buildRouteStep(route.orderedBins[index], index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHero(OptimizedRouteResponse route) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryStat(Icons.delete_sweep_rounded, "${route.orderedBins.length}", "BACS", _kPrimary),
          _summaryStat(Icons.opacity_rounded, "${route.totalVolume.toStringAsFixed(0)}", "LITRES", _kMid),
          _summaryStat(Icons.fitness_center_rounded, "${route.totalWeight.toStringAsFixed(0)}", "KG", _kAlert),
        ],
      ),
    );
  }

  Widget _summaryStat(IconData icon, String val, String lab, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color.withOpacity(0.15), size: 48),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val, style: const TextStyle(color: _kPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
              Text(lab, style: const TextStyle(color: _kTextSec, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(OrderedBin bin, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: _kPale, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Text("${index + 1}", style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bin.name, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildInfoBadge("${bin.volume.toStringAsFixed(0)}L", _kMid.withOpacity(0.1)),
                const SizedBox(width: 8),
                _buildInfoBadge("${bin.capacity.toStringAsFixed(0)}%", bin.capacity > 80 ? _kAlert.withOpacity(0.1) : _kPrimary.withOpacity(0.1)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: _kBorder, size: 16),
        onTap: () {
          // Find original TrashBin for mapping by name
          final originalBin = widget.allAvailableBins.firstWhere((b) => b.name == bin.name);
          Navigator.push(context, MaterialPageRoute(builder: (c) => MapScreen(trashBins: [originalBin], initialTrashBin: originalBin, showRoute: true)));
        },
      ),
    );
  }

  Widget _buildInfoBadge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: _kAlert, size: 64),
        const SizedBox(height: 20),
        Text(_error!, style: const TextStyle(color: _kPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _fetchOptimizedRoute, child: const Text("RÉESSAYER")),
      ],
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_rounded, color: _kMid.withOpacity(0.2), size: 100),
        const SizedBox(height: 20),
        const Text("AUCUNE ROUTE À OPTIMISER", style: TextStyle(color: _kPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}