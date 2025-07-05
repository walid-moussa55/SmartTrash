// lib/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // <<< ADD THIS IMPORT
import 'package:flutter/material.dart'; // For GlobalKey access if needed later
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'debug_utils.dart'; // Your debug logger
import 'main.dart'; // To access homeScreenKey (ensure this import path is correct)
import 'package:flutter/material.dart';
import 'profile_settings_screen.dart'; // Add this import
import 'user_model.dart'; // Import UserRole if needed
import 'package:firebase_database/firebase_database.dart'; // <<< ADD THIS IMPORT
import 'auth_service.dart'; // <<< ADD THIS IMPORT

// Define the FCM topic name as a constant
const String TRASH_ALERTS_TOPIC =
    'trash_alerts'; // Use the same topic name as your backend
const String TRASH_ALERTS_TOPIC_GAS =
    'trash_alerts_gas'; // Optional: Use a different topic for gas alerts
const String TRASH_ALERTS_TOPIC_EMERGENCY =
    'trash_alerts_emergency'; // Optional: Use a different topic for emergency alerts

// Background message handler MUST be a top-level function
// It handles messages received when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need Firebase services in background, initialize here minimally
  await Firebase.initializeApp(); // Often not needed just for notification display

  // If you are using Firebase Realtime Database or Firestore in the background
  // handler, you MUST initialize Firebase here.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Use your generated options

  print("Handling a background message: ${message.messageId}");
  DebugLogger.addDebugMessage(
    "Background message handled: ${message.notification?.title ?? message.messageId}",
  );

  final String? userId = AuthService().currentFirebaseAuthUser?.uid;

  if (userId != null && message.notification != null) {
    final dbRef = FirebaseDatabase.instance.ref('user_notifications/$userId');
    final newNotificationRef = dbRef.push();
    await newNotificationRef.set({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'sentTime': message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        'data': message.data,
        'read': false,
    });
    DebugLogger.addDebugMessage("Saved background notification to DB for user $userId.");
  }
}

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Flag to ensure initialization happens only once
  bool _initialized = false;

  // NEW METHOD to save a notification to the database
  Future<void> _saveNotificationToDB(RemoteMessage message) async {
    // Get the current authenticated user's ID
    final String? userId = AuthService().currentFirebaseAuthUser?.uid;
    if (userId == null) {
      DebugLogger.addDebugMessage("Cannot save notification, user not logged in.");
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref('user_notifications/$userId');
    final newNotificationRef = dbRef.push(); // Creates a new unique ID

    await newNotificationRef.set({
      'title': message.notification?.title,
      'body': message.notification?.body,
      'sentTime': message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'data': message.data,
      'read': false, // Optional: for tracking read/unread status
    });
    DebugLogger.addDebugMessage("Saved notification ${message.messageId} to DB for user $userId.");
  }

  // --- Initialization Method ---
  Future<void> initialize() async {
    if (_initialized) {
      DebugLogger.addDebugMessage("NotificationService already initialized.");
      return;
    }
    
    DebugLogger.addDebugMessage("Initializing NotificationService...");

    if (kIsWeb) {
      await _requestWebNotificationPermissions();
      await _initializeWebNotifications();
    } else {
      await _requestPermissions();
      await _initializeLocalNotifications();
    }

    // Setup message handlers
    _setupMessageHandlers();

    // Subscribe to topics (if not web)
    if (!kIsWeb) {
      await subscribeToTopic(TRASH_ALERTS_TOPIC);
      DebugLogger.addDebugMessage(
        "Subscribed to topic: $TRASH_ALERTS_TOPIC",
      );
      // Optional: Subscribe to additional topics if needed
      await subscribeToTopic(TRASH_ALERTS_TOPIC_GAS);
      DebugLogger.addDebugMessage(
        "Subscribed to topic: $TRASH_ALERTS_TOPIC_GAS",
      );
      await subscribeToTopic(TRASH_ALERTS_TOPIC_EMERGENCY);
      DebugLogger.addDebugMessage(
        "Subscribed to topic: $TRASH_ALERTS_TOPIC_EMERGENCY",
      );
    } else {
      DebugLogger.addDebugMessage("Skipping topic subscription on web client.");
    }
    _initialized = true;
    DebugLogger.addDebugMessage(
      "NotificationService Initialization Complete for ${kIsWeb ? 'Web' : 'Native'}",
    );
  }

  // --- Helper: Request Permissions ---
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      DebugLogger.addDebugMessage('✅ Notification permission granted.');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      DebugLogger.addDebugMessage(
        '✅ Notification permission granted provisionally.',
      );
    } else {
      DebugLogger.addDebugMessage(
        '❌ User declined or has not accepted notification permission',
      );
    }
  }

  Future<void> _requestWebNotificationPermissions() async {
    if (kIsWeb) {
      final status = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        sound: true,
      );
      
      DebugLogger.addDebugMessage(
        'Web notification permission status: ${status.authorizationStatus}'
      );
    }
  }

  // --- Helper: Initialize Local Notifications ---
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Default app icon

    const DarwinInitializationSettings
    initializationSettingsIOS = DarwinInitializationSettings(
      // requestAlertPermission, requestBadgePermission, requestSoundPermission defaults true
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onSelectNotification,
    );

    // --- Create Android Notification Channel ---
    // Crucial for Android 8.0+
    // Use a meaningful channel ID, NOT an FCM token.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // Unique ID for the channel (e.g., 'trash_alerts_channel')
      'High Importance Notifications', // Title shown in system settings
      description:
          'This channel is used for important notifications.', // Description
      importance: Importance.max, // Make it pop up
      playSound: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    DebugLogger.addDebugMessage(
      "Local notifications initialized & channel created.",
    );
  }

  Future<void> _initializeWebNotifications() async {
    if (kIsWeb) {
      try{
        // Get the token for web
        final vapidKey = 'BJhtHl-fqJmuvbvEgcXtcwMJ1FCaKVhoqUeeHqei1UCIlo0jlL2hQrDxAk94rY7JXfzleAbWg4QQc2xuCpKD9Uo'; // Add your VAPID key here
        final webToken = await _firebaseMessaging.getToken(
          vapidKey: vapidKey,
        );
        
        if (webToken != null) {
          DebugLogger.addDebugMessage('Web FCM Token obtained: ${webToken.substring(0, 10)}...');
        } else {
          DebugLogger.addDebugMessage('❌ Failed to get web FCM token.');
        }

        // Setup web-specific message handler
        FirebaseMessaging.onMessage.listen(
          (RemoteMessage message) {  // Changed from _firebaseMessaging.onMessage
            // Create web notification
            DebugLogger.addDebugMessage('Foreground message received: ${message.messageId}');
            
            if (message.notification != null) {
              // Save to DB first
              _saveNotificationToDB(message);

              // Then proceed to show the local notification and update UI
              showLocalNotification(message); // This will still call homeScreenKey...addNotification
            }
          },
          onError: (error) {
            DebugLogger.addDebugMessage(
              '❌ Error in web notification handler: $error',
            );
          },
        );
      } catch (e) {
        DebugLogger.addDebugMessage('❌ Error initializing web notifications: $e');
      }
    }
  }

  void _showWebNotification(RemoteMessage message) {
    if (!kIsWeb) return;

    // Update the UI if the notification dialog is open
    homeScreenKey.currentState?.setState(() {});
    
    // Show browser notification
    if (message.notification != null) {
      DebugLogger.addDebugMessage(
        'Showing web notification: ${message.notification?.title}'
      );
    }
  }

  // Removed: --- Helper: Get and Log FCM Token ---
  // This method is removed as we are focusing only on topic messaging.
  // Future<void> _getAndLogFcmToken() async { ... }

  // --- Helper: Setup Message Handlers ---
  void _setupMessageHandlers() {
    // --- Handler for Foreground Messages ---
    // This handles messages received while the app is actively open and visible.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("FCM Message Data: ${message.data}");
      print("FCM Notification: ${message.notification?.title}");
      DebugLogger.addDebugMessage(
        'Foreground message received: ${message.messageId}',
      );
      if (message.notification != null) {
        DebugLogger.addDebugMessage(
          'Notification: ${message.notification?.title} / ${message.notification?.body}',
        );
        // Save the notification to the database
        _saveNotificationToDB(message);
        // Show local notification for foreground messages using flutter_local_notifications
        showLocalNotification(message);
      } else {
        DebugLogger.addDebugMessage('Foreground message data: ${message.data}');
        // Handle foreground data-only messages if necessary
        // Process message.data here for messages without a notification payload
      }
    });

    // --- Handler for Background Messages ---
    // Assign the top-level function here. This runs when the app is in the background or terminated.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // --- Handler for Terminated State Messages ---
    // Check if the app was opened from a terminated state via a notification tap.
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        DebugLogger.addDebugMessage(
          'App opened from terminated state via notification: ${message.messageId}',
        );
        // You might want to navigate to a specific screen based on message.data
        // Example: _handleMessageNavigation(message.data); // Implement this method
      }
    });

    // --- Handler for when app is opened from background (notification tap) ---
    // This listens for when the user taps on a notification while the app is in the background.
    // Note: Local notification tap is handled by onDidReceiveNotificationResponse if configured
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      DebugLogger.addDebugMessage(
        'App opened from background via notification tap: ${message.messageId}',
      );
      // Navigate or handle based on message data
      // Example: _handleMessageNavigation(message.data); // Implement this method
    });

    DebugLogger.addDebugMessage("FCM message handlers set up.");
  }

  // --- Method to Subscribe to an FCM Topic ---
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      DebugLogger.addDebugMessage('✅ Successfully subscribed to topic: $topic');
      print('✅ Successfully subscribed to topic: $topic');
    } catch (e) {
      DebugLogger.addDebugMessage('❌ Error subscribing to topic $topic: $e');
      print('❌ Error subscribing to topic $topic: $e');
    }
  }

  // --- Optional: Method to Unsubscribe from an FCM Topic ---
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      DebugLogger.addDebugMessage(
        '✅ Successfully unsubscribed from topic: $topic',
      );
      print('✅ Successfully unsubscribed from topic: $topic');
    } catch (e) {
      DebugLogger.addDebugMessage(
        '❌ Error unsubscribing from topic $topic: $e',
      );
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  // --- Method to Show Local Notification (for Foreground messages) ---
  Future<void> showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    // Use the channel ID defined during initialization
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // Channel ID (must match the one created in _initializeLocalNotifications)
      'High Importance Notifications', // Channel Name
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker', // Ticker text shown briefly on older Android
      // icon: '@mipmap/ic_launcher', // Optional: Can override default icon
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ); // Show alert even in foreground
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (notification != null) {
      // Use a unique ID for each notification, message.hashCode is one way.
      // Or generate a more robust unique ID if needed.
      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload:
            jsonEncode(message.data), // Optional: Pass data as string payload
      );
      // Add this line to update the UI
      // homeScreenKey.currentState?.addNotification(message);
      DebugLogger.addDebugMessage(
        "Displayed local notification: ${notification.title}",
      );
    }
  }

  Future<void> checkFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");
    DebugLogger.addDebugMessage("FCM Token: $token");
  }

  // --- Optional: Handle Notification Tap Payload ---
  Future<void> onSelectNotification(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      DebugLogger.addDebugMessage('Local notification payload: $payload');
      try {
        // Convert string payload back to Map
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          // Using JSON decode since payload was stringified
          jsonDecode(payload)
        );
        // Handle the data appropriately
        _handleMessageNavigation(data);
      } catch (e) {
        DebugLogger.addDebugMessage('Error processing notification payload: $e');
      }
    }
  }

  // --- Optional: Handle navigation based on message data ---
  // This method could be called from getInitialMessage or onMessageOpenedApp
  void _handleMessageNavigation(Map<String, dynamic> data) {
    if (data.containsKey('screen')) {
      String screen = data['screen'];
      // Use the homeScreenKey to update UI or navigate
      if (homeScreenKey.currentState != null) {
        switch (screen) {
          case 'map':
            if (data.containsKey('binId')) {
              // Updated to use the new method
              homeScreenKey.currentState!.handleBinSelection(data['binId'].toString());
            }
            break;
          case 'settings':
            // Navigate to settings
              Navigator.of(homeScreenKey.currentState!.context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsScreen(
                    currentUser: homeScreenKey.currentState!.widget.currentUser
                  )
                )
              );
            break;
          default:
            DebugLogger.addDebugMessage('Unknown screen route: $screen');
        }
      }
    }
  }

  // --- Method to Initialize Topics for User Role ---
  Future<void> initializeTopicsForRole(UserRole role) async {
    if (kIsWeb) return;

    // Base topics for all users
    await subscribeToTopic(TRASH_ALERTS_TOPIC);

    // Role-specific topics
    switch (role) {
      case UserRole.admin:
        await subscribeToTopic(TRASH_ALERTS_TOPIC_GAS);
        await subscribeToTopic(TRASH_ALERTS_TOPIC_EMERGENCY);
        break;
      case UserRole.worker:
        await subscribeToTopic(TRASH_ALERTS_TOPIC_GAS);
        await subscribeToTopic(TRASH_ALERTS_TOPIC_EMERGENCY);
        break;
      default:
        break;
    }
  }

  // --- Method to Clear All Notifications ---
  Future<void> clearAllNotifications() async {
    try {
      // Clear local notifications
      await _localNotificationsPlugin.cancelAll();

      // Clear notifications from Firebase Database
      final String? userId = AuthService().currentFirebaseAuthUser?.uid;
      if (userId != null) {
        final dbRef = FirebaseDatabase.instance.ref('user_notifications/$userId');
        await dbRef.remove();
        DebugLogger.addDebugMessage("Cleared all notifications for user $userId");
      }

      // Update UI if needed
      homeScreenKey.currentState?.setState(() {
        // Clear local notification list if you maintain one
      });
    } catch (e) {
      DebugLogger.addDebugMessage("Error clearing notifications: $e");
    }
  }
}
