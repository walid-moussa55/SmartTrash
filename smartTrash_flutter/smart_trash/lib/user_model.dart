// lib/user_model.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

enum UserRole { user, worker, admin }

class AppUser {
  final String uid;
  String? email;
  final UserRole role;
  final int score;
  final int scoreThreshold;

  AppUser({
    required this.uid,
    this.email,
    required this.role,
    this.score = 0,
    this.scoreThreshold = 100,
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
      orElse: () => UserRole.user,
    );
    return AppUser(
      uid: uid,
      email: email ?? data['email'],
      role: role,
      score: int.tryParse(data['score']?.toString() ?? '0') ?? 0,
      scoreThreshold: int.tryParse(data['score_threshold']?.toString() ?? '100') ?? 100,
    );
  }

  AppUser copyWith({int? score, int? scoreThreshold}) {
    return AppUser(
      uid: uid,
      email: email,
      role: role,
      score: score ?? this.score,
      scoreThreshold: scoreThreshold ?? this.scoreThreshold,
    );
  }
}
