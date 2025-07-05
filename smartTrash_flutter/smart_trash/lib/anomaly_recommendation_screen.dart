import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:smart_trash/app_settings.dart'; // Importer AppSettings pour l'URL du serveur

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
        print('Erreur du serveur : ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur réseau : $e';
        _recommendationsText = "Échec de la récupération des recommandations. Vérifiez la connexion au serveur.";
      });
      print('Erreur lors de la récupération des recommandations : $e');
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
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary;
    final Color textColor = Colors.white.withOpacity(0.9);
    final Color fadedTextColor = Colors.white.withOpacity(0.7);

    return Scaffold(
      backgroundColor: const Color(0xFF1A2A3A), // Arrière-plan sombre
      appBar: AppBar(
        title: const Text("Recommandations d'Anomalies"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                "Analyse des Anomalies et Actions Suggérées",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(2.0, 2.0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Bouton pour générer les recommandations
              _isLoading
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
                  : ElevatedButton.icon(
                      onPressed: _fetchRecommendations,
                      icon: const Icon(Icons.psychology_outlined), // Icône pour l'IA/Analyse
                      label: const Text('Générer Recommandations'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 8,
                      ),
                    ),
              const SizedBox(height: 30),

              // Affichage des messages de statut et d'erreur
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    'Erreur : $_errorMessage',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_recommendationsText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SelectableText( // Permettre la sélection du texte
                    _recommendationsText,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                      height: 1.5, // Espacement de ligne pour une meilleure lisibilité
                      fontFamily: 'monospace', // Pour un affichage plus "code" si désiré
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
