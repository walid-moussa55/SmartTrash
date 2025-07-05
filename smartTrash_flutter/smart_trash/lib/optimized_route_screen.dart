// lib/optimized_route_screen.dart
import 'package:flutter/material.dart';
import 'package:smart_trash/debug_utils.dart';
import 'package:smart_trash/home_screen.dart' show TrashBin; // For passing allBins
import 'package:smart_trash/route_models.dart';
import 'package:smart_trash/route_optimization_service.dart';
import 'package:smart_trash/route_map_screen.dart'; // Assuming map_screen can be adapted
import 'package:smart_trash/user_model.dart'; // For AppUser
import 'package:http/http.dart' as http;

class OptimizedRouteScreen extends StatefulWidget {
  final List<TrashBin> allAvailableBins; // Pass all bins from HomeScreen
  final AppUser currentUser;

  const OptimizedRouteScreen({
    Key? key,
    required this.allAvailableBins,
    required this.currentUser,
  }) : super(key: key);

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
      MaterialPageRoute(
        builder: (context) => RouteMapScreen( // Use the new screen
          orderedBins: _routeResponse!.orderedBins,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: Colors.red.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                  const SizedBox(height: 16),
                  Text("Error: $_error", style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _fetchOptimizedRoute,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_routeResponse == null || _routeResponse!.orderedBins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: Colors.grey.shade100,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600, size: 48),
                  const SizedBox(height: 16),
                  const Text("No optimized route available or no bins to collect.",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final route = _routeResponse!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.blue.shade700, size: 32),
                      const SizedBox(width: 10),
                      Text("Route Summary", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text("Total Bins: ", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text("${route.orderedBins.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.local_drink, color: Colors.blue.shade400),
                      const SizedBox(width: 6),
                      Text("Total Volume: ", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text("${route.totalVolume.toStringAsFixed(1)} L", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.scale, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text("Total Weight: ", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text("${route.totalWeight.toStringAsFixed(1)} kg", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: route.orderedBins.length,
            itemBuilder: (context, index) {
              final bin = route.orderedBins[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(bin.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Text("${bin.location.latitude.toStringAsFixed(4)}, ${bin.location.longitude.toStringAsFixed(4)}", style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.local_drink, size: 15, color: Colors.blue.shade400),
                            const SizedBox(width: 2),
                            Text("${bin.volume}L", style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 10),
                            Icon(Icons.scale, size: 15, color: Colors.orange.shade700),
                            const SizedBox(width: 2),
                            Text("${bin.weight}kg", style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 10),
                            Icon(Icons.battery_full, size: 15, color: Colors.green.shade700),
                            const SizedBox(width: 2),
                            Text("${bin.capacity}%", style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        if (bin.distance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              children: [
                                Icon(Icons.directions_walk, size: 15, color: Colors.purple.shade400),
                                const SizedBox(width: 2),
                                Text("${bin.distance!.toStringAsFixed(1)} km", style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RouteMapScreen(
                          orderedBins: _routeResponse!.orderedBins,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}