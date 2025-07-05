// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // <--- ADD THIS IMPORT
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_web.dart'; // <-- Import the generated file

// No direct FirebaseAuth import needed here if AuthService handles it

import 'notification_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'debug_utils.dart';
import 'auth_service.dart'; // Import your AuthService
import 'user_model.dart';   // Import AppUser
import 'app_settings.dart'; // Import AppSettings

final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();
// You might need a GlobalKey for NavigatorState if navigating from NotificationService without context
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugLogger.addDebugMessage("Flutter Binding Initialized.");

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: firebaseOptionsWeb, // <-- Use the imported constant
      );
    } else {
      await Firebase.initializeApp();
    }
    DebugLogger.addDebugMessage("Firebase Initialized.");
  } catch (e) {
    DebugLogger.addDebugMessage("Firebase Initialization FAILED: $e");
    print("Firebase Initialization FAILED: $e");
    return;
  }

  try {
    await NotificationService().initialize();
    DebugLogger.addDebugMessage("NotificationService Initialized.");
  } catch (e) {
    DebugLogger.addDebugMessage("NotificationService Initialization FAILED: $e");
  }

  DebugLogger.addDebugMessage("Running App...");
  runApp(MyApp(authService: AuthService())); // Pass AuthService instance
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // navigatorKey: navigatorKey, // If using for global navigation
      debugShowCheckedModeBanner: false,
      title: 'Smart Trash',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder<AppUser?>( // Use AppUser from your model
        stream: authService.appUserWithRoleStream, // Use the new stream
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            final AppUser currentUser = snapshot.data!;
            // Pass the AppUser (which includes the role) to HomeScreen
            // HomeScreen then needs to be adapted to accept AppUser
            // For now, we assume HomeScreen is adapted or we pass only needed parts.
            // For ProfileSettingsScreen, this AppUser object will be crucial.
            // Initialize topics when user role is known
            NotificationService().initializeTopicsForRole(currentUser.role);
            return HomeScreen(key: homeScreenKey , currentUser: currentUser ); // Modify HomeScreen to accept AppUser
          }
          return LoginScreen();
        },
      ),
    );
  }
}