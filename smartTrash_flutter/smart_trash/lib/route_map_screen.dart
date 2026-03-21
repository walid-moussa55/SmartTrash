// lib/route_map_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:naqi_ai/route_models.dart';
import 'package:naqi_ai/app_settings.dart';
import 'package:naqi_ai/trash_bin_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class RouteMapScreen extends StatefulWidget {
  final List<OrderedBin> orderedBins;

  const RouteMapScreen({
    super.key,
    required this.orderedBins,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> with OSMMixinObserver {
  late MapController mapController;
  late AppSettings _appSettings;
  GeoPoint? userLocation;
  final GeoPoint _defaultCenter = GeoPoint(
    latitude: 32.8811,
    longitude: -6.9063,
  );
  bool _isLoading = true;
  // Popup state: stores info to display in overlay instead of showDialog
  Map<String, dynamic>? _popupInfo;

  // Add a reference to the database
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('trash_bins');
  Map<String, TrashBin> _trashBinsCache = {};

  @override
  void initState() {
    super.initState();
    mapController = MapController(
      initPosition: _defaultCenter,
    );
    mapController.addObserver(this);
    mapController.enableTracking(enableStopFollow: true);
    _appSettings = AppSettings();
    _appSettings.loadSettings();
    _fetchTrashBins();
    _getCurrentLocation();
  }

  Future<void> _fetchTrashBins() async {
    try {
      final event = await _databaseRef.once();
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _trashBinsCache = {};
        
        data.forEach((key, value) {
          if (value is Map) {
            _trashBinsCache[key.toString()] = TrashBin.fromMap(key.toString(), value);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching trash bins: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          userLocation = GeoPoint(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });
        await mapController.enableTracking(
          enableStopFollow: true,
          disableUserMarkerRotation: true,
        );
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _addMarkers() async {
    try {
      if (widget.orderedBins.isEmpty) return;
      
      setState(() => _isLoading = true);
      
      // First clear everything
      await mapController.clearAllRoads();
      await mapController.removeMarker(_defaultCenter); // Clear default marker if any
      
      // Add markers first
      for (int i = 0; i < widget.orderedBins.length; i++) {
        final bin = widget.orderedBins[i];
        final geoPoint = GeoPoint(
          latitude: bin.location.latitude,
          longitude: bin.location.longitude,
        );
        
        if (geoPoint.latitude == 0.0 && geoPoint.longitude == 0.0) continue;

        await mapController.addMarker(
          geoPoint,
          markerIcon: MarkerIcon(
            iconWidget: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        );
        
        // Add delay between markers
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Then zoom to show all markers
      await _zoomToMarkers();

      await Future.delayed(const Duration(milliseconds: 400));

      await _drawRoute();
      
      // Finally draw routes with delay
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      debugPrint("Error in _addMarkers: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _zoomToMarkers() async {
    final List<GeoPoint> points = [];
    
    if (userLocation != null) points.add(userLocation!);
    
    points.addAll(widget.orderedBins
        .map((bin) => GeoPoint(
              latitude: bin.location.latitude,
              longitude: bin.location.longitude,
            ))
        .where((p) => p.latitude != 0.0 && p.longitude != 0.0));

    if (points.isEmpty) return;
    
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLon = min(minLon, point.longitude);
      maxLon = max(maxLon, point.longitude);
    }

    final boundingBox = BoundingBox(
      north: maxLat,
      south: minLat,
      east: maxLon,
      west: minLon,
    );

    await mapController.zoomToBoundingBox(
      boundingBox,
      paddinInPixel: 50,
    );
  }


  @override
  Future<void> mapIsReady(bool isReady) async {
    if (!isReady) return;
    
    try {
      // Wait for map to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      // First get current location
      await _getCurrentLocation();
      
      // Then add markers
      await _addMarkers();
      
    } catch (e) {
      debugPrint("Error in mapIsReady: $e");
    }
  }

  void _showTruckInfo(GeoPoint location) {
    setState(() {
      _popupInfo = {
        'type': 'truck',
        'title': 'Collection Truck',
        'rows': [
          'Maximum Volume: ${_appSettings.containerVolume?.toStringAsFixed(1) ?? "N/A"} L',
          'Maximum Weight: ${_appSettings.containerWeight?.toStringAsFixed(1) ?? "N/A"} kg',
          '---',
          'Current Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
        ],
      };
    });
  }

  Future<void> _drawRoute() async {
    List<GeoPoint> points = [];
    if (userLocation != null) {
      points.add(userLocation!); // Start from truck location
    }
    points.addAll(widget.orderedBins
        .map((bin) => GeoPoint(
              latitude: bin.location.latitude,
              longitude: bin.location.longitude,
            ))
        .where((p) => p.latitude != 0.0 && p.longitude != 0.0));

    if (points.length < 2) return;

    // Build MultiRoadConfiguration list for each segment
    final configs = <MultiRoadConfiguration>[];
    for (int i = 0; i < points.length - 1; i++) {
      configs.add(
        MultiRoadConfiguration(
          startPoint: points[i],
          destinationPoint: points[i + 1],
          // Optionally, you can add roadOptionConfiguration here
        ),
      );
    }

    await mapController.drawMultipleRoad(
      configs,
      commonRoadOption: MultiRoadOption(
        roadColor: Colors.blue,
        roadWidth: 8,
      ),
    );
  }

  TrashBin _getTrashBinFromOrderedBin(OrderedBin orderedBin) {
    // First try to find by exact location match
    return _trashBinsCache.values.firstWhere(
      (bin) => 
        bin.location.latitude == orderedBin.location.latitude &&
        bin.location.longitude == orderedBin.location.longitude,
      orElse: () {
        // If not found by location, try to find by name
        return _trashBinsCache.values.firstWhere(
          (bin) => bin.name == orderedBin.name,
          orElse: () {
            // If still not found, create a temporary TrashBin from OrderedBin data
            return TrashBin(
              id: 'temp_${orderedBin.name}',
              name: orderedBin.name,
              humidity: 0.0, // Default values
              trashLevel: orderedBin.capacity,
              gazLevel: 0.0,
              location: orderedBin.location,
              trashType: 'Unknown',
              weight: orderedBin.weight,
              volume: orderedBin.volume,
            );
          },
        );
      },
    );
  }

  void _showBinInfo(OrderedBin orderedBin, int orderNumber) {
    final trashBin = _getTrashBinFromOrderedBin(orderedBin);
    final rows = <String>[
      'Trash Type: ${trashBin.trashType}',
      'Capacity: ${trashBin.trashLevel.toStringAsFixed(1)}%',
      'Weight: ${trashBin.weight.toStringAsFixed(1)} kg',
    ];
    if (trashBin.volume != null) {
      rows.add('Volume: ${trashBin.volume!.toStringAsFixed(1)} L');
    }
    rows.addAll([
      'Gas Level: ${trashBin.gazLevel.toStringAsFixed(1)}%',
      'Humidity: ${trashBin.humidity.toStringAsFixed(1)}%',
      'Temperature: ${trashBin.temperature.toStringAsFixed(1)}°C',
      '---',
      'Order in Route: $orderNumber',
      'Distance: ${orderedBin.distance?.toStringAsFixed(1) ?? "N/A"} km',
      'Location: ${trashBin.location.latitude.toStringAsFixed(6)}, ${trashBin.location.longitude.toStringAsFixed(6)}',
    ]);
    setState(() {
      _popupInfo = {
        'type': 'bin',
        'title': 'Container $orderNumber: ${trashBin.name}',
        'rows': rows,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => mapController.currentLocation(),
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
              // Add these missing options
              // trackMyPosition: true,
              showDefaultInfoWindow: false,
              enableRotationByGesture: true,
              showZoomController: true,
              userTrackingOption: UserTrackingOption(
                enableTracking: true,
                unFollowUser: false,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  assetMarker: AssetMarker(
                    image: AssetImage('assets/images/truck_marker.png'),
                    scaleAssetImage: 25,
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  assetMarker: AssetMarker(
                    image: AssetImage('assets/images/truck_marker.png'),
                    scaleAssetImage: 25,
                  ),
                ),
              ),
            ),
            onGeoPointClicked: (geoPoint) async {
              if (_popupInfo != null) return;
              if (userLocation?.latitude == geoPoint.latitude && 
                  userLocation?.longitude == geoPoint.longitude) {
                _showTruckInfo(geoPoint);
              } else {
                final clickedIndex = widget.orderedBins.indexWhere(
                  (bin) => 
                    bin.location.latitude == geoPoint.latitude && 
                    bin.location.longitude == geoPoint.longitude,
                );
                if (clickedIndex == -1) return;
                
                _showBinInfo(
                  widget.orderedBins[clickedIndex],
                  clickedIndex + 1
                );
              }
            },
          ),
          // Info popup overlay
          if (_popupInfo != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _popupInfo = null),
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
                              _popupInfo!['title'] as String,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ...(_popupInfo!['rows'] as List<String>).map((row) {
                              if (row == '---') return const Divider();
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(row),
                              );
                            }),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(() => _popupInfo = null),
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
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController.removeObserver(this);
    mapController.dispose();
    super.dispose();
  }
}