import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:naqi_ai/profile_settings_screen.dart';
import 'package:naqi_ai/user_model.dart';
import 'package:naqi_ai/trash_bin_model.dart';
import 'package:naqi_ai/app_notification_model.dart';
import 'package:naqi_ai/level_utils.dart';
import 'map_screen.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'debug_utils.dart';
import 'optimized_route_screen.dart';
import 'app_settings.dart';
import 'prediction_screen.dart';
import 'notification_service.dart';
import 'waste_dashboard.dart';
import 'package:naqi_ai/type_prediction_screen.dart';
import 'anomaly_recommendation_screen.dart';
import 'eco_assistant_screen.dart';

import 'theme_provider.dart';

// Re-export models so existing `show` imports from home_screen still work
export 'package:naqi_ai/location_model.dart';
export 'package:naqi_ai/trash_bin_model.dart';
export 'package:naqi_ai/app_notification_model.dart';

// --- HomeScreen Widget ---
class HomeScreen extends StatefulWidget {
  final AppUser currentUser;
  final List<TrashBin> trashBins;

  const HomeScreen({super.key, required this.currentUser, this.trashBins = const []});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('trash_bins');
  final AuthService _authService = AuthService();

  Map<String, TrashBin> _trashBins = {};
  bool _isLoading = true;
  String? _error;

  StreamSubscription<DatabaseEvent>? _binSubscription;
  late AnimationController _gridAnimController;

  @override
  void initState() {
    super.initState();

    _gridAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Register callbacks for NotificationService (replaces GlobalKey pattern)
    NotificationService().onBinSelected = handleBinSelection;
    NotificationService().onRefreshUI = () {
      if (mounted) setState(() {});
    };
    NotificationService().getCurrentUser = () => widget.currentUser;

    AppSettings().loadSettings().then((_) {
      DebugLogger.addDebugMessage("App settings loaded from within HomeScreen.");
    });

    _setupDataListener();
  }

  @override
  void dispose() {
    _binSubscription?.cancel();
    _gridAnimController.dispose();
    // Unregister notification callbacks
    NotificationService().onBinSelected = null;
    NotificationService().onRefreshUI = null;
    NotificationService().getCurrentUser = null;
    super.dispose();
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
    _binSubscription = _databaseRef.onValue.listen((DatabaseEvent event) {
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
            }
          } else {
            DebugLogger.addDebugMessage("Invalid data type for bin $key: ${value.runtimeType}");
          }
        });

        setState(() {
          _trashBins = updatedBins;
          _isLoading = false;
          _error = null;
        });
        _gridAnimController.forward(from: 0);
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
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 400),
        ),
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
      _slideRoute(MapScreen(
        trashBins: _trashBins.values.toList(),
        initialTrashBin: initialTrashBin,
      )),
    );
    DebugLogger.addDebugMessage("Navigating to Map Screen.");
  }


  Widget _buildBinGridTile(TrashBin bin) {
    final theme = Theme.of(context);
    final Color color = getLevelColor(bin.trashLevel);
    final status = getTrashStatus(bin.trashLevel);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showBinDetailsPopup(bin),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              // ── Header: name ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.05)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  bin.name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // ── Center: gauge ──
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 52, height: 52,
                          child: CircularProgressIndicator(
                            value: bin.trashLevel / 100,
                            strokeWidth: 4.5,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          "${bin.trashLevel.toStringAsFixed(0)}%",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Footer: status + metrics ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 5, top: 3),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMiniMetric(Icons.thermostat, "${bin.temperature.toStringAsFixed(0)}°", Colors.deepOrange),
                        _buildMiniMetric(Icons.water_drop, "${bin.humidity.toStringAsFixed(0)}%", Colors.blue),
                        _buildMiniMetric(Icons.cloud, "${bin.gazLevel.toStringAsFixed(0)}%", Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }

  void _showBinDetailsPopup(TrashBin bin) {
    final theme = Theme.of(context);
    final Color color = getLevelColor(bin.trashLevel);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_outline_rounded, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bin.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text("${bin.trashLevel.toStringAsFixed(0)}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(getTrashStatus(bin.trashLevel), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: bin.trashLevel / 100,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 16),
              _buildMetricRow(Icons.water_drop_outlined, "Humidity", "${bin.humidity.toStringAsFixed(1)}%", Colors.blue),
              _buildMetricRow(Icons.thermostat_outlined, "Temperature", "${bin.temperature.toStringAsFixed(1)}°C", Colors.orange),
              _buildMetricRow(Icons.cloud_outlined, "Gas Level", "${bin.gazLevel.toStringAsFixed(1)}%", Colors.purple),
              _buildMetricRow(Icons.scale_outlined, "Weight", "${bin.weight.toStringAsFixed(1)} kg", Colors.teal),
              _buildMetricRow(Icons.category_outlined, "Trash Type", bin.trashType, Colors.indigo),
              if (bin.volume != null)
                _buildMetricRow(Icons.inbox_outlined, "Volume", "${bin.volume!.toStringAsFixed(1)} L", Colors.cyan),
              _buildMetricRow(Icons.water, "Water Level", "${bin.waterLevel.toStringAsFixed(1)}%", Colors.lightBlue),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              if (bin.location.latitude != 0.0 || bin.location.longitude != 0.0) {
                navigateToMap(bin);
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text("Invalid location for this bin.")),
                );
              }
            },
            icon: Icon(Icons.location_on_outlined, size: 18, color: theme.colorScheme.primary),
            label: Text("View on Map", style: TextStyle(color: theme.colorScheme.primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
            onPressed: notifications.isEmpty ? null : () async {
              await NotificationService().clearAllNotifications();
              if (!context.mounted) return;
              Navigator.of(context).pop();
              DebugLogger.addDebugMessage("Notifications cleared by user (${widget.currentUser.role}).");
            },
            child: const Text("Clear All"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
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
            notification.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.body),
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
              final binId = notification.data['binId'].toString();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userNotificationsRef = FirebaseDatabase.instance
        .ref()
        .child('user_notifications')
        .child(widget.currentUser.uid);

    List<TrashBin> sortedBins = _trashBins.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text("NaqiAI"),
          ],
        ),
        actions: [
          // Notifications Button (only for worker and admin)
          if (widget.currentUser.role == UserRole.worker ||
              widget.currentUser.role == UserRole.admin)
            StreamBuilder(
              stream: userNotificationsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                int notificationCount = 0;
                List<AppNotification> notifications = [];
                if (snapshot.hasData && !snapshot.hasError && snapshot.data!.snapshot.value != null) {
                  final rawData = snapshot.data!.snapshot.value;
                  if (rawData is Map) {
                    rawData.forEach((key, value) {
                      if (value is Map) {
                        notifications.add(AppNotification.fromMap(key.toString(), value));
                      }
                    });
                  }
                  notificationCount = notifications.length;
                }
                return IconButton(
                  icon: Badge(
                    label: Text(notificationCount.toString()),
                    isLabelVisible: notificationCount > 0,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'Show Notifications',
                  onPressed: () => _showNotificationsDialog(notifications),
                );
              },
            ),
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Open Menu',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              );
            },
          ),
        ],
      ),
      endDrawer: _buildDrawer(context, theme, isDark),
      body: _buildBody(sortedBins),
    );
  }

  Widget _buildDrawer(BuildContext context, ThemeData theme, bool isDark) {
    return Drawer(
      child: Column(
        children: [
          // ── Drawer Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.currentUser.email ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.currentUser.role.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          // ── Menu Items ──
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.map_outlined, 'Map', () {
                  Navigator.pop(context);
                  navigateToMap();
                }),
                _drawerItem(Icons.dashboard_outlined, 'Dashboard', () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(const DashboardScreen()));
                }),
                _drawerItem(Icons.analytics_outlined, 'Predictions', () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(const PredictionScreen()));
                }),
                _drawerItem(Icons.image_search_outlined, 'Trash Type AI', () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(const TypePredictionScreen()));
                }),
                _drawerItem(Icons.psychology_outlined, 'Eco-Assistant IA', () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(const EcoAssistantScreen()));
                }),
                if (widget.currentUser.role == UserRole.worker || widget.currentUser.role == UserRole.admin)
                  _drawerItem(Icons.route_outlined, 'Optimized Route', () {
                    Navigator.pop(context);
                    if (_trashBins.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No bins available to optimize route.")),
                      );
                      return;
                    }
                    Navigator.push(context, _slideRoute(
                      OptimizedRouteScreen(
                        allAvailableBins: _trashBins.values.toList(),
                        currentUser: widget.currentUser,
                      ),
                    ));
                  }),
                const Divider(height: 1),
                if (widget.currentUser.role == UserRole.admin)
                  _drawerItem(Icons.lightbulb_outline, 'Anomaly Insights', () {
                    Navigator.pop(context);
                    Navigator.push(context, _slideRoute(const AnomalyRecommendationScreen()));
                  }),
                _drawerItem(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(
                    ProfileSettingsScreen(currentUser: widget.currentUser),
                  ));
                }),
                if (widget.currentUser.role == UserRole.admin)
                  _drawerItem(Icons.bug_report_outlined, 'Debug Log', () {
                    Navigator.pop(context);
                    DebugLogger.showDebugDialog(context);
                  }),
                const Divider(height: 1),
                // ── Theme Toggle ──
                ListTile(
                  leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  title: Text(isDark ? 'Light Mode' : 'Dark Mode'),
                  trailing: Switch.adaptive(
                    value: isDark,
                    activeTrackColor: theme.colorScheme.primary,
                    onChanged: (_) => ThemeProvider().toggleTheme(),
                  ),
                  onTap: () => ThemeProvider().toggleTheme(),
                ),
                const Divider(height: 1),
                _drawerItem(Icons.logout, 'Logout', () {
                  Navigator.pop(context);
                  _logout();
                }, color: Colors.redAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: 0.5),
    );
  }

  // --- Helper to Build Body Content ---
  Widget _buildBody(List<TrashBin> sortedBins) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text("Error: $_error", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
          ],
        ),
      ));
    }
    if (sortedBins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text("No trash bins found", style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    // Stats summary
    final avgLevel = sortedBins.map((b) => b.trashLevel).reduce((a, b) => a + b) / sortedBins.length;
    final critical = sortedBins.where((b) => b.trashLevel >= 80).length;

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: () async {
        DebugLogger.addDebugMessage("Pull to refresh triggered.");
        _binSubscription?.cancel();
        _setupDataListener();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Animated Stats Banner ──
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            ),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(child: _statColumn("Bins", "${sortedBins.length}", Icons.delete_outline)),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(child: _statColumn("Avg Fill", "${avgLevel.toStringAsFixed(0)}%", Icons.bar_chart)),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(child: _statColumn("Critical", "$critical", Icons.warning_amber_rounded)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Quick Actions with animation ──
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 15 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            ),
            child: Row(
              children: [
                Expanded(child: _quickAction(Icons.map_outlined, "Map", () => navigateToMap())),
                const SizedBox(width: 10),
                Expanded(child: _quickAction(Icons.dashboard_outlined, "Dashboard", () {
                  Navigator.push(context, _slideRoute(const DashboardScreen()));
                })),
                const SizedBox(width: 10),
                Expanded(child: _quickAction(Icons.analytics_outlined, "Predict", () {
                  Navigator.push(context, _slideRoute(const PredictionScreen()));
                })),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text("Trash Bins", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          // ── Staggered Animated Bin Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              const double tileSize = 150;
              final int columns = (constraints.maxWidth / tileSize).floor().clamp(2, 6);
              return AnimatedBuilder(
                animation: _gridAnimController,
                builder: (context, _) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 0,
                      mainAxisSpacing: 0,
                    ),
                    itemCount: sortedBins.length,
                    itemBuilder: (context, index) {
                      final staggerDelay = (index / sortedBins.length).clamp(0.0, 0.7);
                      final interval = Interval(staggerDelay, (staggerDelay + 0.3).clamp(0.0, 1.0), curve: Curves.easeOutBack);
                      final animValue = interval.transform(_gridAnimController.value);
                      return Transform.scale(
                        scale: 0.5 + 0.5 * animValue,
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildBinGridTile(sortedBins[index]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.colorScheme.primary.withAlpha(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary.withAlpha(25)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 26),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Route _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final fadeAnimation = Tween<double>(begin: 0, end: 1)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
