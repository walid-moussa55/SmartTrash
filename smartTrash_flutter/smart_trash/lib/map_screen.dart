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

  late MapController mapController;
  bool _routeDrawn = false;
  TrashBin? _selectedBin;
  String? _routeInfo;
  final GeoPoint _defaultCenter = GeoPoint(latitude: 32.8811, longitude: -6.9063);

  @override
  void initState() {
    super.initState();
    mapController = MapController(initPosition: _defaultCenter);
    mapController.addObserver(this);
    mapController.enableTracking(enableStopFollow: true);
  }

  Future<void> _addMarkers() async {
    try {
      for (final bin in widget.trashBins) {
        if (bin.location.latitude == 0.0 && bin.location.longitude == 0.0) continue;
        final geoPoint = GeoPoint(latitude: bin.location.latitude, longitude: bin.location.longitude);
        
        await mapController.addMarker(
          geoPoint,
          markerIcon: MarkerIcon(
            icon: Icon(Icons.location_on_rounded, color: getLevelColor(bin.trashLevel), size: 48),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding markers: $e");
    }
  }

  Future<void> _drawRouteToTarget(TrashBin bin) async {
    try {
      // Nettoyer les anciens trajets s'ils existent
      if (_routeDrawn) {
        await mapController.removeLastRoad();
      }

      final userLoc = await mapController.myLocation();
      final targetLoc = GeoPoint(
        latitude: bin.location.latitude,
        longitude: bin.location.longitude,
      );

      await mapController.drawMultipleRoad(
        [MultiRoadConfiguration(startPoint: userLoc, destinationPoint: targetLoc)],
        commonRoadOption: MultiRoadOption(roadColor: Colors.blueAccent, roadWidth: 8),
      );

      final dLat = (targetLoc.latitude - userLoc.latitude) * 111320;
      final dLon = (targetLoc.longitude - userLoc.longitude) * 111320 * cos(userLoc.latitude * pi / 180);
      final distanceKm = sqrt(dLat * dLat + dLon * dLon) / 1000;

      setState(() {
        _routeDrawn = true;
        _routeInfo = distanceKm >= 1 ? '${distanceKm.toStringAsFixed(1)} km' : '${(distanceKm * 1000).toStringAsFixed(0)} m';
      });

      await mapController.zoomToBoundingBox(
        BoundingBox(
          north: max(userLoc.latitude, targetLoc.latitude) + 0.005,
          south: min(userLoc.latitude, targetLoc.latitude) - 0.005,
          east: max(userLoc.longitude, targetLoc.longitude) + 0.005,
          west: min(userLoc.longitude, targetLoc.longitude) - 0.005,
        ),
        paddinInPixel: 100,
      );
    } catch (e) {
      debugPrint("Error drawing route: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Géolocalisation nécessaire pour l\'itinéraire.')),
        );
      }
    }
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (!isReady) return;
    await Future.delayed(const Duration(milliseconds: 600));
    await _addMarkers();
    
    if (widget.initialTrashBin != null) {
      final loc = GeoPoint(latitude: widget.initialTrashBin!.location.latitude, longitude: widget.initialTrashBin!.location.longitude);
      await mapController.moveTo(loc, animate: true);
      await mapController.setZoom(zoomLevel: 16);
      if (widget.showRoute) await _drawRouteToTarget(widget.initialTrashBin!);
    } else if (widget.trashBins.isNotEmpty) {
      final valid = widget.trashBins.where((b) => b.location.latitude != 0.0).toList();
      if (valid.isNotEmpty) {
        final centerLat = valid.map((b) => b.location.latitude).reduce((a, b) => a + b) / valid.length;
        final centerLon = valid.map((b) => b.location.longitude).reduce((a, b) => a + b) / valid.length;
        await mapController.moveTo(GeoPoint(latitude: centerLat, longitude: centerLon), animate: true);
        await mapController.setZoom(zoomLevel: 14);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final targetBin = widget.initialTrashBin;
    final isRouteMode = widget.showRoute && targetBin != null;

    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                _buildMapWidget(),
                _buildOverlayButtons(),
                if (!isDesktop && _selectedBin != null) _buildMobileBottomPanel(),
                if (isRouteMode && _routeDrawn) _buildRouteBanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    return OSMFlutter(
      controller: mapController,
      osmOption: OSMOption(
        zoomOption: ZoomOption(initZoom: 14, minZoomLevel: 2, maxZoomLevel: 19),
        userLocationMarker: UserLocationMaker(
          personMarker: MarkerIcon(icon: Icon(Icons.person_pin_circle_rounded, color: Colors.blue, size: 48)),
          directionArrowMarker: MarkerIcon(icon: Icon(Icons.navigation_rounded, color: Colors.blue, size: 48)),
        ),
      ),
      onGeoPointClicked: (geoPoint) {
        final clicked = widget.trashBins.firstWhere(
          (b) => b.location.latitude == geoPoint.latitude && b.location.longitude == geoPoint.longitude,
          orElse: () => widget.trashBins.first,
        );
        setState(() => _selectedBin = clicked);
      },
    );
  }

  Widget _buildOverlayButtons() {
    return Positioned(
      top: 50,
      left: 20,
      child: Column(
        children: [
          _buildCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          _buildCircleButton(
            icon: Icons.my_location_rounded,
            onTap: () => mapController.currentLocation(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 52, width: 52,
          decoration: BoxDecoration(
            color: _kSurface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: Icon(icon, color: _kPrimary, size: 24),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 400,
      color: _kSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Text('TRASH BIN MAP', style: TextStyle(color: _kPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ),
          Expanded(
            child: _selectedBin == null 
              ? _buildBinList() 
              : _buildBinDetailPanel(_selectedBin!),
          ),
        ],
      ),
    );
  }

  Widget _buildBinList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.trashBins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final bin = widget.trashBins[index];
        return ListTile(
          onTap: () {
            setState(() => _selectedBin = bin);
            mapController.moveTo(GeoPoint(latitude: bin.location.latitude, longitude: bin.location.longitude), animate: true);
          },
          tileColor: _kBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Icon(Icons.auto_delete_rounded, color: getLevelColor(bin.trashLevel)),
          title: Text(bin.name, style: const TextStyle(fontWeight: FontWeight.w700, color: _kTextDark)),
          subtitle: Text('${bin.trashType} • ${bin.trashLevel.toStringAsFixed(0)}%', style: const TextStyle(color: _kTextSec)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _kTextSec),
        );
      },
    );
  }

  Widget _buildBinDetailPanel(TrashBin bin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _selectedBin = null), icon: const Icon(Icons.close_rounded, color: _kTextSec)),
              const Spacer(),
              Text('DÉTAILS', style: TextStyle(color: _kTextSec, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                _buildInfoRow(Icons.label_rounded, 'Nom', bin.name),
                _buildInfoRow(Icons.category_rounded, 'Type', bin.trashType),
                _buildInfoRow(Icons.analytics_rounded, 'Remplissage', '${bin.trashLevel}%', color: getLevelColor(bin.trashLevel)),
                _buildInfoRow(Icons.air_rounded, 'Gaz', '${bin.gazLevel}'),
                _buildInfoRow(Icons.thermostat_rounded, 'Temp.', '${bin.temperature}°C'),
                _buildInfoRow(Icons.water_drop_rounded, 'Humidité', '${bin.humidity}%'),
                _buildInfoRow(Icons.monitor_weight_rounded, 'Poids', '${bin.weight} kg'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _drawRouteToTarget(bin),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('ITINÉRAIRE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? _kTextSec),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: _kTextSec, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(color: color ?? _kTextDark, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildMobileBottomPanel() {
    return Positioned(
      left: 16, right: 16, bottom: 20,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 8,
        color: _kSurface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
            _buildBinDetailPanel(_selectedBin!),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteBanner() {
    return Positioned(
      left: 20, right: 20, bottom: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurface, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.directions_rounded, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ITINÉRAIRE', style: TextStyle(color: _kTextSec, fontSize: 10, fontWeight: FontWeight.w800)),
                Text(_routeInfo ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kTextDark)),
              ]),
            ),
            IconButton(onPressed: () => setState(() => _routeDrawn = false), icon: const Icon(Icons.close_rounded, color: _kTextSec)),
          ],
        ),
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