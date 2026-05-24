import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:naqi_ai/trash_bin_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'app_settings.dart';

/// A single deposit record from Firebase RTDB.
class DepositRecord {
  final String id;
  final String binId;
  final String binType;
  final String trashType;
  final bool match;
  final int bonus;
  final double weightAdded;
  final double typeCoefficient;
  final String timestamp;

  const DepositRecord({
    required this.id,
    required this.binId,
    required this.binType,
    required this.trashType,
    required this.match,
    required this.bonus,
    required this.weightAdded,
    required this.typeCoefficient,
    required this.timestamp,
  });

  factory DepositRecord.fromMap(String id, Map<dynamic, dynamic> m) {
    return DepositRecord(
      id: id,
      binId: m['bin_id']?.toString() ?? '',
      binType: m['bin_type']?.toString() ?? '',
      trashType: m['trash_type']?.toString() ?? '',
      match: m['match'] == true,
      bonus: int.tryParse(m['bonus']?.toString() ?? '0') ?? 0,
      weightAdded: double.tryParse(m['weight_added']?.toString() ?? '0') ?? 0,
      typeCoefficient: double.tryParse(m['type_coefficient']?.toString() ?? '1') ?? 1,
      timestamp: m['timestamp']?.toString() ?? '',
    );
  }

  String get trashTypeEmoji {
    switch (trashType.toLowerCase()) {
      case 'plastic':   return '🧴 Plastique';
      case 'glass':     return '🍶 Verre';
      case 'paper':
      case 'cardboard': return '📄 Papier';
      case 'metal':     return '🔩 Métal';
      case 'organic':
      case 'food':      return '🌿 Organique';
      default:          return '🗑️ ${trashType.isEmpty ? 'Inconnu' : trashType}';
    }
  }

  /// Estimated CO2 avoided in kg (rough estimate based on weight)
  double get co2Avoided {
    switch (trashType.toLowerCase()) {
      case 'plastic':   return weightAdded * 1.5;
      case 'glass':     return weightAdded * 0.3;
      case 'paper':     return weightAdded * 0.9;
      case 'metal':     return weightAdded * 2.5;
      case 'organic':   return weightAdded * 0.1;
      default:          return weightAdded * 0.5;
    }
  }
}

class RewardRecord {
  final String id;
  final String type;
  final String awardedAt;
  final int scoreAtAward;

  const RewardRecord({
    required this.id,
    required this.type,
    required this.awardedAt,
    required this.scoreAtAward,
  });

  factory RewardRecord.fromMap(String id, Map<dynamic, dynamic> m) {
    return RewardRecord(
      id: id,
      type: m['type']?.toString() ?? 'ticket',
      awardedAt: m['awarded_at']?.toString() ?? '',
      scoreAtAward: int.tryParse(m['score_at_award']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Service listening to Firebase RTDB for a user's gamification data.
class UserScoreService {
  final String uid;

  UserScoreService({required this.uid});

  DatabaseReference get _userRef =>
      FirebaseDatabase.instance.ref('users/$uid');

  /// Stream of the user's current score (int).
  Stream<int> get scoreStream => _userRef.child('score').onValue.map((event) {
        final val = event.snapshot.value;
        return int.tryParse(val?.toString() ?? '0') ?? 0;
      });

  /// Stream of the user's score threshold.
  Stream<int> get thresholdStream =>
      _userRef.child('score_threshold').onValue.map((event) {
        final val = event.snapshot.value;
        return int.tryParse(val?.toString() ?? '100') ?? 100;
      });

  /// Returns the last [limit] deposit records (most recent first).
  Future<List<DepositRecord>> getDepositHistory({int limit = 20}) async {
    final snapshot = await _userRef.child('deposits').get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final raw = snapshot.value as Map<dynamic, dynamic>;
    final records = raw.entries
        .map((e) => DepositRecord.fromMap(e.key.toString(), e.value as Map))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records.take(limit).toList();
  }

  /// Returns all reward records (most recent first).
  Future<List<RewardRecord>> getRewards() async {
    final snapshot = await _userRef.child('rewards').get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final raw = snapshot.value as Map<dynamic, dynamic>;
    final records = raw.entries
        .map((e) => RewardRecord.fromMap(e.key.toString(), e.value as Map))
        .toList()
      ..sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
    return records;
  }

  /// Fetches a bin info from Firebase by its ID.
  static Future<TrashBin?> getBinStatic(String binId) async {
    final snapshot = await FirebaseDatabase.instance.ref('trash_bins/$binId').get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return TrashBin.fromMap(binId, snapshot.value as Map);
  }

  // ── Smart Enterprise Rankings ─────────────────────────────────────────────

  static const List<Map<String, dynamic>> ranks = [
    {'name': 'Novice Ambassadeur', 'min': 0, 'icon': '🌱'},
    {'name': 'Expert Environnement', 'min': 500, 'icon': '🌿'},
    {'name': 'Elite de l\'Eco-Action', 'min': 2000, 'icon': '🌲'},
    {'name': 'Gardien de la Terre', 'min': 5000, 'icon': '🌍'},
    {'name': 'Légende SmartTrash', 'min': 10000, 'icon': '✨'},
  ];

  Map<String, dynamic> getUserRank(int score) {
    for (var i = ranks.length - 1; i >= 0; i--) {
      if (score >= ranks[i]['min']) {
        return {
          ...ranks[i],
          'level': i + 1,
          'next': i < ranks.length - 1 ? ranks[i + 1]['min'] : null,
          'progress': i < ranks.length - 1 
              ? (score - ranks[i]['min']) / (ranks[i + 1]['min'] - ranks[i]['min']) 
              : 1.0,
        };
      }
    }
    return ranks[0];
  }

  /// Calls the FastAPI endpoint to predict the trash type from a photo.
  static Future<Map<String, dynamic>> predictTrashType(XFile file) async {
    final url = Uri.parse('$_baseUrl/predict/trash_type');
    var request = http.MultipartRequest('POST', url);
    
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }

    final streamRes = await request.send().timeout(const Duration(seconds: 15));
    final res = await http.Response.fromStream(streamRes);
    
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception("IA de prédiction indisponible (${res.statusCode})");
  }

  /// High-level method for the scanner to submit a deposit and get rewards.
  Future<Map<String, dynamic>> validateAndAddScore({
    required String binId,
    required String predictedType,
    required double weightBefore,
  }) async {
    final result = await submitDeposit(
      userId: uid,
      binId: binId,
      trashTypePredicted: predictedType,
      weightBefore: weightBefore,
    );
    
    if (result != null) return result;
    throw Exception("La validation du dépôt a échoué sur le serveur.");
  }

  // ── API calls ─────────────────────────────────────────────────────────────

  static String get _baseUrl =>
      AppSettings().rotageServerUrl ?? 'http://192.168.137.1:8000';

  /// Registers a deposit session before the bin opens.
  static Future<bool> registerSession({
    required String binId,
    required String userId,
    required String trashTypePredicted,
    required double weightBefore,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/deposit/session');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bin_id': binId,
          'user_id': userId,
          'trash_type_predicted': trashTypePredicted,
          'weight_before': weightBefore,
        }),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Calls the reward/deposit endpoint explicitly (Flutter-driven flow).
  static Future<Map<String, dynamic>?> submitDeposit({
    required String userId,
    required String binId,
    required String trashTypePredicted,
    required double weightBefore,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/reward/deposit');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'bin_id': binId,
          'trash_type_predicted': trashTypePredicted,
          'weight_before': weightBefore,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint("Deposit submission failed: ${res.statusCode} ${res.body}");
      return null;
    } catch (e) {
      debugPrint("Deposit submission error: $e");
      return null;
    }
  }
}
