// lib/gamification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_model.dart';
import 'user_score_service.dart';

class GamificationScreen extends StatefulWidget {
  final AppUser currentUser;
  const GamificationScreen({super.key, required this.currentUser});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen>
    with SingleTickerProviderStateMixin {
  // ── Palette NaqiAI Stricte ──
  static const Color _kBg       = Color(0xFFF5F3EE);
  static const Color _kSurface  = Color(0xFFFFFFFF);
  static const Color _kBorder   = Color(0xFFE2DDD5);
  static const Color _kPrimary  = Color(0xFF2A4A30);
  static const Color _kMid      = Color(0xFF5C8E60);
  static const Color _kLight    = Color(0xFF8EBF93);
  static const Color _kAlert    = Color(0xFFB86B2A);
  static const Color _kTextSec  = Color(0xFF7A8A7C);

  late final UserScoreService _svc;
  late final AnimationController _progressCtrl;

  int _score = 0;
  int _threshold = 100;
  List<DepositRecord> _deposits = [];
  List<RewardRecord> _rewards = [];
  bool _loadingHistory = true;

  StreamSubscription<int>? _scoreSub;
  StreamSubscription<int>? _thresholdSub;

  @override
  void initState() {
    super.initState();
    _svc = UserScoreService(uid: widget.currentUser.uid);
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _scoreSub = _svc.scoreStream.listen((s) {
      if (mounted) {
        setState(() => _score = s);
        final rank = _svc.getUserRank(_score);
        final progress = rank['progress'] as double;
        _progressCtrl.animateTo(progress, curve: Curves.easeOutQuart);
      }
    });
    _thresholdSub = _svc.thresholdStream.listen((t) {
      if (mounted) setState(() => _threshold = t < 1 ? 100 : t);
    });

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _loadingHistory = true);
    final deps = await _svc.getDepositHistory();
    final rews = await _svc.getRewards();
    if (mounted) {
      setState(() {
        _deposits = deps;
        _rewards  = rews;
        _loadingHistory = false;
      });
    }
  }

  @override
  void dispose() {
    _scoreSub?.cancel();
    _thresholdSub?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = _svc.getUserRank(_score);
    final String rankName = rank['name'];
    final String rankIcon = rank['icon'];
    
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('MON IMPACT ÉCO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13, color: _kPrimary)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kPrimary),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: _kPrimary,
        backgroundColor: _kSurface,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            _buildImpactHeader(rankName, rankIcon),
            const SizedBox(height: 24),
            _buildScoreDashboard(rank),
            const SizedBox(height: 24),
            _buildImpactStats(),
            const SizedBox(height: 32),
            _sectionHeader('HISTORIQUE DES ACTIONS', Icons.analytics_outlined),
            const SizedBox(height: 16),
            if (_loadingHistory)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)))
            else if (_deposits.isEmpty)
              _emptyMessage('Aucune action enregistrée. Commencez à trier pour voir votre impact.')
            else
              ..._deposits.map((d) => _depositCard(d)),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactHeader(String rank, String icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kPrimary, _kMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STATUT ACTUEL', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(rank.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDashboard(Map<String, dynamic> rank) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140, height: 140,
                child: AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (context, child) => CustomPaint(
                    painter: _PremiumGaugePainter(progress: _progressCtrl.value),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_score', style: const TextStyle(color: _kPrimary, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
                          const Text('POINTS', style: TextStyle(color: _kTextSec, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _statItem('Dépôts', '${_deposits.length}', Icons.auto_delete_outlined)),
              Container(height: 30, width: 1, color: _kBorder),
              Expanded(child: _statItem('Récompenses', '${_rewards.length}', Icons.emoji_events_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactStats() {
    double totalCo2 = 0;
    for (var d in _deposits) { totalCo2 += d.co2Avoided; }

    return Row(
      children: [
        Expanded(
          child: _impactCard('CO2 ÉCONOMISÉ', '${totalCo2.toStringAsFixed(1)} kg', Icons.cloud_done_outlined, _kMid),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _impactCard('OBJECTIF', '$_threshold pts', Icons.track_changes_rounded, _kAlert),
        ),
      ],
    );
  }

  Widget _impactCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: _kTextSec, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _kTextSec, size: 18),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: _kPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: _kTextSec, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _depositCard(DepositRecord d) {
    final color = d.match ? _kMid : _kAlert;
    String fmtDate = d.timestamp;
    try {
      fmtDate = DateFormat('dd MMM, HH:mm').format(DateTime.parse(d.timestamp).toLocal());
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(d.match ? Icons.verified_rounded : Icons.info_outline_rounded, color: color, size: 20),
        ),
        title: Text(d.trashType.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: _kPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${d.weightAdded.toStringAsFixed(2)} kg · -$fmtDate', style: const TextStyle(fontSize: 12, color: _kTextSec, fontWeight: FontWeight.w500)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(d.bonus >= 0 ? '+${d.bonus}' : '${d.bonus}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            const Text('PTS', style: TextStyle(color: _kTextSec, fontSize: 9, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kPrimary),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: _kPrimary)),
      ],
    );
  }

  Widget _emptyMessage(String text) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _kBorder)),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _kTextSec, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _PremiumGaugePainter extends CustomPainter {
  final double progress;
  _PremiumGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFFE2DDD5).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2A4A30), Color(0xFF8EBF93)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -1.5708, // -90 degrees in radians
      6.28318 * progress, // 360 degrees in radians
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_PremiumGaugePainter oldDelegate) => oldDelegate.progress != progress;
}
