// lib/route_map_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:smart_trash/route_models.dart';
import 'package:smart_trash/app_settings.dart';
import 'package:smart_trash/home_screen.dart' show TrashBin;
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class RouteMapScreen extends StatefulWidget {
  final List<OrderedBin> orderedBins;

  const RouteMapScreen({
    Key? key,
    required this.orderedBins,
  }) : super(key: key);

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> with OSMMixinObserver {
  late MapController mapController;
  late AppSettings _appSettings;
  GeoPoint? userLocation;
  final GeoPoint _defaultCenter = GeoPoint(
    latitude: 32.3372,
    longitude: -6.3498,
  );
  bool _isLoading = true;
  List<RoadInfo> _roads = [];

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

  Color _getBinColor(double capacity) {
    if (capacity <= 25) return Colors.green;
    if (capacity <= 50) return Colors.orange;
    if (capacity <= 75) return Colors.deepOrange;
    return Colors.red;
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Collection Truck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maximum Volume: ${_appSettings.containerVolume?.toStringAsFixed(1) ?? "N/A"} L'),
            Text('Maximum Weight: ${_appSettings.containerWeight?.toStringAsFixed(1) ?? "N/A"} kg'),
            const Divider(),
            Text('Current Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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

  TrashBin? _getTrashBinFromOrderedBin(OrderedBin orderedBin) {
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
    if (trashBin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bin data not found")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Container $orderNumber: ${trashBin.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trash Type: ${trashBin.trashType}'),
            Text('Capacity: ${trashBin.trashLevel.toStringAsFixed(1)}%'),
            Text('Weight: ${trashBin.weight.toStringAsFixed(1)} kg'),
            if (trashBin.volume != null)
              Text('Volume: ${trashBin.volume!.toStringAsFixed(1)} L'),
            Text('Gas Level: ${trashBin.gazLevel.toStringAsFixed(1)}%'),
            Text('Humidity: ${trashBin.humidity.toStringAsFixed(1)}%'),
            Text('Temperature: ${trashBin.temperature.toStringAsFixed(1)}°C'),
            const Divider(),
            Text('Order in Route: $orderNumber'),
            Text('Distance: ${orderedBin.distance?.toStringAsFixed(1) ?? "N/A"} km'),
            Text('Location: ${trashBin.location.latitude.toStringAsFixed(6)}, ${trashBin.location.longitude.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              if (userLocation?.latitude == geoPoint.latitude && 
                  userLocation?.longitude == geoPoint.longitude) {
                _showTruckInfo(geoPoint);
              } else {
                // Find clicked ordered bin
                final clickedOrderedBin = widget.orderedBins.firstWhere(
                  (bin) => 
                    bin.location.latitude == geoPoint.latitude && 
                    bin.location.longitude == geoPoint.longitude,
                  orElse: () => widget.orderedBins.first,
                );
                
                _showBinInfo(
                  clickedOrderedBin,
                  widget.orderedBins.indexOf(clickedOrderedBin) + 1
                );
              }
            },
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