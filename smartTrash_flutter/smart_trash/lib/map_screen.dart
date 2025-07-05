import 'dart:math';

// lib/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:smart_trash/home_screen.dart' show TrashBin;

class MapScreen extends StatefulWidget {
  final List<TrashBin> trashBins;
  final TrashBin? initialTrashBin;

  const MapScreen({
    Key? key,
    required this.trashBins,
    this.initialTrashBin,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with OSMMixinObserver {
  late MapController mapController;
  final GeoPoint _defaultCenter = GeoPoint(
    latitude: 32.3372,
    longitude: -6.3498,
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
              color: _getMarkerColor(bin.trashLevel),
              size: 40,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding markers: $e");
    }
  }

  Color _getMarkerColor(double level) {
    if (level <= 25) return Colors.green;
    if (level <= 50) return Colors.yellow.shade700;
    if (level <= 75) return Colors.orange;
    return Colors.red;
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (!isReady) return;
    
    try {
      // Add initial delay to ensure map is fully initialized
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (widget.initialTrashBin != null) {
        // Then add markers
        await _addMarkers();
        final initialLocation = GeoPoint(
          latitude: widget.initialTrashBin!.location.latitude,
          longitude: widget.initialTrashBin!.location.longitude,
        );
        
        // First move to location
        await mapController.goToLocation(initialLocation);
        // Wait for movement to complete
        await Future.delayed(const Duration(milliseconds: 300));
        // Finally set zoom
        await mapController.setZoom(zoomLevel: 16);
        
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
          await mapController.goToLocation(GeoPoint(
            latitude: centerLat,
            longitude: centerLon,
          ));
          
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
        await mapController.goToLocation(_defaultCenter);
        await Future.delayed(const Duration(milliseconds: 300));
        await mapController.setZoom(zoomLevel: 14);
      }
    } catch (e) {
      debugPrint("Error in mapIsReady: $e");
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash Bin Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              mapController.currentLocation();
              // to stop the follow of the user position set to false
              mapController.enableTracking(enableStopFollow: false);
            },
          ),
        ],
      ),
      body: OSMFlutter(
        controller: mapController,
        osmOption: OSMOption( // Added OSMOption
          zoomOption: ZoomOption( // Configured zoom options here
            initZoom: 14, // Initial zoom for when no specific bin is selected
            minZoomLevel: 2,
            maxZoomLevel: 19,
          ),
          userLocationMarker: UserLocationMaker(
            personMarker: MarkerIcon(
              assetMarker: AssetMarker(
                image: AssetImage('assets/images/person-location.png'),
                scaleAssetImage: 10, // Adjust scale as needed
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
          // Find the trash bin that matches the clicked geoPoint
          TrashBin? clickedBin;
          for (final bin in widget.trashBins) {
            if (bin.location.latitude == geoPoint.latitude &&
                bin.location.longitude == geoPoint.longitude) {
              clickedBin = bin;
              break;
            }
          }

          if (clickedBin != null) {
            // Show a simple dialog with the trash bin name
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(clickedBin!.name),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Trash Type: ${clickedBin.trashType}'),
                      Text('Trash Level: ${clickedBin.trashLevel}%'),
                      Text('Gaz Level: ${clickedBin.gazLevel}'),
                      Text('Humidity: ${clickedBin.humidity}%'),
                      Text('Temperature: ${clickedBin.temperature}°C'),
                      Text('Weight: ${clickedBin.weight} kg'),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
            debugPrint("Clicked on: ${clickedBin.name} at $geoPoint");
          } else {
            debugPrint("Clicked on unhandled geoPoint: $geoPoint");
          }
        },
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