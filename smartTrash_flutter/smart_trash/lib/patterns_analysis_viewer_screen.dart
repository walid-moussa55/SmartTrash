import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert'; // For utf8.decode
import 'package:smart_trash/app_settings.dart'; // For fetching server URL
import 'package:smart_trash/debug_utils.dart'; // For logging

/// A screen dedicated to displaying "Analyse des Patterns" content.
/// It features a button to fetch the Markdown content from a server endpoint
/// and displays it directly on the page.
class PatternsAnalysisViewerScreen extends StatefulWidget {
  const PatternsAnalysisViewerScreen({super.key});

  @override
  State<PatternsAnalysisViewerScreen> createState() => _PatternsAnalysisViewerScreenState();
}

class _PatternsAnalysisViewerScreenState extends State<PatternsAnalysisViewerScreen> {
  String _markdownContent = "Cliquez sur 'Charger l'analyse' pour voir les patterns.";
  bool _isLoading = false;
  String? _errorMessage;
  String? _serverUrl;

  // The specific endpoint for the patterns analysis Markdown file
  static const String _patternsAnalysisEndpoint = '/get-patterns-analysis-markdown';

    // Instance of AppSettings to fetch the server URL
    final AppSettings appSettings = AppSettings();

  @override
  void initState() {
    super.initState();
    // Load server URL on init, but don't fetch content automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerUrl();
    });
  }

  Future<void> _loadServerUrl() async {
    try {
      await appSettings.loadSettings();

      if (mounted) {
        setState(() {
          _serverUrl = appSettings.rotageServerUrl;
          if (_serverUrl == null || _serverUrl!.isEmpty) {
            _errorMessage = "L'URL du serveur n'est pas configurée dans les paramètres de l'application.";
            _markdownContent = "Impossible de charger l'analyse : URL du serveur manquante.";
            DebugLogger.addDebugMessage("PatternsAnalysisViewerScreen: Server URL not configured.");
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur d'initialisation : ${e.toString()}";
          _markdownContent = "Erreur de chargement.";
        });
      }
      DebugLogger.addDebugMessage("PatternsAnalysisViewerScreen: Error during init/load: $e");
    }
  }

  Future<void> _fetchMarkdownContent() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      setState(() {
        _errorMessage = "L'URL du serveur n'est pas disponible pour récupérer le contenu Markdown.";
        _markdownContent = "Impossible de charger l'analyse : URL du serveur manquante.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _markdownContent = "Chargement de l'analyse...";
    });

    try {
      final response = await http.get(Uri.parse('$_serverUrl$_patternsAnalysisEndpoint'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _markdownContent = utf8.decode(response.bodyBytes); // Décode les octets en chaîne
            _isLoading = false;
          });
        }
        DebugLogger.addDebugMessage("PatternsAnalysisViewerScreen: Contenu chargé avec succès depuis $_patternsAnalysisEndpoint.");
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Échec du chargement du contenu : ${response.statusCode} - ${response.reasonPhrase ?? 'Inconnu'}.';
            _markdownContent = "Erreur lors du chargement du contenu.";
            _isLoading = false;
          });
        }
        DebugLogger.addDebugMessage("PatternsAnalysisViewerScreen: Échec du chargement du contenu depuis $_patternsAnalysisEndpoint : ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur réseau : $e. Vérifiez la connexion au serveur et l\'URL.';
          _markdownContent = "Erreur lors du chargement du contenu.";
          _isLoading = false;
        });
      }
      DebugLogger.addDebugMessage("PatternsAnalysisViewerScreen: Erreur réseau lors de la récupération de $_patternsAnalysisEndpoint : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2A3A),
      appBar: AppBar(
        title: const Text('Analyse des Patterns'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchMarkdownContent, // Désactiver le rafraîchissement pendant le chargement
            tooltip: 'Actualiser le contenu',
          ),
        ],
      ),
      body: SingleChildScrollView( // Utiliser SingleChildScrollView pour tout le corps
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Étirer les enfants horizontalement
          children: [
            // Bouton de génération/chargement
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _serverUrl == null || _serverUrl!.isEmpty
                    ? Center(
                        child: Text(
                          _errorMessage ?? "Veuillez configurer l'URL du serveur.",
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _fetchMarkdownContent,
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: const Text('Charger l\'analyse des patterns'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 5,
                        ),
                      ),
            const SizedBox(height: 20), // Espace après le bouton

            // Affichage des messages d'erreur (si présents)
            if (_errorMessage != null && !_isLoading) // Montrer l'erreur si non en chargement
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Erreur: $_errorMessage',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),

            // Affichage du contenu Markdown
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: _markdownContent,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  h1: TextStyle(color: primaryColor, fontSize: 28, fontWeight: FontWeight.bold),
                  h2: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 24, fontWeight: FontWeight.bold),
                  h3: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 20, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  // NEW: Table styles for text color
                  tableBody: const TextStyle(color: Colors.white, fontSize: 16),
                  tableHead: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  // tableCellsPadding: const EdgeInsets.all(8.0), // Optional: add padding
                  // tableBorder: TableBorder.all(color: Colors.white.withOpacity(0.3)), // Optional: add table borders
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
