import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:naqi_ai/app_settings.dart'; 
import 'package:naqi_ai/pdf_generator_service.dart';

// --- Executive Studio AI Design System (Premium Light) ---
const _kBgSable    = Color(0xFFFDFCF9); // Sophisticated Beige
const _kSurface    = Color(0xFFFFFFFF); // High-end Paper
const _kDeepForest = Color(0xFF1E3A24); // Executive Primary
const _kSage       = Color(0xFFA7B9A9); // Accent
const _kSlate      = Color(0xFF64748B); // Subtext
const _kSoftAlert  = Color(0xFFB45309); // Warning
const _kSoftError  = Color(0xFF991B1B); // Critical

final _kSoftBorder = Color(0xFFEEE9E0);
final _kSoftShadow = [BoxShadow(color: Color(0xFF1E3A24).withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 15))];

class AnomalyRecommendationScreen extends StatefulWidget {
  const AnomalyRecommendationScreen({super.key});

  @override
  State<AnomalyRecommendationScreen> createState() => _AnomalyRecommendationScreenState();
}

class _AnomalyRecommendationScreenState extends State<AnomalyRecommendationScreen> with TickerProviderStateMixin {
  String _serverUrl = ''; 
  String _recommendationsText = "// Système en attente...\nCliquez sur l'analyseur pour démarrer le diagnostic complet du réseau de bacs.";
  bool _isLoading = false;
  String? _errorMessage;
  final AppSettings appSettings = AppSettings(); 
  
  late AnimationController _pulseCtrl;
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServerUrl());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServerUrl() async {
    await appSettings.loadSettings(); 
    if (mounted) {
      setState(() {
        _serverUrl = appSettings.rotageServerUrl ?? '';
        if (_serverUrl.isEmpty) {
          _errorMessage = "L'URL du serveur n'est pas configurée.";
          _recommendationsText = "Veuillez configurer l'URL du serveur dans les paramètres.";
        }
      });
    }
  }

  Future<void> _fetchRecommendations() async {
    if (_serverUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _recommendationsText = "Calcul et analyse des données en cours...";
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/anomaly-recommendations'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() => _recommendationsText = responseData['recommendations'] ?? "Aucune anomalie détectée.");
      } else {
        setState(() {
          _errorMessage = "Erreur serveur : ${response.statusCode}";
          _recommendationsText = "Échec du diagnostic système.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur réseau : Vérifiez votre connexion.";
        _recommendationsText = "Le serveur est injoignable.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgSable,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kDeepForest, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("ANALYSES PRÉDICTIVES", 
            style: TextStyle(color: _kDeepForest, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildExecutiveHeader(),
                const SizedBox(height: 54),
                _buildMinimalistButton(),
                const SizedBox(height: 54),
                if (_errorMessage != null) _buildSoftErrorCard(),
                _buildExecutiveReport(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: _kSoftBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 30)],
          ),
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut)),
            child: const Icon(Icons.interests_outlined, size: 64, color: _kDeepForest),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "ANALYSTE IA",
          textAlign: TextAlign.center,
          style: TextStyle(color: _kDeepForest, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: _kSage.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
          child: const Text("SOPHISTIQUÉ & PRÉCIS", style: TextStyle(color: _kDeepForest, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildMinimalistButton() {
    return _isLoading
        ? const CircularProgressIndicator(color: _kDeepForest, strokeWidth: 2)
        : Container(
            width: 280,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [BoxShadow(color: _kDeepForest.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ElevatedButton(
              onPressed: _fetchRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDeepForest,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text('LANCER L\'ANALYSE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
            ),
          );
  }

  Widget _buildExecutiveReport() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kSoftBorder, width: 1.5),
        boxShadow: _kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _kSoftBorder))),
            child: Row(
              children: [
                const Icon(Icons.summarize_outlined, color: _kDeepForest, size: 20),
                const SizedBox(width: 14),
                const Text("RAPPORT DE PERFORMANCE IA", style: TextStyle(color: _kDeepForest, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: _buildFormattedReport(_recommendationsText),
          ),
          if (!_isLoading && _recommendationsText.contains("anomalies détectées"))
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => PdfGeneratorService.generateAndDownloadReport(reportText: _recommendationsText),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kDeepForest, width: 1.5),
                    foregroundColor: _kDeepForest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text("TÉLÉCHARGER LE RAPPORT OFFICIEL (PDF)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormattedReport(String text) {
    List<Widget> spans = [];
    final lines = text.split('\n');

    for (var line in lines) {
      Color textColor = _kDeepForest;
      FontWeight weight = FontWeight.w600;
      Widget? leading;

      if (line.contains('anomalies détectées') || line.contains('Anomalie détectée')) {
        textColor = _kSoftError;
        weight = FontWeight.w900;
        leading = Container(width: 4, height: 20, decoration: BoxDecoration(color: _kSoftError, borderRadius: BorderRadius.circular(10)));
      } else if (line.contains('Action prioritaire') || line.contains('Suggestion')) {
        textColor = _kSoftAlert;
        weight = FontWeight.w800;
      }

      spans.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) Padding(padding: const EdgeInsets.only(right: 12), child: leading),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    color: textColor.withOpacity(line.startsWith('-') ? 0.7 : 1.0),
                    fontSize: 14,
                    fontWeight: weight,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: spans);
  }

  Widget _buildSoftErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _kSoftError.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: _kSoftError.withOpacity(0.1))),
      child: Text(_errorMessage!, style: const TextStyle(color: _kSoftError, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
