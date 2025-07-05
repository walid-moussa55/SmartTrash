import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:smart_trash/profile_settings_screen.dart';
import 'package:smart_trash/user_model.dart';
import 'map_screen.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'debug_utils.dart';
import 'optimized_route_screen.dart';
import 'app_settings.dart';
import 'prediction_screen.dart'; // Assuming this is your general prediction screen
import 'notification_service.dart';
import 'waste_dashboard.dart';
import 'package:smart_trash/type_prediction_screen.dart'; // Your specific image prediction screen
import 'final_rapport_generation_screen.dart'; // Assuming this is your report generation screen
import 'anomaly_recommendation_screen.dart'; // Assuming this is your anomaly recommendation screen
import 'patterns_analysis_viewer_screen.dart'; // Assuming this is your patterns analysis screen


// --- Data Model for Location ---
class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromMap(Map<dynamic, dynamic> data) {
    return Location(
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// --- Data Model for a Trash Bin (Updated) ---
class TrashBin {
  final String id; // e.g., "trash_1"
  final String name;
  final double humidity;
  final double temperature;
  final double trashLevel;
  final double gazLevel;
  final Location location;
  final String trashType;
  final double weight;
  final double? volume;
  final double waterLevel;

  TrashBin({
    required this.id,
    required this.name,
    required this.humidity,
    required this.trashLevel,
    required this.gazLevel,
    required this.location,
    required this.trashType,
    required this.weight,
    this.volume,
    this.temperature = 0.0,
    this.waterLevel = 0.0,
  });

  factory TrashBin.fromMap(String id, Map<dynamic, dynamic> data) {
    final defaultLocation = Location(latitude: 0.0, longitude: 0.0);
    Location parsedLocation = defaultLocation;
    if (data['location'] != null && data['location'] is Map) {
      try {
        parsedLocation = Location.fromMap(data['location']);
      } catch (e) {
        DebugLogger.addDebugMessage("Error parsing location for $id: $e");
        print("Error parsing location for $id: $e");
      }
    } else {
      DebugLogger.addDebugMessage("Location data missing or invalid for $id.");
      print("Location data missing or invalid for $id.");
    }

    return TrashBin(
      id: id,
      name: data['name']?.toString() ?? 'Trash Bin ${id.split('_').last}',
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      trashLevel: (data['trash_level'] as num?)?.toDouble() ?? 0.0,
      gazLevel: (data['gaz_level'] as num?)?.toDouble() ?? 0.0,
      location: parsedLocation,
      trashType: data['trash_type']?.toString() ?? 'Unknown',
      weight: (data['weight'] as num?)?.toDouble() ?? 0.0,
      volume: (data['volume'] as num?)?.toDouble(),
      waterLevel: (data['water_level'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// --- Data Model for stored notifications ---
class AppNotification {
  final String key;
  final String title;
  final String body;
  final DateTime sentTime;
  final Map<String, dynamic> data;

  AppNotification({
    required this.key,
    required this.title,
    required this.body,
    required this.sentTime,
    required this.data,
  });

  factory AppNotification.fromMap(String key, Map<dynamic, dynamic> value) {
    return AppNotification(
      key: key,
      title: value['title'] ?? 'No Title',
      body: value['body'] ?? 'No Body',
      sentTime: DateTime.fromMillisecondsSinceEpoch(
          value['sentTime'] ?? DateTime.now().millisecondsSinceEpoch),
      data: Map<String, dynamic>.from(value['data'] ?? {}),
    );
  }
}

// --- HomeScreen Widget ---
class HomeScreen extends StatefulWidget {
  final AppUser currentUser;
  final List<TrashBin> trashBins;

  const HomeScreen({Key? key, required this.currentUser, this.trashBins = const []}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('trash_bins');
  final AuthService _authService = AuthService();

  Map<String, TrashBin> _trashBins = {};
  bool _isLoading = true;
  String? _error;


  @override
  void initState() {
    super.initState();

    AppSettings().loadSettings().then((_) {
      DebugLogger.addDebugMessage("App settings loaded from within HomeScreen.");
    });

    _setupDataListener();
  }

  void handleBinSelection(String binId) {
    final selectedBin = _trashBins[binId];
    if (selectedBin != null) {
      navigateToMap(selectedBin);
    } else {
      DebugLogger.addDebugMessage("Bin with ID $binId not found");
    }
  }

  void _setupDataListener() {
    _databaseRef.onValue.listen((DatabaseEvent event) {
      if (!mounted) return;

      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final Map<String, TrashBin> updatedBins = {};
        data.forEach((key, value) {
          if (value is Map) {
            try {
              updatedBins[key.toString()] = TrashBin.fromMap(key.toString(), value);
            } catch (e) {
              DebugLogger.addDebugMessage("Error parsing bin data for $key: $e");
              print("Error parsing bin data for $key: $e");
            }
          } else {
            DebugLogger.addDebugMessage("Invalid data type for bin $key: ${value.runtimeType}");
            print("Invalid data type for bin $key: ${value.runtimeType}");
          }
        });

        setState(() {
          _trashBins = updatedBins;
          _isLoading = false;
          _error = null;
        });
        DebugLogger.addDebugMessage("Trash bin data updated. Count: ${updatedBins.length}");
      } else {
        setState(() {
          _trashBins = {};
          _isLoading = false;
          _error = data == null ? "No data found at 'trash_bins'." : "Invalid data format received.";
        });
        DebugLogger.addDebugMessage("Received null or invalid data from 'trash_bins'.");
      }
    }, onError: (error) {
      if (!mounted) return;
      DebugLogger.addDebugMessage("Error fetching trash bin data: $error");
      print("Error fetching trash bin data: $error");
      setState(() {
        _isLoading = false;
        _error = "Failed to load data. Check connection.";
      });
    });
  }

  void _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (Route<dynamic> route) => false,
      );
      DebugLogger.addDebugMessage("User logged out.");
    }
  }

  void navigateToMap([TrashBin? initialTrashBin]) {
    if (_trashBins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No trash bin locations to show on map.")),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapScreen(
          trashBins: _trashBins.values.toList(),
          initialTrashBin: initialTrashBin,
        ),
      ),
    );
    DebugLogger.addDebugMessage("Navigating to Map Screen.");
  }


  Color _getLevelColor(double level) {
    if (level <= 25) return Colors.green;
    if (level <= 50) return Colors.yellow.shade700;
    if (level <= 75) return Colors.orange;
    return Colors.red;
  }

  String _getTrashStatus(double level) {
    if (level < 50) return "Okay";
    if (level < 85) return "Getting Full";
    return "Needs Emptying Soon";
  }

  Widget _buildExpandableTrashCard(TrashBin bin) {
    Color color = _getLevelColor(bin.trashLevel);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(Icons.delete_outline, color: color, size: 40),
        title: Text(
          bin.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "${bin.trashLevel.toStringAsFixed(1)}% Full",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: bin.trashLevel / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                const SizedBox(height: 15),
                _buildInfoRow(Icons.info_outline, "Status", _getTrashStatus(bin.trashLevel)),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.water_drop_outlined, "Humidity", "${bin.humidity.toStringAsFixed(1)} %"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.thermostat_outlined, "Temperature", "${bin.temperature.toStringAsFixed(1)} °C"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.cloud_outlined, "Gas Level", "${bin.gazLevel.toStringAsFixed(1)} %"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.scale_outlined, "Weight", "${bin.weight.toStringAsFixed(1)} kg"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.category_outlined, "Trash Type", bin.trashType),
                const SizedBox(height: 8),
                if (bin.volume != null)
                  _buildInfoRow(Icons.inbox_outlined, "Volume", "${bin.volume!.toStringAsFixed(1)} L"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.water, "Water Level", "${bin.waterLevel.toStringAsFixed(1)} %"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    const Text("Location: ", style: TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Text(
                        "Lat: ${bin.location.latitude.toStringAsFixed(4)}, Lon: ${bin.location.longitude.toStringAsFixed(4)}",
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (bin.location.latitude != 0.0 || bin.location.longitude != 0.0) {
                          navigateToMap(bin);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invalid location for this trash bin.")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text("Go to", style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
        onExpansionChanged: (isExpanded) {
          DebugLogger.addDebugMessage("${bin.name} (${bin.id}) expansion changed: $isExpanded");
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }


  void _showNotificationsDialog(List<AppNotification> notifications) {
    DebugLogger.addDebugMessage(
      "Opening notifications dialog. Count: ${notifications.length}"
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Notifications ${widget.currentUser.role == UserRole.admin ? '(Admin)' : '(Worker)'}"
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _buildNotificationList(notifications),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            child: const Text("Clear All"),
            onPressed: notifications.isEmpty ? null : () async {
              await NotificationService().clearAllNotifications();
              if (!context.mounted) return;
              print("Notifications : ${notifications.length} cleared.");
              Navigator.of(context).pop();
              DebugLogger.addDebugMessage("Notifications cleared by user (${widget.currentUser.role}).");
            },
          ),
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    DebugLogger.addDebugMessage(
      "Notifications dialog shown to ${widget.currentUser.role}"
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return const Center(
        child: Text(
          "No notifications",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    notifications.sort((a, b) => b.sentTime.compareTo(a.sentTime));

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return ListTile(
          title: Text(
            notification.title ?? 'No title',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.body ?? 'No message'),
              Text(
                notification.sentTime.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          leading: Icon(
            Icons.notifications,
            color: Theme.of(context).primaryColor,
          ),
          onTap: () {
            if (notification.data.containsKey('binId')) {
              final binId = notification.data['binId'];
              handleBinSelection(binId);
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final userNotificationsRef = FirebaseDatabase.instance
        .ref()
        .child('user_notifications')
        .child(widget.currentUser.uid);

    List<TrashBin> sortedBins = _trashBins.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Trash Monitor"),
        backgroundColor: Theme.of(context).primaryColor, // Consistent app bar color
        foregroundColor: Colors.white, // White text/icons
        elevation: 4,
        actions: [
          // Notifications Button (only for worker and admin) - KEPT IN APPBAR
          if (widget.currentUser.role == UserRole.worker ||
              widget.currentUser.role == UserRole.admin)
            StreamBuilder(
              stream: userNotificationsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                int notificationCount = 0;
                List<AppNotification> notifications = [];
                if (snapshot.hasData && !snapshot.hasError && snapshot.data!.snapshot.value != null) {
                  final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  data.forEach((key, value) {
                    notifications.add(AppNotification.fromMap(key, value));
                  });
                  notificationCount = notifications.length;
                }
                return IconButton(
                  icon: Badge(
                    label: Text(notificationCount.toString()),
                    isLabelVisible: notificationCount > 0,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'Show Notifications',
                  onPressed: () => _showNotificationsDialog(notifications),
                );
              },
            ),
          // More icon to open the drawer on the right
          Builder( // Use Builder to get a context that can find the Scaffold
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open Menu',
                onPressed: () => Scaffold.of(context).openEndDrawer(), // Open end drawer
              );
            },
          ),
        ],
      ),
      endDrawer: Drawer( // NEW: Add a Drawer
        backgroundColor: Colors.blueGrey[900], // Dark background for the drawer
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader( // Custom header for the drawer
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(height: 10),
                  Text(
                    widget.currentUser.email ?? '', // FIX: Added null check here
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Role: ${widget.currentUser.role.toString().split('.').last}', // Display role
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Map Option
            ListTile(
              leading: Icon(Icons.map_outlined, color: Colors.white70),
              title: Text('Map', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                navigateToMap();
              },
            ),
            // Dashboard Option
            ListTile(
              leading: Icon(Icons.dashboard_outlined, color: Colors.white70),
              title: Text('Dashboard', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DashboardScreen()),
                );
              },
            ),
            // General Prediction Screen (if it's different from Type Prediction)
            // If prediction_screen.dart is just a placeholder, you can remove this.
            ListTile(
              leading: Icon(Icons.analytics, color: Colors.white70),
              title: Text('General Prediction', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PredictionScreen()),
                );
              },
            ),
            // Type Prediction Screen (Image-based)
            ListTile(
              leading: Icon(Icons.image_search, color: Colors.white70),
              title: Text('Trash Type Prediction', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TypePredictionScreen()),
                );
              },
            ),
            // Optimized Route (Worker/Admin only)
            if (widget.currentUser.role == UserRole.worker ||
                widget.currentUser.role == UserRole.admin)
              ListTile(
                leading: Icon(Icons.route_outlined, color: Colors.white70),
                title: Text('Optimized Collection Route', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  if (_trashBins.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No bins available to optimize route.")),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OptimizedRouteScreen(
                        allAvailableBins: _trashBins.values.toList(),
                        currentUser: widget.currentUser,
                      ),
                    ),
                  );
                },
              ),
            Divider(color: Colors.white54), // Separator
            // NEW: Report Generation Option for admin only
            if (widget.currentUser.role == UserRole.admin)
              ListTile(
                leading: Icon(Icons.receipt_long_outlined, color: Colors.white70),
                title: Text('Generate Report', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FinalRapportGenerationScreen()),
                  );
                },
              ),
            // NEW: Anomaly Recommendations Option for admin only
            if (widget.currentUser.role == UserRole.admin)
              // NOUVEAU: Option de Recommandations d'Anomalies
              ListTile(
                leading: Icon(Icons.lightbulb_outline, color: Colors.white70), // Icône suggestive
                title: Text("Recommandations d'Anomalies", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context); // Fermer le tiroir
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AnomalyRecommendationScreen()),
                  );
                },
              ),
            if (widget.currentUser.role == UserRole.admin)
              // NEW: Analyse des patterns (Updated to new screen)
              ListTile(
                leading: Icon(Icons.bar_chart_outlined, color: Colors.white70),
                title: Text('Analyse des Patterns', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PatternsAnalysisViewerScreen(), // Navigate to the new combined screen
                    ),
                  );
                },
              ),
              Divider(color: Colors.white54), // Separator
            // Settings
            ListTile(
              leading: Icon(Icons.settings, color: Colors.white70),
              title: Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
            ),
            // Debug Log (Admin only)
            if (widget.currentUser.role == UserRole.admin)
              ListTile(
                leading: Icon(Icons.bug_report_outlined, color: Colors.white70),
                title: Text('Debug Log', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  DebugLogger.showDebugDialog(context);
                },
              ),
            // Logout
            ListTile(
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                _logout();
              },
            ),
          ],
        ),
      ),
      body: _buildBody(sortedBins),
    );
  }

  // --- Helper to Build Body Content ---
  Widget _buildBody(List<TrashBin> sortedBins) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("Error: $_error", style: const TextStyle(color: Colors.red)),
      ));
    }
    if (sortedBins.isEmpty) {
      return const Center(child: Text("No trash bins found."));
    }

    return RefreshIndicator(
      onRefresh: () async {
        DebugLogger.addDebugMessage("Pull to refresh triggered.");
        setState(() { _isLoading = true; _error = null; });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sortedBins.length,
        itemBuilder: (context, index) {
          return _buildExpandableTrashCard(sortedBins[index]);
        },
      ),
    );
  }
}
