// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_web.dart';

import 'notification_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'debug_utils.dart';
import 'auth_service.dart';
import 'user_model.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugLogger.addDebugMessage("Flutter Binding Initialized.");

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: firebaseOptionsWeb,
      );
    } else {
      await Firebase.initializeApp();
    }
    DebugLogger.addDebugMessage("Firebase Initialized.");
  } catch (e) {
    DebugLogger.addDebugMessage("Firebase Initialization FAILED: $e");
    return;
  }

  try {
    await NotificationService().initialize();
    DebugLogger.addDebugMessage("NotificationService Initialized.");
  } catch (e) {
    DebugLogger.addDebugMessage("NotificationService Initialization FAILED: $e");
  }

  await ThemeProvider().loadTheme();

  DebugLogger.addDebugMessage("Running App...");
  runApp(MyApp(authService: AuthService()));
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  const MyApp({super.key, required this.authService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NaqiAI',
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: _themeProvider.themeMode,
      home: StreamBuilder<AppUser?>(
        stream: widget.authService.appUserWithRoleStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', height: 80),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Color(0xFF2ECC71)),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            final AppUser currentUser = snapshot.data!;
            NotificationService().initializeTopicsForRole(currentUser.role);
            return HomeScreen(currentUser: currentUser);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}