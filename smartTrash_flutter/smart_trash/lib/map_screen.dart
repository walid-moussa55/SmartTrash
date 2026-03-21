import 'dart:math';

// lib/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:naqi_ai/trash_bin_model.dart';
import 'package:naqi_ai/level_utils.dart';

class MapScreen extends StatefulWidget {
  final List<TrashBin> trashBins;
  final TrashBin? initialTrashBin;
  final bool showRoute;

  const MapScreen({
    super.key,
    required this.trashBins,
    this.initialTrashBin,
    this.showRoute = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with OSMMixinObserver {
  late MapController mapController;
  bool _routeDrawn = false;
  TrashBin? _selectedBin;
  String? _routeInfo;
  final GeoPoint _defaultCenter = GeoPoint(
    latitude: 32.8811,
    longitude: -6.9063,
  );

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _defaultCenter,
    );
    mapController.addObserver(this);
    mapController.enableTracking(enableStopFollow: true);
  }

  Future<void> _addMarkers() async {
    try {
      for (final bin in widget.trashBins) {
        final geoPoint = GeoPoint(
          latitude: bin.location.latitude,
          longitude: bin.location.longitude,
        );
        
        if (bin.location.latitude == 0.0 && bin.location.longitude == 0.0) {
          continue;
        }

        await mapController.addMarker(
          geoPoint,
          markerIcon: MarkerIcon(
            icon: Icon(
              Icons.location_on,
              color: getLevelColor(bin.trashLevel),
              size: 40,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding markers: $e");
    }
  }

  Future<void> _drawRouteToTarget() async {
    if (widget.initialTrashBin == null) return;
    try {
      final userLoc = await mapController.myLocation();
      final targetLoc = GeoPoint(
        latitude: widget.initialTrashBin!.location.latitude,
        longitude: widget.initialTrashBin!.location.longitude,
      );

      final configs = [
        MultiRoadConfiguration(
          startPoint: userLoc,
          destinationPoint: targetLoc,
        ),
      ];

      await mapController.drawMultipleRoad(
        configs,
        commonRoadOption: MultiRoadOption(
          roadColor: Colors.blue,
          roadWidth: 6,
        ),
      );

      // Calculate approximate distance
      final dLat = (targetLoc.latitude - userLoc.latitude) * 111320;
      final dLon = (targetLoc.longitude - userLoc.longitude) * 111320 * cos(userLoc.latitude * pi / 180);
      final distanceM = sqrt(dLat * dLat + dLon * dLon);
      final distanceKm = distanceM / 1000;

      setState(() {
        _routeDrawn = true;
        _routeInfo = distanceKm >= 1
            ? '${distanceKm.toStringAsFixed(1)} km'
            : '${distanceM.toStringAsFixed(0)} m';
      });

      // Zoom to fit both points
      final minLat = min(userLoc.latitude, targetLoc.latitude);
      final maxLat = max(userLoc.latitude, targetLoc.latitude);
      final minLon = min(userLoc.longitude, targetLoc.longitude);
      final maxLon = max(userLoc.longitude, targetLoc.longitude);
      final latPad = (maxLat - minLat) * 0.3;
      final lonPad = (maxLon - minLon) * 0.3;

      await mapController.zoomToBoundingBox(
        BoundingBox(
          north: maxLat + latPad,
          south: minLat - latPad,
          east: maxLon + lonPad,
          west: minLon - lonPad,
        ),
        paddinInPixel: 60,
      );
    } catch (e) {
      debugPrint("Error drawing route: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de tracer l\'itinéraire. Vérifiez votre localisation.')),
        );
      }
    }
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (!isReady) return;
    
    try {
      // Add initial delay to ensure map is fully initialized
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (widget.initialTrashBin != null) {
        await _addMarkers();
        final initialLocation = GeoPoint(
          latitude: widget.initialTrashBin!.location.latitude,
          longitude: widget.initialTrashBin!.location.longitude,
        );
        
        await mapController.moveTo(initialLocation, animate: true);
        await Future.delayed(const Duration(milliseconds: 300));
        await mapController.setZoom(zoomLevel: 16);

        // Draw route from user location to target bin
        if (widget.showRoute) {
          await _drawRouteToTarget();
        }
        
      } else if (widget.trashBins.isNotEmpty) {
        // Get valid markers
        final markers = widget.trashBins
            .where((bin) => bin.location.latitude != 0.0 && bin.location.longitude != 0.0)
            .map((bin) => GeoPoint(
                  latitude: bin.location.latitude,
                  longitude: bin.location.longitude,
                ))
            .toList();

        if (markers.isNotEmpty) {
          // Add markers
          await _addMarkers();
          
          // Calculate center point of all markers
          double centerLat = markers.map((m) => m.latitude).reduce((a, b) => a + b) / markers.length;
          double centerLon = markers.map((m) => m.longitude).reduce((a, b) => a + b) / markers.length;
          
          // First move to center
          await mapController.moveTo(GeoPoint(
            latitude: centerLat,
            longitude: centerLon,
          ), animate: true);
          
          // Wait for movement to complete
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Calculate bounding box
          double minLat = markers.map((m) => m.latitude).reduce(min);
          double maxLat = markers.map((m) => m.latitude).reduce(max);
          double minLon = markers.map((m) => m.longitude).reduce(min);
          double maxLon = markers.map((m) => m.longitude).reduce(max);

          // Add padding to bounding box
          final latPadding = (maxLat - minLat) * 0.1;
          final lonPadding = (maxLon - minLon) * 0.1;

          final boundingBox = BoundingBox(
            north: maxLat + latPadding,
            south: minLat - latPadding,
            east: maxLon + lonPadding,
            west: minLon - lonPadding,
          );

          // Finally zoom to show all markers
          await mapController.zoomToBoundingBox(
            boundingBox,
            paddinInPixel: 50,
          );
        }
      } else {
        // Default center location
        await mapController.moveTo(_defaultCenter, animate: true);
        await Future.delayed(const Duration(milliseconds: 300));
        await mapController.setZoom(zoomLevel: 14);
      }
    } catch (e) {
      debugPrint("Error in mapIsReady: $e");
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final targetBin = widget.initialTrashBin;
    final isRouteMode = widget.showRoute && targetBin != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRouteMode ? 'Itinéraire vers ${targetBin.name}' : 'Trash Bin Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              mapController.currentLocation();
              mapController.enableTracking(enableStopFollow: false);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: mapController,
            osmOption: OSMOption(
              zoomOption: ZoomOption(
                initZoom: 14,
                minZoomLevel: 2,
                maxZoomLevel: 19,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  assetMarker: AssetMarker(
                    image: AssetImage('assets/images/person-location.png'),
                    scaleAssetImage: 10,
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  assetMarker: AssetMarker(
                    image: AssetImage('assets/images/person-location.png'),
                    scaleAssetImage: 10,
                  ),
                ),
              ),
            ),
            onGeoPointClicked: (geoPoint) {
              if (_selectedBin != null) return;
              TrashBin? clickedBin;
              for (final bin in widget.trashBins) {
                if (bin.location.latitude == geoPoint.latitude &&
                    bin.location.longitude == geoPoint.longitude) {
                  clickedBin = bin;
                  break;
                }
              }

              if (clickedBin != null) {
                setState(() {
                  _selectedBin = clickedBin;
                });
              }
            },
          ),
          // Bin info popup overlay
          if (_selectedBin != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _selectedBin = null),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {},
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedBin!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text('Trash Type: ${_selectedBin!.trashType}'),
                            Text('Trash Level: ${_selectedBin!.trashLevel}%'),
                            Text('Gaz Level: ${_selectedBin!.gazLevel}'),
                            Text('Humidity: ${_selectedBin!.humidity}%'),
                            Text('Temperature: ${_selectedBin!.temperature}°C'),
                            Text('Weight: ${_selectedBin!.weight} kg'),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(() => _selectedBin = null),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Route info banner at the bottom
          if (isRouteMode && _routeDrawn)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: getLevelColor(targetBin.trashLevel).withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.directions, color: Colors.blue, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              targetBin.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type: ${targetBin.trashType} • Niveau: ${targetBin.trashLevel.toStringAsFixed(0)}%',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (_routeInfo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _routeInfo!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController.removeObserver(this);
    mapController.disabledTracking();
    mapController.dispose();
    super.dispose();
  }
}