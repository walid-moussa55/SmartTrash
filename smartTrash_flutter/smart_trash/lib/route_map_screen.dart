import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:naqi_ai/route_models.dart';
import 'package:naqi_ai/app_settings.dart';
import 'package:naqi_ai/trash_bin_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

// --- Visual Constants (NaqiAI System) ---
const _kBg = Color(0xFFF5F3EE);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2DDD5);
const _kPale = Color(0xFFDCF0E0);
const _kMid = Color(0xFF5C8E60);
const _kPrimary = Color(0xFF2A4A30);
const _kTextSec = Color(0xFF7A8A7C);
const _kAlert = Color(0xFFB86B2A);

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
  final GeoPoint _defaultCenter = GeoPoint(latitude: 32.8811, longitude: -6.9063);
  bool _isLoading = true;
  Map<String, dynamic>? _popupInfo;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('trash_bins');
  Map<String, TrashBin> _trashBinsCache = {};

  @override
  void initState() {
    super.initState();
    mapController = MapController(initPosition: _defaultCenter);
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
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          userLocation = GeoPoint(latitude: position.latitude, longitude: position.longitude);
        });
        await mapController.enableTracking(enableStopFollow: true, disableUserMarkerRotation: true);
      }
    } catch (_) {}
  }

  Future<void> _addMarkers() async {
    try {
      if (widget.orderedBins.isEmpty) return;
      setState(() => _isLoading = true);
      await mapController.clearAllRoads();
      
      for (int i = 0; i < widget.orderedBins.length; i++) {
        final bin = widget.orderedBins[i];
        final geoPoint = GeoPoint(latitude: bin.location.latitude, longitude: bin.location.longitude);
        if (geoPoint.latitude == 0.0 && geoPoint.longitude == 0.0) continue;

        await mapController.addMarker(
          geoPoint,
          markerIcon: MarkerIcon(
            iconWidget: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _kPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: _kSurface, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await _zoomToMarkers();
      await Future.delayed(const Duration(milliseconds: 400));
      await _drawRoute();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _zoomToMarkers() async {
    final List<GeoPoint> points = [];
    if (userLocation != null) points.add(userLocation!);
    points.addAll(widget.orderedBins.map((bin) => GeoPoint(latitude: bin.location.latitude, longitude: bin.location.longitude)).where((p) => p.latitude != 0.0));
    if (points.isEmpty) return;
    
    double minLat = points.first.latitude, maxLat = points.first.latitude, minLon = points.first.longitude, maxLon = points.first.longitude;
    for (var p in points) {
      minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude);
      minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude);
    }
    await mapController.zoomToBoundingBox(BoundingBox(north: maxLat, south: minLat, east: maxLon, west: minLon), paddinInPixel: 70);
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (!isReady) return;
    await Future.delayed(const Duration(milliseconds: 500));
    await _getCurrentLocation();
    await _addMarkers();
  }

  void _showTruckInfo(GeoPoint location) {
    setState(() {
      _popupInfo = {
        'type': 'truck',
        'title': 'CAMION DE COLLECTE',
        'icon': Icons.local_shipping_rounded,
        'color': _kMid,
        'rows': [
          'MAX VOLUME: ${_appSettings.containerVolume?.toStringAsFixed(1) ?? "N/A"} L',
          'MAX POIDS: ${_appSettings.containerWeight?.toStringAsFixed(1) ?? "N/A"} kg',
          'COORD: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
        ],
      };
    });
  }

  Future<void> _drawRoute() async {
    List<GeoPoint> points = [];
    if (userLocation != null) points.add(userLocation!);
    points.addAll(widget.orderedBins.map((bin) => GeoPoint(latitude: bin.location.latitude, longitude: bin.location.longitude)).where((p) => p.latitude != 0.0));
    if (points.length < 2) return;

    final configs = <MultiRoadConfiguration>[];
    for (int i = 0; i < points.length - 1; i++) {
      configs.add(MultiRoadConfiguration(startPoint: points[i], destinationPoint: points[i + 1]));
    }
    await mapController.drawMultipleRoad(configs, commonRoadOption: const MultiRoadOption(roadColor: _kPrimary, roadWidth: 10));
  }

  void _showBinInfo(OrderedBin bin, int order) {
    setState(() {
      _popupInfo = {
        'type': 'bin',
        'title': 'BAC N°$order: ${bin.name}',
        'icon': Icons.delete_rounded,
        'color': bin.capacity > 80 ? _kAlert : _kPrimary,
        'rows': [
          'TYPE: DÉCHETS MIXTES',
          'REMPLISSAGE: ${bin.capacity.toStringAsFixed(0)}%',
          'POIDS: ${bin.weight.toStringAsFixed(1)} kg',
          'LITRES: ${bin.volume.toStringAsFixed(0)} L',
          'DISTANCE PROCHE: ${bin.distance?.toStringAsFixed(1) ?? "N/A"} km',
        ],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: _kSurface,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kPrimary, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: _kSurface.withOpacity(0.9), borderRadius: BorderRadius.circular(20), border: Border.all(color: _kBorder)),
          child: const Text("CONTRÔLE NAVIGATION", style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: _kSurface,
              child: IconButton(
                icon: const Icon(Icons.my_location_rounded, color: _kPrimary, size: 20),
                onPressed: () => mapController.currentLocation(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: mapController,
            osmOption: OSMOption(
              zoomOption: const ZoomOption(initZoom: 14, minZoomLevel: 2, maxZoomLevel: 19),
              showDefaultInfoWindow: false,
              enableRotationByGesture: true,
              userTrackingOption: const UserTrackingOption(enableTracking: true, unFollowUser: false),
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  iconWidget: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _kPrimary, shape: BoxShape.circle, border: Border.all(color: _kSurface, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  iconWidget: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _kPrimary, shape: BoxShape.circle, border: Border.all(color: _kSurface, width: 3)),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
            onGeoPointClicked: (geoPoint) async {
              if (_popupInfo != null) { setState(() => _popupInfo = null); return; }
              if (userLocation?.latitude == geoPoint.latitude) {
                _showTruckInfo(geoPoint);
              } else {
                final idx = widget.orderedBins.indexWhere((b) => b.location.latitude == geoPoint.latitude);
                if (idx != -1) _showBinInfo(widget.orderedBins[idx], idx + 1);
              }
            },
          ),
          if (_popupInfo != null)
            Positioned(
              left: 20, right: 20, bottom: 40,
              child: _buildPremiumPopup(),
            ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildPremiumPopup() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: (_popupInfo!['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(_popupInfo!['icon'] as IconData, color: _popupInfo!['color'] as Color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(_popupInfo!['title'] as String, style: const TextStyle(color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              IconButton(onPressed: () => setState(() => _popupInfo = null), icon: const Icon(Icons.close_rounded, color: _kTextSec))
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: (_popupInfo!['rows'] as List<String>).map((row) => _buildPopupBadge(row)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder.withOpacity(0.5))),
      child: Text(text, style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  @override
  void dispose() {
    mapController.removeObserver(this);
    mapController.dispose();
    super.dispose();
  }
}