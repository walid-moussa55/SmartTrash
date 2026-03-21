// lib/user_model.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

enum UserRole { user, worker, admin }

class AppUser {
  final String uid;
  String? email;
  final UserRole role;

  AppUser({
    required this.uid,
    this.email,
    required this.role,
  });

  factory AppUser.fromFirebaseAuthUser(fb_auth.User firebaseUser, UserRole role) {
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      role: role,
    );
  }

  // Optional: If you fetch a map from Firebase for user data
  factory AppUser.fromFirebaseMap(String uid, String? email, Map<dynamic, dynamic> data) {
    UserRole role = UserRole.values.firstWhere(
          (e) => e.name == data['role'],
      orElse: () => UserRole.user, // Default to 'user' if role is missing or invalid
    );
    return AppUser(
      uid: uid,
      email: email ?? data['email'], // Use Firebase Auth email preferably
      role: role,
    );
  }
}