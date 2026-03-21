import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:naqi_ai/app_settings.dart'; // Importer AppSettings pour l'URL du serveur
import 'package:naqi_ai/debug_utils.dart';

class AnomalyRecommendationScreen extends StatefulWidget {
  const AnomalyRecommendationScreen({super.key});

  @override
  State<AnomalyRecommendationScreen> createState() => _AnomalyRecommendationScreenState();
}

class _AnomalyRecommendationScreenState extends State<AnomalyRecommendationScreen> {
  String _serverUrl = ''; // Sera chargé depuis AppSettings
  String _recommendationsText = "Cliquez sur 'Générer Recommandations' pour voir les anomalies et les actions suggérées.";
  bool _isLoading = false;
  String? _errorMessage;
  final AppSettings appSettings = AppSettings(); // Instance de AppSettings pour accéder aux paramètres

  @override
  void initState() {
    super.initState();
    // Charger l'URL du serveur dès que le widget est construit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerUrl();
    });
  }

  // Charger l'URL du serveur depuis AppSettings
  Future<void> _loadServerUrl() async {
    await appSettings.loadSettings(); // S'assurer que les paramètres sont chargés
    if (mounted) {
      setState(() {
        _serverUrl = appSettings.rotageServerUrl ?? '';
        if (_serverUrl.isEmpty) {
          _errorMessage = "L'URL du serveur n'est pas configurée dans les paramètres de l'application.";
          _recommendationsText = "Impossible de se connecter au serveur sans URL.";
        }
      });
    }
  }

  // Fonction pour récupérer les recommandations d'anomalies depuis le serveur
  Future<void> _fetchRecommendations() async {
    if (_serverUrl.isEmpty) {
      setState(() {
        _errorMessage = "L'URL du serveur n'est pas configurée. Veuillez la définir dans les paramètres de l'application.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _recommendationsText = "Génération et récupération des recommandations...";
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/anomaly-recommendations'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String recommendations = responseData['recommendations'] ?? "Aucune recommandation disponible.";
        setState(() {
          _recommendationsText = recommendations;
        });
      } else {
        String detail = 'Échec de la récupération des recommandations : Erreur du serveur.';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          detail = errorData['detail'] ?? detail;
        } catch (_) {
          detail = 'Erreur du serveur : ${response.statusCode}, ${response.reasonPhrase ?? 'Inconnu'}. Réponse brute : ${response.body}';
        }
        setState(() {
          _errorMessage = detail;
          _recommendationsText = "Échec de la récupération des recommandations.";
        });
        DebugLogger.addDebugMessage('Erreur du serveur : ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur réseau : $e';
        _recommendationsText = "Échec de la récupération des recommandations. Vérifiez la connexion au serveur.";
      });
      DebugLogger.addDebugMessage('Erreur lors de la récupération des recommandations : $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Anomaly Recommendations"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.psychology_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                "AI Anomaly Analysis",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              _isLoading
                  ? CircularProgressIndicator(color: theme.colorScheme.primary)
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _fetchRecommendations,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Generate Recommendations'),
                      ),
                    ),
              const SizedBox(height: 30),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_recommendationsText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(
                    _recommendationsText,
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
