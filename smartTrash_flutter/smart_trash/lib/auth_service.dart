// lib/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'debug_utils.dart';
import 'user_model.dart'; // Import your AppUser and UserRole

class AuthService {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Stream to provide AppUser with role
  Stream<AppUser?> get appUserWithRoleStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        DebugLogger.addDebugMessage("Auth state changed: No Firebase user.");
        return null;
      }
      try {
        DataSnapshot snapshot = await _dbRef.child('users').child(firebaseUser.uid).get();
        if (snapshot.exists && snapshot.value != null) {
          if (snapshot.value is! Map) {
            throw FormatException('Expected Map for user data');
          }
          Map<dynamic, dynamic> userData = snapshot.value as Map<dynamic, dynamic>;
          UserRole role = UserRole.values.firstWhere(
                  (e) => e.name == userData['role'],
              orElse: () {
                DebugLogger.addDebugMessage("Role not found or invalid for UID: ${firebaseUser.uid}, defaulting to 'user'.");
                return UserRole.user; // Default role
              }
          );
          DebugLogger.addDebugMessage("Role fetched for UID ${firebaseUser.uid}: ${role.name}");
          return AppUser(uid: firebaseUser.uid, email: firebaseUser.email, role: role);
        } else {
          // User exists in Auth, but no data in RTDB (e.g., migration, or error during signup)
          // Create a default entry
          DebugLogger.addDebugMessage("No user data in RTDB for UID: ${firebaseUser.uid}. Creating default 'user' entry.");
          await _dbRef.child('users').child(firebaseUser.uid).set({
            'email': firebaseUser.email,
            'role': UserRole.user.name, // Store role as string
          });
          return AppUser(uid: firebaseUser.uid, email: firebaseUser.email, role: UserRole.user);
        }
      } catch (e) {
        DebugLogger.addDebugMessage("Error fetching role for UID ${firebaseUser.uid}: $e. Defaulting to 'user'.");
        // Fallback in case of DB error
        return AppUser(uid: firebaseUser.uid, email: firebaseUser.email, role: UserRole.user);
      }
    });
  }


  // Register a new user
  Future<AppUser?> registerWithEmailPassword(String email, String password, {UserRole role = UserRole.user,}) async {
    try {
      fb_auth.UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // Set default role in RTDB
        UserRole defaultRole = role; // Use the provided role or default to 'user'
        await _dbRef.child('users').child(firebaseUser.uid).set({
          'email': email,
          'role': defaultRole.name, // Store role as string (e.g., 'user')
        });
        DebugLogger.addDebugMessage("User registered: ${firebaseUser.uid}, Role: ${defaultRole.name}");
        return AppUser(uid: firebaseUser.uid, email: email, role: defaultRole);
      }
      return null;
    } catch (e) {
      DebugLogger.addDebugMessage("Registration Error: $e");
      return null;
    }
  }

  // Login user
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    try {
      fb_auth.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // Fetch role from RTDB
        DataSnapshot snapshot = await _dbRef.child('users').child(firebaseUser.uid).get();
        if (snapshot.exists && snapshot.value != null) {
          Map<dynamic, dynamic> userData = snapshot.value as Map<dynamic, dynamic>;
          UserRole role = UserRole.values.firstWhere(
                (e) => e.name == userData['role'],
            orElse: () => UserRole.user, // Default to 'user' if role is missing/invalid
          );
          DebugLogger.addDebugMessage("User logged in: ${firebaseUser.uid}, Role: ${role.name}");
          return AppUser(uid: firebaseUser.uid, email: email, role: role);
        } else {
          // Should not happen if registration is correct, but handle defensively
          DebugLogger.addDebugMessage("Login successful but no DB entry for ${firebaseUser.uid}. Creating default.");
          UserRole fallbackRole = UserRole.user;
          await _dbRef.child('users').child(firebaseUser.uid).set({
            'email': email, // or firebaseUser.email
            'role': fallbackRole.name,
          });
          return AppUser(uid: firebaseUser.uid, email: email, role: fallbackRole);
        }
      }
      return null;
    } catch (e) {
      DebugLogger.addDebugMessage("Login Error: $e");
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    await _auth.signOut();
    DebugLogger.addDebugMessage("User logged out.");
  }

  // Get current Firebase Auth user (can be useful for direct Firebase Auth operations)
  fb_auth.User? get currentFirebaseAuthUser => _auth.currentUser;

  // fb_auth.User? get currentUser => null;
}