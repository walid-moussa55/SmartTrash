import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io' as io;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:smart_trash/app_settings.dart'; // Import AppSettings for server URL

// Add this import only for web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class FinalRapportGenerationScreen extends StatefulWidget {
  const FinalRapportGenerationScreen({super.key});

  @override
  State<FinalRapportGenerationScreen> createState() => _FinalRapportGenerationScreenState();
}

class _FinalRapportGenerationScreenState extends State<FinalRapportGenerationScreen> {
  String _serverUrl = ''; // Will be loaded from AppSettings
  String? _statusMessage;
  String? _errorMessage;
  bool _isGenerating = false;
  
  // NEW: State variable to hold PDF bytes
  Uint8List? _pdfBytes;
  // NEW: Controller for the PDF viewer
  final PdfViewerController _pdfViewerController = PdfViewerController();

    // Instance of AppSettings to access server URL
    final AppSettings appSettings = AppSettings();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerUrl();
    });
  }

  @override
  void dispose() {
    _pdfViewerController.dispose(); // Dispose the PDF viewer controller
    super.dispose();
  }

  // Load server URL from AppSettings
  Future<void> _loadServerUrl() async {
    await appSettings.loadSettings();
    if (mounted) {
      setState(() {
        _serverUrl = appSettings.rotageServerUrl ?? '';
        if (_serverUrl.isEmpty) {
          _errorMessage = "Server URL is not configured in app settings.";
          _statusMessage = "Please configure server URL in settings to generate reports.";
        }
      });
    }
  }

  // Function to generate the report on the server and fetch its content
  Future<void> _generateReport() async {
    if (_serverUrl.isEmpty) {
      setState(() {
        _errorMessage = "Server URL is not configured.";
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = "Generating report...";
      _errorMessage = null;
      _pdfBytes = null; // Clear previous PDF
    });

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/generate-report'),
        headers: {'Content-Type': 'application/json'}, // Server still expects this for the trigger
      );

      if (response.statusCode == 200) {
        // Assume server directly sends PDF bytes on success
        setState(() {
          _pdfBytes = response.bodyBytes; // Store the PDF bytes
          _statusMessage = 'Report generated successfully!';
        });
      } else {
        // If server returns JSON error, try to parse it
        String detail = 'Failed to generate report: Server error.';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          detail = errorData['detail'] ?? detail;
        } catch (_) {
          // If response body is not JSON, use raw body
          detail = 'Server error: ${response.statusCode}, ${response.reasonPhrase ?? 'Unknown'}. Raw response: ${response.body}';
        }
        setState(() {
          _errorMessage = detail;
          _statusMessage = "Report generation failed.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _statusMessage = "Report generation failed.";
      });
      print('Error generating report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
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
      backgroundColor: Color(0xFF1A2A3A),
      appBar: AppBar(
        title: const Text("Report Generation & View"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Smart Waste Management Report",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black.withOpacity(0.5),
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoText('**I. Résumé de l\'Analyse**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**II. Indicateurs Principaux**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**III. Analyse des Alertes**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**IV. Analyse du Temps**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**V. Analyse Environnementale**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**VI. Conclusion**'),
                    const SizedBox(height: 20),
                    _buildInfoText('**VII. Analyses Visuelles**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**VIII. Tableau Récapitulatif**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**IX. Bacs en Situation Critique**'),
                    const SizedBox(height: 15),
                    _buildInfoText('**X. Analyse Avancée par NLP**'),
                    const SizedBox(height: 20),
                    Text(
                      "Report generated by the SmartTrash system.",
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: fadedTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Generate Report Button
              _isGenerating
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
                  : ElevatedButton.icon(
                      onPressed: _generateReport,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Generate & View Report'), // Changed label
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

              // Status and Error Messages
              if (_statusMessage != null)
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _errorMessage == null ? Colors.greenAccent : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),

              // Download Button Section
              if (_pdfBytes != null) ...[
                _buildSectionHeader('Generated Report'),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 8,
                  ),
                  onPressed: () async {
                    if (kIsWeb) {
                      // Web: Use AnchorElement to trigger download
                      final blob = html.Blob([_pdfBytes!], 'application/pdf');
                      final url = html.Url.createObjectUrlFromBlob(blob);
                      final anchor = html.AnchorElement(href: url)
                        ..setAttribute('download', 'SmartTrash_Rapport.pdf')
                        ..click();
                      html.Url.revokeObjectUrl(url);
                    } else {
                      // Mobile/Desktop: Save to Downloads directory
                      final status = await Permission.storage.request();
                      if (status.isGranted) {
                        final directory = await getExternalStorageDirectory();
                        final path = directory?.path ?? '/storage/emulated/0/Download';
                        final file = io.File('$path/SmartTrash_Rapport.pdf');
                        await file.writeAsBytes(_pdfBytes!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PDF saved to $path/SmartTrash_Rapport.pdf')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Storage permission denied')),
                        );
                      }
                    }
                  },
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 20),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: primaryColor.withOpacity(0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SfPdfViewer.memory(
                        _pdfBytes!,
                        controller: _pdfViewerController,
                        canShowHyperlinkDialog: true,
                        scrollDirection: PdfScrollDirection.vertical,
                        pageLayoutMode: PdfPageLayoutMode.continuous,
                        onDocumentLoadFailed: (details) {
                          setState(() {
                            _errorMessage = 'Failed to load PDF: ${details.description}';
                          });
                          print('PDF Load Failed: ${details.description}');
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildInfoText(String text) {
    List<TextSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text.rich(
        TextSpan(children: spans),
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}
