// lib/optimized_route_screen.dart
import 'package:flutter/material.dart';
import 'package:naqi_ai/debug_utils.dart';
import 'package:naqi_ai/home_screen.dart' show TrashBin; // For passing allBins
import 'package:naqi_ai/route_models.dart';
import 'package:naqi_ai/route_optimization_service.dart';
import 'package:naqi_ai/route_map_screen.dart'; // Assuming map_screen can be adapted
import 'package:naqi_ai/user_model.dart'; // For AppUser
import 'package:http/http.dart' as http;

class OptimizedRouteScreen extends StatefulWidget {
  final List<TrashBin> allAvailableBins; // Pass all bins from HomeScreen
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _routeService.getOptimizedRoute(
        allBins: widget.allAvailableBins,
      );
      if (mounted) {
        setState(() {
          _routeResponse = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.addDebugMessage("Error fetching optimized route on screen: $e");
      if (mounted) {
        setState(() {
          // Replace generic exception with
          if (e is http.ClientException) {
            _error = "Network error: ${e.message}";
          } else if (e is FormatException) {
            _error = "Data format error";
          } else {
            _error = "Route optimization failed";
          }
          _isLoading = false;
        });
      }
    }
  }

  void _viewRouteOnMap() {
    if (_routeResponse == null || _routeResponse!.orderedBins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No route to display on map.")),
      );
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => RouteMapScreen(
          orderedBins: _routeResponse!.orderedBins,
        ),
        transitionsBuilder: (_, a, __, c) {
          final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
          return SlideTransition(position: offset, child: FadeTransition(opacity: a, child: c));
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Optimized Collection Route"),
        actions: [
          if (_routeResponse != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: "View Route on Map",
              onPressed: _viewRouteOnMap,
            )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text("Error: $_error", style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(onPressed: _fetchOptimizedRoute, icon: const Icon(Icons.refresh), label: const Text("Retry")),
            ],
          ),
        ),
      );
    }
    if (_routeResponse == null || _routeResponse!.orderedBins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 16),
            Text("No optimized route available.", style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final route = _routeResponse!;
    return Column(
      children: [
        // Summary card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(Icons.delete_outline, "${route.orderedBins.length}", "Bins"),
              _summaryItem(Icons.local_drink, "${route.totalVolume.toStringAsFixed(0)}L", "Volume"),
              _summaryItem(Icons.scale, "${route.totalWeight.toStringAsFixed(0)}kg", "Weight"),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: route.orderedBins.length,
            itemBuilder: (context, index) {
              final bin = route.orderedBins[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(bin.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("${bin.volume}L · ${bin.weight}kg · ${bin.capacity}%"),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (_, __, ___) => RouteMapScreen(orderedBins: _routeResponse!.orderedBins),
                    transitionsBuilder: (_, a, __, c) {
                      final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
                      return SlideTransition(position: offset, child: FadeTransition(opacity: a, child: c));
                    },
                    transitionDuration: const Duration(milliseconds: 350),
                  )),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ],
    );
  }
}