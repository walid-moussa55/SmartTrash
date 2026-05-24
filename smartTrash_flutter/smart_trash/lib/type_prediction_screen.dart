import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:naqi_ai/app_settings.dart';
import 'package:naqi_ai/debug_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Import the new bin search service and models
import 'package:naqi_ai/bin_search_service.dart';
import 'package:naqi_ai/home_screen.dart' show TrashBin;
import 'package:naqi_ai/map_screen.dart';

class TypePredictionScreen extends StatefulWidget {
  const TypePredictionScreen({super.key});

  @override
  State<TypePredictionScreen> createState() => _TypePredictionScreenState();
}

class _TypePredictionScreenState extends State<TypePredictionScreen> {
  // ── DESIGN SYSTEM CONSTANTS ──
  static const Color _kBg        = Color(0xFFF5F3EE);
  static const Color _kSurface   = Color(0xFFFFFFFF);
  static const Color _kBorder    = Color(0xFFE2DDD5);
  static const Color _kPale      = Color(0xFFDCF0E0);
  static const Color _kLight     = Color(0xFF8EBF93);
  static const Color _kMid       = Color(0xFF5C8E60);
  static const Color _kPrimary   = Color(0xFF2A4A30);
  static const Color _kAlert     = Color(0xFFB86B2A);
  static const Color _kTextSec   = Color(0xFF7A8A7C);
  static const Color _kTextDark  = Color(0xFF2A4A30);

  XFile? _imageFile;
  String _predictionResult = "Sélectionnez une image pour commencer l'analyse.";
  bool _isLoading = false;
  String? _errorMessage;
  String? _serverUrl;
  String? _predictedTrashType;
  bool _isSearchingBins = false;

  final BinSearchService _binSearchService = BinSearchService();
  final AppSettings appSettings = AppSettings();

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    await appSettings.loadSettings();
    if (!mounted) return;
    setState(() {
      _serverUrl = appSettings.rotageServerUrl;
      if (_serverUrl == null || _serverUrl!.isEmpty) {
        _errorMessage = "Serveur non configuré.";
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _predictionResult = "Prêt pour l'analyse.";
      _imageFile = null;
      _predictedTrashType = null;
    });
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  Future<void> _predictTrashType() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      setState(() { _errorMessage = "Serveur non configuré."; });
      return;
    }
    if (_imageFile == null) {
      setState(() { _errorMessage = "Veuillez choisir une image."; });
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionResult = "Analyse en cours...";
      _errorMessage = null;
      _predictedTrashType = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_serverUrl/predict/trash_type'));
      request.files.add(http.MultipartFile.fromBytes('file', await _imageFile!.readAsBytes(), filename: _imageFile!.name));
      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String res = data['predicted_class'] ?? 'Inconnu';
        setState(() {
          _predictedTrashType = res;
          _predictionResult = res;
        });
      } else {
        setState(() {
          _errorMessage = 'Erreur serveur (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Erreur réseau: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _searchAndDisplayBins() async {
    if (_predictedTrashType == null) return;
    setState(() { _isSearchingBins = true; });
    try {
      final bins = await _binSearchService.findNearestBinsOfType(_predictedTrashType!);
      if (mounted) _showBinListDialog(bins);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recherche impossible: $e")));
    } finally {
      if (mounted) setState(() { _isSearchingBins = false; });
    }
  }

  void _showBinListDialog(List<TrashBin> bins) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Poubelles $_predictedTrashType à proximité', style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
        content: bins.isEmpty
          ? const Text('Aucune poubelle trouvée.', style: TextStyle(color: _kTextSec, fontWeight: FontWeight.w600))
          : SizedBox(
              width: double.maxFinite,
              height: 350,
              child: ListView.separated(
                itemCount: bins.length,
                separatorBuilder: (c, i) => const Divider(color: _kBorder, height: 1),
                itemBuilder: (c, i) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _kPale, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_rounded, color: _kPrimary, size: 22),
                  ),
                  title: Text(bins[i].name, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(
                    'NIVEAU: ${bins[i].trashLevel.toStringAsFixed(0)}% • TYPE: ${bins[i].trashType}',
                    style: const TextStyle(color: _kTextSec, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: _kBorder, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => MapScreen(trashBins: [bins[i]], initialTrashBin: bins[i], showRoute: true)));
                  },
                ),
              ),
            ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('FERMER', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    // Status and Error indicators
    Widget feedbackArea = Column(
      children: [
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text("ANALYSE DES PIXELS EN COURS...", style: TextStyle(color: _kTextSec, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
      ],
    );

    Widget content = Column(
      children: [
        _buildScannerFrame(),
        const SizedBox(height: 30),
        _buildCaptureButtons(),
        const SizedBox(height: 30),
        _buildPredictionZone(),
        feedbackArea, // Added feedback here for mobile
        const SizedBox(height: 20),
        if (_predictedTrashType != null) _buildResultCard(),
        const SizedBox(height: 40),
      ],
    );

    if (isDesktop) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildScannerFrame()),
          const SizedBox(width: 40),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildCaptureButtons(),
                const SizedBox(height: 30),
                _buildPredictionZone(),
                feedbackArea, // Added feedback here for desktop
                if (_predictedTrashType != null) _buildResultCard(),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("AI VISION", style: TextStyle(color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildScannerFrame() {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      width: double.infinity,
      height: isDesktop 
          ? MediaQuery.of(context).size.height * 0.65 // Limit height on PC
          : MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _kBorder, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            _imageFile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_center_focus_rounded, size: 64, color: _kTextSec.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text("Visez un déchet", style: TextStyle(color: _kTextSec, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : Image.network(_imageFile!.path, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(child: CircularProgressIndicator(color: _kPrimary)),
              ),
            // Corners Design
            _buildCorner(top: 0, left: 0),
            _buildCorner(top: 0, right: 0, isRight: true),
            _buildCorner(bottom: 0, left: 0, isBottom: true),
            _buildCorner(bottom: 0, right: 0, isBottom: true, isRight: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right, bool isBottom = false, bool isRight = false}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top != null ? const BorderSide(color: _kPrimary, width: 4) : BorderSide.none,
            bottom: bottom != null ? const BorderSide(color: _kPrimary, width: 4) : BorderSide.none,
            left: left != null ? const BorderSide(color: _kPrimary, width: 4) : BorderSide.none,
            right: right != null ? const BorderSide(color: _kPrimary, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPillButton(Icons.camera_alt_rounded, "Caméra", () => _pickImage(ImageSource.camera)),
        const SizedBox(width: 16),
        _buildPillButton(Icons.photo_library_rounded, "Galerie", () => _pickImage(ImageSource.gallery), isSecondary: true),
      ],
    );
  }

  Widget _buildPillButton(IconData icon, String label, VoidCallback onTap, {bool isSecondary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSecondary ? _kSurface : _kPrimary,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSecondary ? _kBorder : _kPrimary),
          boxShadow: [BoxShadow(color: (isSecondary ? _kBorder : _kPrimary).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSecondary ? _kPrimary : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSecondary ? _kPrimary : Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionZone() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: (_imageFile != null && !_isLoading) ? _predictTrashType : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary, foregroundColor: Colors.white,
          disabledBackgroundColor: _kBorder.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text("DÉTECTER LE TYPE DE DÉCHET", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildResultCard() {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kMid.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: _kMid, size: 24),
                const SizedBox(width: 12),
                Text(_predictedTrashType!.toUpperCase(), style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: _kBorder),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSearchingBins ? null : _searchAndDisplayBins,
              icon: const Icon(Icons.location_on_rounded),
              label: const Text("TROUVER UNE POUBELLE ADAPTÉE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kMid, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

