import 'dart:async';
import 'dart:math';
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
import 'qr_scan_screen.dart';
import 'gamification_screen.dart';

import 'theme_provider.dart';

// Re-export models so existing `show` imports from home_screen still work
export 'package:naqi_ai/location_model.dart';
export 'package:naqi_ai/trash_bin_model.dart';
export 'package:naqi_ai/app_notification_model.dart';

// ── Design palette matching the mockup ──
const _kBg       = Color(0xFFF5F3EE);
const _kCard     = Colors.white;
const _kPrimary  = Color(0xFF2A4A30);
const _kAccent   = Color(0xFF5C8E60);
const _kMuted    = Color(0xFF9EAC9F);
const _kBorder   = Color(0xFFE2DDD5);
const _kTextDark = Color(0xFF2A4A30);
const _kTextGray = Color(0xFF7A8A7C);
const _kAlert    = Color(0xFFB86B2A);
const _kStatsBg  = Color(0xFFDCF0E0);

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

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final userNotificationsRef = FirebaseDatabase.instance
        .ref().child('user_notifications').child(widget.currentUser.uid);

    List<TrashBin> sortedBins = _trashBins.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: isDesktop ? null : _buildAppBar(userNotificationsRef),
      drawer: isDesktop ? null : _buildDrawer(),
      body: isDesktop
          ? Row(
              children: [
                // Persistent sidebar on desktop
                _buildPersistentSidebar(),
                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      _buildDesktopTopBar(userNotificationsRef),
                      Expanded(child: _buildBody(sortedBins, isDesktop: true)),
                    ],
                  ),
                ),
              ],
            )
          : _buildBody(sortedBins, isDesktop: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_trashBins.isEmpty) return;
          Navigator.push(context, _slideRoute(OptimizedRouteScreen(
            allAvailableBins: _trashBins.values.toList(),
            currentUser: widget.currentUser,
          )));
        },
        backgroundColor: _kPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // PERSISTENT SIDEBAR (Desktop only)
  // ══════════════════════════════════════════════
  Widget _buildPersistentSidebar() {
    const sidebarBg      = Color(0xFFF5F3EE);
    const sidebarPale    = Color(0xFFDCF0E0);
    const sidebarPrimary = Color(0xFF2A4A30);
    const sidebarMid     = Color(0xFF5C8E60);
    const sidebarTextSec = Color(0xFF7A8A7C);
    const sidebarBorder  = Color(0xFFE2DDD5);
    const sidebarAlertPale = Color(0xFFF0E8DC);
    const sidebarAlert   = Color(0xFFB86B2A);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder)),
      ),
      child: Column(
        children: [
          // ── Logo header ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sidebarPale,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.eco, size: 20, color: sidebarPrimary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("NaqiAI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: -0.3)),
                    Text(
                      "${widget.currentUser.role.name[0].toUpperCase()}${widget.currentUser.role.name.substring(1)} Panel",
                      style: TextStyle(fontSize: 10, color: sidebarTextSec, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: sidebarBorder),
          const SizedBox(height: 8),
          // ── Nav items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _sidebarNavItem(Icons.home_outlined, 'Home', () {}, sidebarPrimary, sidebarPale, sidebarTextSec, isActive: true),
                _sidebarNavItem(Icons.map_outlined, 'Map', () => navigateToMap(), sidebarPrimary, sidebarPale, sidebarTextSec),
                _sidebarNavItem(Icons.dashboard_outlined, 'Dashboard', () => Navigator.push(context, _slideRoute(const DashboardScreen())), sidebarPrimary, sidebarPale, sidebarTextSec),
                _sidebarNavItem(Icons.analytics_outlined, 'Predictions', () => Navigator.push(context, _slideRoute(const PredictionScreen())), sidebarPrimary, sidebarPale, sidebarTextSec),
                _sidebarNavItem(Icons.image_search_outlined, 'Trash Type AI', () => Navigator.push(context, _slideRoute(const TypePredictionScreen())), sidebarPrimary, sidebarPale, sidebarTextSec),
                _sidebarNavItem(Icons.psychology_outlined, 'Eco-Assistant', () => Navigator.push(context, _slideRoute(const EcoAssistantScreen())), sidebarPrimary, sidebarPale, sidebarTextSec),
                if (widget.currentUser.role == UserRole.worker || widget.currentUser.role == UserRole.admin)
                  _sidebarNavItem(Icons.route_outlined, 'Optimized Route', () {
                    if (_trashBins.isEmpty) return;
                    Navigator.push(context, _slideRoute(OptimizedRouteScreen(allAvailableBins: _trashBins.values.toList(), currentUser: widget.currentUser)));
                  }, sidebarPrimary, sidebarPale, sidebarTextSec),
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: sidebarBorder)),
                if (widget.currentUser.role == UserRole.admin)
                  _sidebarNavItem(Icons.lightbulb_outline, 'Anomaly Insights', () => Navigator.push(context, _slideRoute(const AnomalyRecommendationScreen())), sidebarPrimary, sidebarPale, sidebarTextSec),
                _sidebarNavItem(Icons.settings_outlined, 'Settings', () => Navigator.push(context, _slideRoute(ProfileSettingsScreen(currentUser: widget.currentUser))), sidebarPrimary, sidebarPale, sidebarTextSec),
                if (widget.currentUser.role == UserRole.admin)
                  _sidebarNavItem(Icons.bug_report_outlined, 'Debug Log', () => DebugLogger.showDebugDialog(context), sidebarPrimary, sidebarPale, sidebarTextSec),
              ],
            ),
          ),
          // ── Bottom section ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              Divider(height: 1, color: sidebarBorder),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: sidebarAlertPale, borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.logout_rounded, color: sidebarAlert, size: 20),
                  title: Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sidebarAlert)),
                  onTap: _logout,
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Text("NaqiAI • Waste Management", style: TextStyle(fontSize: 10, color: sidebarTextSec, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
              const SizedBox(height: 16),
            ]),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // DESKTOP TOP BAR
  // ══════════════════════════════════════════════
  Widget _buildDesktopTopBar(DatabaseReference userNotificationsRef) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(bottom: BorderSide(color: _kBorder.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Title
          const Text("Bienvennue ! ", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _kTextDark)),
          const Spacer(),
          // Notifications
          if (widget.currentUser.role == UserRole.worker || widget.currentUser.role == UserRole.admin)
            StreamBuilder(
              stream: userNotificationsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                int count = 0;
                List<AppNotification> notifications = [];
                if (snapshot.hasData && !snapshot.hasError && snapshot.data!.snapshot.value != null) {
                  final rawData = snapshot.data!.snapshot.value;
                  if (rawData is Map) {
                    rawData.forEach((key, value) {
                      if (value is Map) notifications.add(AppNotification.fromMap(key.toString(), value));
                    });
                  }
                  count = notifications.length;
                }
                return IconButton(
                  icon: Badge(
                    label: Text(count.toString(), style: const TextStyle(fontSize: 9)),
                    isLabelVisible: count > 0,
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.notifications_outlined, color: _kTextDark, size: 22),
                  ),
                  onPressed: () => _showNotificationsDialog(userNotificationsRef),
                );
              },
            ),
          const SizedBox(width: 8),
          // User info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: _kPrimary,
                child: const Icon(Icons.person, size: 16, color: Colors.white)),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.currentUser.email?.split('@').first ?? 'User',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextDark)),
                  Text(widget.currentUser.role.name.toUpperCase(),
                      style: TextStyle(fontSize: 9, color: _kMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // APP BAR (mobile only — hamburger + NaqiAI title + bell + avatar)
  // ══════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(DatabaseReference userNotificationsRef) {
    return AppBar(
      backgroundColor: _kBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: _kTextDark, size: 26),
          tooltip: 'Open Menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco, size: 22, color: _kPrimary),
          const SizedBox(width: 8),
          const Text("NaqiAI", style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: -0.3)),
        ],
      ),
      centerTitle: false,
      actions: [
        if (widget.currentUser.role == UserRole.worker || widget.currentUser.role == UserRole.admin)
          StreamBuilder(
            stream: userNotificationsRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              int count = 0;
              List<AppNotification> notifications = [];
              if (snapshot.hasData && !snapshot.hasError && snapshot.data!.snapshot.value != null) {
                final rawData = snapshot.data!.snapshot.value;
                if (rawData is Map) {
                  rawData.forEach((key, value) {
                    if (value is Map) notifications.add(AppNotification.fromMap(key.toString(), value));
                  });
                }
                count = notifications.length;
              }
              return IconButton(
                icon: Badge(
                  label: Text(count.toString(), style: const TextStyle(fontSize: 9)),
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.notifications_outlined, color: _kTextDark, size: 22),
                ),
                onPressed: () => _showNotificationsDialog(userNotificationsRef),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: _kPrimary,
              child: const Icon(Icons.person, size: 18, color: Colors.white)),
            const SizedBox(width: 6),
            Text(
              widget.currentUser.role.name[0].toUpperCase() + widget.currentUser.role.name.substring(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextDark),
            ),
          ]),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // BODY
  // ══════════════════════════════════════════════
  Widget _buildBody(List<TrashBin> sortedBins, {bool isDesktop = false}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.redAccent.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text("Error: $_error", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
        ]),
      ));
    }
    if (sortedBins.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delete_outline, size: 64, color: _kPrimary.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text("No trash bins found", style: TextStyle(fontSize: 16, color: _kMuted)),
      ]));
    }

    final avgLevel = sortedBins.map((b) => b.trashLevel).reduce((a, b) => a + b) / sortedBins.length;
    final critical = sortedBins.where((b) => b.trashLevel >= 80).length;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = isDesktop ? 32 : (screenWidth * 0.085);

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: () async { _binSubscription?.cancel(); _setupDataListener(); },
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
        children: [
          // ── Stats Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: _kStatsBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: _kPrimary.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                _buildStatItem("Nombre Totale des Poubelles", "${sortedBins.length}", Icons.delete_outline, _kPrimary),
                _buildStatDivider(),
                _buildStatItem("Remplissage Moyen ", "${avgLevel.toStringAsFixed(0)}%", Icons.bar_chart, _kPrimary),
                _buildStatDivider(),
                _buildStatItem("Poubelle Pleine", "$critical", Icons.warning_amber_rounded,
                    critical > 0 ? _kAlert : Colors.green.shade700),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ── NaqiAI Service Bar ──
          _buildServiceBar(),
          const SizedBox(height: 32),
          // ── Section Title ──
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text("Waste Disposal Units Overview", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextDark.withOpacity(0.8))),
            ),
          // ── Bin Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final double maxW = constraints.maxWidth;
              int columns;
              double childRatio;
              
              if (maxW > 1400) { columns = 4; childRatio = 0.95; }
              else if (maxW > 1000) { columns = 3; childRatio = 0.90; }
              else if (maxW > 600) { columns = 2; childRatio = 0.85; }
              else { 
                columns = 1; 
                childRatio = 0.82; // Increased height (ratio < 1) to avoid overflow with large elements
              }

              return AnimatedBuilder(
                animation: _gridAnimController,
                builder: (context, _) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: childRatio,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: sortedBins.length,
                    itemBuilder: (context, index) {
                      final stagger = (index / sortedBins.length).clamp(0.0, 0.7);
                      final interval = Interval(stagger, (stagger + 0.3).clamp(0.0, 1.0), curve: Curves.easeOutBack);
                      final animVal = interval.transform(_gridAnimController.value);
                      return Transform.scale(
                        scale: 0.8 + 0.2 * animVal,
                        child: Opacity(opacity: animVal.clamp(0.0, 1.0), child: _buildBinCard(sortedBins[index])),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 44, color: _kPrimary.withValues(alpha: 0.12));
  }

  // ── Service Bar (Scanner + Impact) ──
  Widget _buildServiceBar() {
    return Row(
      children: [
        Expanded(
          child: _serviceCard(
            "SCANNER DE TRI", 
            "Identifier & Déposer", 
            Icons.qr_code_scanner_rounded, 
            _kPrimary, 
            () => Navigator.push(context, _slideRoute(QrScanScreen(currentUser: widget.currentUser))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _serviceCard(
            "MON IMPACT ESG", 
            "Rangs & Récompenses", 
            Icons.emoji_events_rounded, 
            _kAccent, 
            () => Navigator.push(context, _slideRoute(GamificationScreen(currentUser: widget.currentUser))),
          ),
        ),
      ],
    );
  }

  Widget _serviceCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder, width: 1),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5, color: _kTextDark)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: _kTextGray, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // BIN CARD (white card, circular gauge, status badge, metrics)
  // ══════════════════════════════════════════════
  Widget _buildBinCard(TrashBin bin) {
    final Color color = getLevelColor(bin.trashLevel);
    final String status = getTrashStatus(bin.trashLevel);
    final bool isCritical = bin.trashLevel >= 80;

    // Status badge colors
    Color statusBg, statusFg;
    if (bin.trashLevel >= 85) {
      statusBg = const Color(0xFFFDE8E0); statusFg = const Color(0xFFD94E2B);
    } else if (bin.trashLevel >= 50) {
      statusBg = const Color(0xFFFFF4E6); statusFg = const Color(0xFFC77516);
    } else {
      statusBg = const Color(0xFFE8F5E9); statusFg = _kPrimary;
    }

    return GestureDetector(
      onTap: () => _showBinDetailsPopup(bin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cardWidth = constraints.maxWidth;
          
          // Dynamic scaling factors - Increased for larger look
          final double gaugeSize = (cardWidth * 0.55).clamp(100.0, 220.0);
          final double titleSize = (cardWidth * 0.055).clamp(14.0, 20.0);
          final double subTitleSize = (cardWidth * 0.04).clamp(11.0, 15.0);
          final double percentTextSize = (gaugeSize * 0.30).clamp(26.0, 52.0);
          final double statusTextSize = (cardWidth * 0.035).clamp(9.0, 13.0);

          return Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBorder.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(cardWidth * 0.06), // Adaptive padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: name + status badge ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bin.name.toUpperCase(),
                              style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: 0.2, height: 1.2),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              bin.trashType.toUpperCase(),
                              style: TextStyle(fontSize: subTitleSize, fontWeight: FontWeight.w600, color: _kMuted, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(fontSize: statusTextSize, fontWeight: FontWeight.w800, color: statusFg, letterSpacing: 0.3),
                        ),
                      ),
                      if (isCritical) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.warning_amber_rounded, color: _kAlert, size: cardWidth * 0.08),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // ── Center: larger dynamic circular gauge ──
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: gaugeSize,
                      height: gaugeSize,
                      child: CustomPaint(
                        painter: _CircularGaugePainter(bin.trashLevel / 100, color),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${bin.trashLevel.toStringAsFixed(0)}%",
                                style: TextStyle(fontSize: percentTextSize, fontWeight: FontWeight.w900, color: _kTextDark),
                              ),
                              Text("FULL", style: TextStyle(fontSize: gaugeSize * 0.1, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 1.0)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // ── Bottom: adaptive metrics row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _adaptiveMetricChip(Icons.thermostat, "${bin.temperature.toStringAsFixed(0)}°C", cardWidth),
                      _adaptiveMetricChip(Icons.water_drop, "${bin.humidity.toStringAsFixed(0)}%", cardWidth),
                      _adaptiveMetricChip(Icons.air, _gasLabel(bin.gazLevel), cardWidth),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _adaptiveMetricChip(IconData icon, String value, double cardWidth) {
    final double iconSize = (cardWidth * 0.06).clamp(14.0, 20.0);
    final double fontSize = (cardWidth * 0.038).clamp(9.0, 13.0);
    
    return Column(
      children: [
        Icon(icon, size: iconSize, color: _kPrimary.withOpacity(0.5)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: _kTextDark)),
      ],
    );
  }

  String _gasLabel(double gaz) {
    if (gaz < 5) return "Low";
    if (gaz < 15) return "Norm";
    return "High";
  }

  // ══════════════════════════════════════════════
  // BIN DETAILS POPUP (matches 2nd image exactly)
  // ══════════════════════════════════════════════
  void _showBinDetailsPopup(TrashBin bin) {
    final Color color = getLevelColor(bin.trashLevel);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.delete_outline_rounded, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bin.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextDark)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text("${bin.trashLevel.toStringAsFixed(0)}%",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(getTrashStatus(bin.trashLevel).toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 900 ? 500 : double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: bin.trashLevel / 100,
                    minHeight: 8,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text("${bin.trashLevel.toStringAsFixed(0)}% FULL",
                    style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                // Metrics grid-like layout in rows
                _popupMetricRow(Icons.water_drop_outlined, "Humidity", "${bin.humidity.toStringAsFixed(1)}%", Colors.blue),
                _popupMetricRow(Icons.thermostat_outlined, "Temperature", "${bin.temperature.toStringAsFixed(1)}°C", Colors.orange),
                _popupMetricRow(Icons.cloud_outlined, "Gas Level", "${bin.gazLevel.toStringAsFixed(1)}%", Colors.purple),
                _popupMetricRow(Icons.scale_outlined, "Weight", "${bin.weight.toStringAsFixed(1)} kg", Colors.teal),
                _popupMetricRow(Icons.category_outlined, "Trash Type", bin.trashType, Colors.indigo),
                if (bin.volume != null)
                  _popupMetricRow(Icons.inbox_outlined, "Volume", "${bin.volume!.toStringAsFixed(1)} L", Colors.cyan),
                _popupMetricRow(Icons.water, "Water Level", "${bin.waterLevel.toStringAsFixed(1)}%", Colors.lightBlue),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            icon: const Icon(Icons.location_on_outlined, size: 18, color: _kPrimary),
            label: const Text("View on Map", style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _kPrimary.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close", style: TextStyle(color: _kMuted, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _popupMetricRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: _kTextDark)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kTextDark)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // NOTIFICATIONS DIALOG
  // ══════════════════════════════════════════════
  void _showNotificationsDialog(DatabaseReference userNotificationsRef) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StreamBuilder(
          stream: userNotificationsRef.onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            List<AppNotification> notifications = [];
            if (snapshot.hasData && !snapshot.hasError && snapshot.data!.snapshot.value != null) {
              final rawData = snapshot.data!.snapshot.value;
              if (rawData is Map) {
                rawData.forEach((key, value) {
                  if (value is Map) notifications.add(AppNotification.fromMap(key.toString(), value));
                });
              }
            }

            return Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 600),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 15))],
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: _kPrimary, size: 24),
                        const SizedBox(width: 14),
                        const Text(
                          "CENTRE D'ALERTES",
                          style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: _kTextGray, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: _kBorder, height: 1),
                  // Body
                  Flexible(
                    child: _buildNotificationList(notifications),
                  ),
                  const Divider(color: _kBorder, height: 1),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        if (notifications.isNotEmpty)
                          TextButton.icon(
                            onPressed: () async {
                              await NotificationService().clearAllNotifications();
                              // No need to pop, StreamBuilder will update the UI to "Auncue notification"
                            },
                            icon: const Icon(Icons.delete_sweep_outlined, color: _kAlert, size: 18),
                            label: const Text("TOUT EFFACER", style: TextStyle(color: _kAlert, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("TERMINER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: _kMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text("Aucune notification", style: TextStyle(color: _kTextGray, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      );
    }
    notifications.sort((a, b) => b.sentTime.compareTo(a.sentTime));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final n = notifications[index];
        bool isUrgent = n.body.contains("89%") || n.body.contains("full") || n.body.contains("empty");
        
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isUrgent ? _kAlert.withOpacity(0.3) : _kBorder, width: isUrgent ? 1.5 : 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: (isUrgent ? _kAlert : _kPrimary).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isUrgent ? Icons.warning_amber_rounded : Icons.notifications_rounded, color: isUrgent ? _kAlert : _kPrimary, size: 18),
                ),
                if (isUrgent)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kAlert, shape: BoxShape.circle)),
                  ),
              ],
            ),
            title: Text(n.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isUrgent ? _kAlert : _kPrimary)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.body, style: const TextStyle(fontSize: 12, color: _kTextDark, fontWeight: FontWeight.w500, height: 1.4)),
                const SizedBox(height: 4),
                Text(n.sentTime.toString().split('.')[0], style: const TextStyle(fontSize: 10, color: _kTextGray, fontWeight: FontWeight.w600)),
              ],
            ),
            onTap: () {
              if (n.data.containsKey('binId')) {
                handleBinSelection(n.data['binId'].toString());
                Navigator.of(context).pop();
              }
            },
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════
  // DRAWER (sidebar with exact color palette)
  // bg #F5F3EE | surface #FFFFFF | border #E2DDD5
  // pale #DCF0E0 | light #8EBF93 | mid #5C8E60 | primary #2A4A30
  // alert pale #F0E8DC | alert #B86B2A | text sec #7A8A7C
  // ══════════════════════════════════════════════
  Widget _buildDrawer() {
    const drawerBg      = Color(0xFFF5F3EE);
    const drawerSurface = Color(0xFFFFFFFF);
    const drawerBorder  = Color(0xFFE2DDD5);
    const drawerPale    = Color(0xFFDCF0E0);
    const drawerLight   = Color(0xFF8EBF93);
    const drawerMid     = Color(0xFF5C8E60);
    const drawerPrimary = Color(0xFF2A4A30);
    const drawerAlertPale = Color(0xFFF0E8DC);
    const drawerAlert   = Color(0xFFB86B2A);
    const drawerTextSec = Color(0xFF7A8A7C);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 28, 24, 24),
            decoration: const BoxDecoration(
              color: drawerPrimary,
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: drawerLight, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: drawerMid.withOpacity(0.5),
                    child: const Icon(Icons.person, size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                // Email
                Text(
                  widget.currentUser.email ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: drawerLight.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.currentUser.role.name.toUpperCase(),
                    style: TextStyle(color: drawerPale, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Navigation Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _sidebarNavItem(Icons.home_outlined, 'Home', () { Navigator.pop(context); }, drawerPrimary, drawerPale, drawerTextSec, isActive: true),
                _sidebarNavItem(Icons.map_outlined, 'Map', () { Navigator.pop(context); navigateToMap(); }, drawerPrimary, drawerPale, drawerTextSec),
                _sidebarNavItem(Icons.dashboard_outlined, 'Dashboard', () { Navigator.pop(context); Navigator.push(context, _slideRoute(const DashboardScreen())); }, drawerPrimary, drawerPale, drawerTextSec),
                _sidebarNavItem(Icons.analytics_outlined, 'Predictions', () { Navigator.pop(context); Navigator.push(context, _slideRoute(const PredictionScreen())); }, drawerPrimary, drawerPale, drawerTextSec),
                _sidebarNavItem(Icons.image_search_outlined, 'Trash Type AI', () { Navigator.pop(context); Navigator.push(context, _slideRoute(const TypePredictionScreen())); }, drawerPrimary, drawerPale, drawerTextSec),
                _sidebarNavItem(Icons.psychology_outlined, 'Eco-Assistant IA', () { Navigator.pop(context); Navigator.push(context, _slideRoute(const EcoAssistantScreen())); }, drawerPrimary, drawerPale, drawerTextSec),
                if (widget.currentUser.role == UserRole.worker || widget.currentUser.role == UserRole.admin)
                  _sidebarNavItem(Icons.route_outlined, 'Optimized Route', () {
                    Navigator.pop(context);
                    if (_trashBins.isEmpty) return;
                    Navigator.push(context, _slideRoute(OptimizedRouteScreen(allAvailableBins: _trashBins.values.toList(), currentUser: widget.currentUser)));
                  }, drawerPrimary, drawerPale, drawerTextSec),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: drawerBorder),
                ),
                if (widget.currentUser.role == UserRole.admin)
                  _sidebarNavItem(Icons.lightbulb_outline, 'Anomaly Insights', () { Navigator.pop(context); Navigator.push(context, _slideRoute(const AnomalyRecommendationScreen())); }, drawerPrimary, drawerPale, drawerTextSec),
                _sidebarNavItem(Icons.settings_outlined, 'Settings', () { Navigator.pop(context); Navigator.push(context, _slideRoute(ProfileSettingsScreen(currentUser: widget.currentUser))); }, drawerPrimary, drawerPale, drawerTextSec),
                if (widget.currentUser.role == UserRole.admin)
                  _sidebarNavItem(Icons.bug_report_outlined, 'Debug Log', () { Navigator.pop(context); DebugLogger.showDebugDialog(context); }, drawerPrimary, drawerPale, drawerTextSec),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: drawerBorder),
                ),
                // Theme toggle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: drawerSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: drawerBorder),
                  ),
                  child: ListTile(
                    leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: drawerMid, size: 20),
                    title: Text(isDark ? 'Light Mode' : 'Dark Mode', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kTextDark)),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeTrackColor: drawerMid,
                      onChanged: (_) => ThemeProvider().toggleTheme(),
                    ),
                    onTap: () => ThemeProvider().toggleTheme(),
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 4),
                // Logout
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: drawerAlertPale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.logout_rounded, color: drawerAlert, size: 20),
                    title: Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: drawerAlert)),
                    onTap: () { Navigator.pop(context); _logout(); },
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          // ── Footer ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Text(
              "NaqiAI • Waste Management",
              style: TextStyle(fontSize: 10, color: drawerTextSec, fontWeight: FontWeight.w500, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarNavItem(IconData icon, String label, VoidCallback onTap, Color primary, Color pale, Color textSec, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? pale : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: isActive ? primary : textSec),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? primary : _kTextDark,
          ),
        ),
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: pale.withOpacity(0.5),
        splashColor: pale,
      ),
    );
  }

  // ══════════════════════════════════════════════
  // Route Transition
  // ══════════════════════════════════════════════
  Route _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final fade = Tween<double>(begin: 0, end: 1)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: FadeTransition(opacity: fade, child: child));
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}

// ══════════════════════════════════════════════
// Circular Gauge Painter (arc style like mockup)
// ══════════════════════════════════════════════
class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  _CircularGaugePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const startAngle = -pi / 2;
    const sweepFull = 2 * pi;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFFE8E5DF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepFull, false, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepFull * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter old) => old.progress != progress || old.color != color;
}
