import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naqi_ai/trash_bin_model.dart';
import 'package:naqi_ai/user_model.dart';
import 'package:naqi_ai/user_score_service.dart';

class QrScanScreen extends StatefulWidget {
  final AppUser currentUser;
  const QrScanScreen({super.key, required this.currentUser});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with TickerProviderStateMixin {
  // ── Palette NaqiAI Stricte ──
  static const Color _kBg       = Color(0xFFF5F3EE);
  static const Color _kSurface  = Color(0xFFFFFFFF);
  static const Color _kBorder   = Color(0xFFE2DDD5);
  static const Color _kPale     = Color(0xFFDCF0E0);
  static const Color _kPrimary  = Color(0xFF2A4A30);
  static const Color _kMid      = Color(0xFF5C8E60);
  static const Color _kAlert    = Color(0xFFB86B2A);
  static const Color _kTextSec  = Color(0xFF7A8A7C);

  // ── State machine ──────────────────────────────────────────────────────────
  _Step _step = _Step.scanning;
  final MobileScannerController _qrCtrl = MobileScannerController();
  bool _qrProcessed = false;

  // Bin data
  String? _binId;
  String? _binName;
  String? _binType;
  double _weightBefore = 0;

  // Photo & prediction
  XFile? _photoFile;
  String? _predictedType;
  bool _isPredicting = false;

  // Reward result
  Map<String, dynamic>? _rewardResult;
  bool _isSubmitting = false;

  late AnimationController _animCtrl;
  late AnimationController _laserCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _laserCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _qrCtrl.dispose();
    _animCtrl.dispose();
    _laserCtrl.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────
  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_qrProcessed) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _qrProcessed = true);

    try {
      final bin = await UserScoreService.getBinStatic(code);
      if (bin != null) {
        setState(() {
          _binId = bin.id;
          _binName = bin.name;
          _binType = bin.trashType;
          _weightBefore = bin.weight;
          _step = _Step.binConfirm;
        });
      } else {
        _showError("Code QR non reconnu par NaqiAI.");
        setState(() => _qrProcessed = false);
      }
    } catch (e) {
      _showError("Erreur de connexion serveur.");
      setState(() => _qrProcessed = false);
    }
  }

  Future<void> _pickAndPredict() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (file == null) return;

    setState(() {
      _photoFile = file;
      _step = _Step.predicting;
    });

    try {
      final result = await UserScoreService.predictTrashType(file);
      setState(() {
        _predictedType = result['predicted_class'] ?? result['predicted_type']; // Support both keys
        _step = _Step.preview;
      });
    } catch (e) {
      _showError("L'IA n'a pas pu identifier la matière.");
      setState(() => _step = _Step.binConfirm);
    }
  }

  Future<void> _submitDeposit() async {
    setState(() => _step = _Step.submitting);

    try {
      final svc = UserScoreService(uid: widget.currentUser.uid);
      final val = await svc.validateAndAddScore(
        binId: _binId!,
        predictedType: _predictedType!,
        weightBefore: _weightBefore,
      );

      setState(() {
        _rewardResult = val;
        _step = _Step.result;
      });
      _animCtrl.forward();
    } catch (e) {
      _showError("Erreur: ${e.toString()}");
      _reset();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _kAlert, behavior: SnackBarBehavior.floating),
    );
  }

  void _reset() {
    setState(() {
      _step = _Step.scanning;
      _qrProcessed = false;
      _binId = _binName = _binType = _predictedType = null;
      _photoFile = null;
      _rewardResult = null;
      _weightBefore = 0;
    });
    _animCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent, // Background will be handled by BackdropFilter
      appBar: AppBar(
        title: Text(_step == _Step.scanning ? 'SCANNER DE TRI' : 'CENTRE DE DEPÔT', 
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13, color: _kPrimary)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_step != _Step.scanning && _step != _Step.submitting && _step != _Step.predicting)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kPrimary),
              tooltip: 'Reset',
              onPressed: _reset,
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Semi-transparent overlay with blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: BackdropFilter(
                  filter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 15)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildStep(theme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(ThemeData theme) {
    switch (_step) {
      case _Step.scanning: return _buildScanner(theme);
      case _Step.binConfirm: return _buildBinConfirm(theme);
      case _Step.predicting: return _buildPredicting(theme);
      case _Step.preview: return _buildPreview(theme);
      case _Step.submitting: return _buildSubmitting(theme);
      case _Step.result: return _buildResult(theme);
    }
  }

  Widget _buildScanner(ThemeData theme) {
    return Column(
      key: const ValueKey('scanner'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        _stepHeader('SCANNER QR', 'Alignez le code QR du bac dans la zone ci-dessous.', theme),
        Container(
          height: 300,
          width: 300,
          margin: const EdgeInsets.fromLTRB(24, 32, 24, 48),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 15))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                MobileScanner(controller: _qrCtrl, onDetect: _onQrDetected),
                _ScannerOverlay(animation: _laserCtrl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBinConfirm(ThemeData theme) {
    final typeColor = _typeColor(_binType ?? '');

    return SingleChildScrollView(
      key: const ValueKey('binConfirm'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader('BAC RÉCUPÉRÉ', 'Vérifiez les spécifications du conteneur avant le dépôt.', theme),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _kBorder, width: 1),
              boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.08), shape: BoxShape.circle),
                  child: Icon(_typeIcon(_binType ?? ''), size: 36, color: typeColor),
                ),
                const SizedBox(height: 20),
                Text(_binName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: _kPrimary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    (_binType ?? '').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
                Divider(color: _kBorder.withValues(alpha: 0.5)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Capacité Actuelle', style: TextStyle(color: _kTextSec, fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${_weightBefore.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _kPrimary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _primaryBtn(Icons.camera_alt_rounded, 'CAPTURE ANALYTIQUE', _pickAndPredict, theme),
        ],
      ),
    );
  }

  Widget _buildPredicting(ThemeData theme) {
    return Center(
      key: const ValueKey('predicting'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 50, width: 50,
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
          ),
          const SizedBox(height: 32),
          const Text(
            'ANALYSE DE LA MATIÈRE',
            style: TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text('Réseau neuronal SmartTrash en cours...', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final matches = _predictedType?.toLowerCase() == _binType?.toLowerCase();
    final predColor = matches ? _kMid : _kAlert;

    return SingleChildScrollView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _stepHeader('IDENTIFICATION TERMINÉE', 'Vérifiez la prédiction avant d\'ouvrir le bac.', theme),
          const SizedBox(height: 32),
          if (_photoFile != null)
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorder, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: kIsWeb 
                    ? Image.network(_photoFile!.path, fit: BoxFit.cover)
                    : Image.file(File(_photoFile!.path), fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _infoCard('BAC', _binType ?? '', _typeColor(_binType ?? ''), theme)),
              const SizedBox(width: 16),
              Expanded(child: _infoCard('IA PRÉDICT', _predictedType ?? '', predColor, theme)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            width: double.infinity,
            decoration: BoxDecoration(color: predColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: predColor.withValues(alpha: 0.3))),
            child: Row(
              children: [
                Icon(matches ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: predColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    matches ? 'Matière confirmée. Vous pouvez procéder au dépôt.' : 'Divergence détectée. Le score pourrait être ajusté.',
                    style: TextStyle(color: predColor, fontWeight: FontWeight.w700, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _primaryBtn(Icons.door_front_door_rounded, 'AUTORISER LE DÉPÔT', _submitDeposit, theme),
          const SizedBox(height: 16),
          _secondaryBtn(Icons.refresh_rounded, 'Nouvelle photo', _pickAndPredict, theme),
        ],
      ),
    );
  }

  Widget _buildSubmitting(ThemeData theme) {
    return Center(
      key: const ValueKey('submitting'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50, width: 50, child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 3)),
          const SizedBox(height: 32),
          const Text('CAPTEURS DE POIDS ACTIFS', style: TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('Veuillez fermer le bac après le dépôt.\nCalcul de l\'impact environnemental...', style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    final bonus = _rewardResult?['bonus'] as int? ?? 0;
    final score = _rewardResult?['total_score'] as int? ?? 0;
    final ticketWon = _rewardResult?['ticket_won'] as bool? ?? false;
    final msg = _rewardResult?['message']?.toString() ?? '';
    final isMatch = _rewardResult?['type_match'] as bool? ?? false;
    
    final mainColor = ticketWon ? const Color(0xFFB86B2A) : (isMatch ? _kMid : _kAlert);
    final iconData = ticketWon ? Icons.emoji_events_rounded : (isMatch ? Icons.verified_rounded : Icons.error_rounded);
    final title = ticketWon ? 'RÉCOMPENSE DÉBLOQUÉE' : (isMatch ? 'DÉPÔT VALIDÉ' : 'DÉPÔT INVALIDE');

    return ScaleTransition(
      scale: _scaleAnim,
      child: Center(
        child: SingleChildScrollView(
          key: const ValueKey('result'),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: mainColor.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 15))],
                ),
                child: Column(
                  children: [
                    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: mainColor.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(iconData, size: 56, color: mainColor)),
                    const SizedBox(height: 32),
                    Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: mainColor)),
                    const SizedBox(height: 16),
                    Text(
                      ticketWon ? 'Ticket Gagné !' : (bonus >= 0 ? '+$bonus PTS' : '$bonus PTS'),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1, color: _kPrimary),
                    ),
                    const SizedBox(height: 16),
                    Text(msg, style: TextStyle(fontSize: 14, height: 1.5, color: _kTextSec, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    Divider(color: _kBorder.withValues(alpha: 0.5)),
                    const SizedBox(height: 24),
                    const Text('BALANCE TOTALE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: _kTextSec)),
                    const SizedBox(height: 8),
                    Text('$score PTS', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              _primaryBtn(Icons.qr_code_scanner_rounded, 'NOUVEAU SCAN', _reset, theme),
              const SizedBox(height: 16),
              _secondaryBtn(Icons.dashboard_rounded, 'Retour au Dashboard', () => Navigator.of(context).pop(), theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(String title, String subtitle, ThemeData theme) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(subtitle, style: const TextStyle(color: _kTextSec, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _infoCard(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: _kTextSec)),
          const SizedBox(height: 8),
          Text(value.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _primaryBtn(IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return SizedBox(
      width: double.infinity, height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _secondaryBtn(IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return SizedBox(
      width: double.infinity, height: 60,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3, fontSize: 14, color: _kPrimary)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _kBorder, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return const Color(0xFF3498DB);
      case 'glass': return const Color(0xFF1ABC9C);
      case 'paper':
      case 'cardboard': return const Color(0xFFE67E22);
      case 'metal': return const Color(0xFF7F8C8D);
      case 'organic':
      case 'food': return _kMid;
      default: return _kPrimary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return Icons.local_drink_rounded;
      case 'glass': return Icons.wine_bar_rounded;
      case 'paper':
      case 'cardboard': return Icons.inventory_2_rounded;
      case 'metal': return Icons.precision_manufacturing_rounded;
      case 'organic':
      case 'food': return Icons.eco_rounded;
      default: return Icons.delete_outline_rounded;
    }
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;
  const _ScannerOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ScannerPainter(animation.value),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double progress;
  _ScannerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double rectSize = size.width * 0.7;
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectSize,
      height: rectSize,
    );

    const double len = 30.0;
    final path = Path();
    path.moveTo(rect.left, rect.top + len);
    path.lineTo(rect.left, rect.top);
    path.lineTo(rect.left + len, rect.top);
    path.moveTo(rect.right - len, rect.top);
    path.lineTo(rect.right, rect.top);
    path.lineTo(rect.right, rect.top + len);
    path.moveTo(rect.left, rect.bottom - len);
    path.lineTo(rect.left, rect.bottom);
    path.lineTo(rect.left + len, rect.bottom);
    path.moveTo(rect.right - len, rect.bottom);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.right, rect.bottom + len);
    canvas.drawPath(path, paint);

    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, Colors.white.withValues(alpha: 0.8), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(rect.left, rect.top + (rect.height * progress), rect.width, 2))
      ..strokeWidth = 3.0;

    canvas.drawLine(
      Offset(rect.left, rect.top + (rect.height * progress)),
      Offset(rect.right, rect.top + (rect.height * progress)),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(_ScannerPainter oldDelegate) => oldDelegate.progress != progress;
}

enum _Step { scanning, binConfirm, predicting, preview, submitting, result }
