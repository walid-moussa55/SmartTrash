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
  XFile? _imageFile;
  String _predictionResult = "No image selected. Please choose or take a photo.";
  bool _isLoading = false; // For image prediction loading
  String? _errorMessage;
  String? _serverUrl;
  String? _predictedTrashType; // Stores the predicted trash type

  bool _isSearchingBins = false; // New: Loading state for bin search

  final BinSearchService _binSearchService = BinSearchService(); // New: Instance of the service

  // Initialize the AppSettings instance
  final AppSettings appSettings = AppSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServerUrl();
    });
  }

  Future<void> _loadServerUrl() async {
    // Correctly access AppSettings using Provider
    await appSettings.loadSettings(); // Ensure settings are loaded from Firebase
    if (!mounted) return;
    setState(() {
      _serverUrl = appSettings.rotageServerUrl;
      if (_serverUrl == null || _serverUrl!.isEmpty) {
        _errorMessage = "Server URL is not configured in app settings.";
        _predictionResult = "Cannot connect to server without a URL.";
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _predictionResult = "No image selected. Please choose or take a photo.";
      _imageFile = null; // Clear previous image on new selection
      _predictedTrashType = null; // Clear previous prediction type
    });
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
          _predictionResult = "Image selected. Ready to predict.";
        });
      } else {
        setState(() {
          _predictionResult = "No image selected.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
        _predictionResult = "Error picking image.";
      });
      DebugLogger.addDebugMessage('Error picking image: $e');
    }
  }

  Future<void> _predictTrashType() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      setState(() {
        _errorMessage = "Server URL is not configured. Please set it in app settings.";
      });
      return;
    }

    if (_imageFile == null) {
      setState(() {
        _errorMessage = "Please select an image first.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionResult = "Predicting...";
      _errorMessage = null;
      _predictedTrashType = null; // Clear old prediction
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/predict/trash_type'), // Confirm this is the correct Flask endpoint
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await _imageFile!.readAsBytes(),
          filename: _imageFile!.name,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String predictedClass = responseData['predicted_class'] ?? 'Unknown'; // Ensure 'class' matches your server's JSON key

        setState(() {
          _predictedTrashType = predictedClass; // Store the predicted type
          _predictionResult = "Predicted Type: $predictedClass";
        });

      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode} - ${response.reasonPhrase ?? 'Unknown'}\n${response.body}';
          _predictionResult = "Prediction failed.";
        });
        DebugLogger.addDebugMessage('Server error: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network or parsing error: $e';
        _predictionResult = "Prediction failed. Check server connection.";
      });
      DebugLogger.addDebugMessage('Network or parsing error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // NEW: Method to trigger bin search and display results
  Future<void> _searchAndDisplayBins() async {
    if (_predictedTrashType == null || _predictedTrashType == 'Unknown') {
      setState(() {
        _errorMessage = "Cannot search for bins, trash type is unknown.";
      });
      return;
    }

    setState(() {
      _isSearchingBins = true;
      _errorMessage = null;
    });

    try {
      final bins = await _binSearchService.findNearestBinsOfType(_predictedTrashType!);
      if (mounted) {
        setState(() {
          if (bins.isEmpty) {
            _predictionResult = "No bins found for type '$_predictedTrashType' near you.";
          } else {
            _predictionResult = "Predicted Type: $_predictedTrashType"; // Reaffirm prediction
          }
        });
        _showBinListDialog(bins); // Show dialog with bin names
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error searching for bins: ${e.toString()}"; // Show full error from service
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error searching for bins: ${e.toString().split(':').last.trim()}")),
        );
      }
      DebugLogger.addDebugMessage("Error searching for bins: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingBins = false;
        });
      }
    }
  }

  // NEW: Dialog to show list of bin names
  void _showBinListDialog(List<TrashBin> bins) {
    final parentContext = context;
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Nearby $_predictedTrashType Bins'),
          content: bins.isEmpty
              ? const Text('No bins of this type found nearby.')
              : SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(dialogContext).size.height * 0.45,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bins.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final bin = bins[index];
                      return ListTile(
                        leading: Icon(Icons.delete_outline, color: Theme.of(dialogContext).colorScheme.primary),
                        title: Text(bin.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Niveau: ${bin.trashLevel.toStringAsFixed(0)}% • Type: ${bin.trashType}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.directions, color: Colors.blue, size: 28),
                          tooltip: 'Itinéraire',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (!mounted) return;
                            Navigator.push(
                              parentContext,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => MapScreen(
                                  trashBins: [bin],
                                  initialTrashBin: bin,
                                  showRoute: true,
                                ),
                                transitionsBuilder: (_, a, __, c) {
                                  final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
                                  return SlideTransition(position: offset, child: FadeTransition(opacity: a, child: c));
                                },
                                transitionDuration: const Duration(milliseconds: 350),
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          Navigator.push(
                            parentContext,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => MapScreen(
                                trashBins: [bin],
                                initialTrashBin: bin,
                                showRoute: true,
                              ),
                              transitionsBuilder: (_, a, __, c) {
                                final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
                                return SlideTransition(position: offset, child: FadeTransition(opacity: a, child: c));
                              },
                              transitionDuration: const Duration(milliseconds: 350),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trash Type Predictor"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Image Display Area
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 2),
                ),
                alignment: Alignment.center,
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_search, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 10),
                          Text("No image selected", style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: kIsWeb
                            ? Image.network(_imageFile!.path, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildImageErrorWidget())
                            : Image.file(File(_imageFile!.path), width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildImageErrorWidget()),
                      ),
              ),
              const SizedBox(height: 30),

              // Image Selection Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(icon: Icons.camera_alt, label: 'Camera', onPressed: () => _pickImage(ImageSource.camera), color: theme.colorScheme.secondary),
                  const SizedBox(width: 16),
                  _buildActionButton(icon: Icons.photo_library, label: 'Gallery', onPressed: () => _pickImage(ImageSource.gallery), color: theme.colorScheme.secondary),
                ],
              ),
              const SizedBox(height: 30),

              // Predict button
              _isLoading
                  ? CircularProgressIndicator(color: theme.colorScheme.primary)
                  : (_serverUrl == null || _serverUrl!.isEmpty)
                      ? Text(_errorMessage ?? "Server URL not configured.", style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)
                      : SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _predictTrashType,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Predict Trash Type'),
                          ),
                        ),
              const SizedBox(height: 30),

              // Result
              Container(
                padding: const EdgeInsets.all(20.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_predictionResult, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                      ),
                  ],
                ),
              ),

              // Nearest Bins button
              if (_predictedTrashType != null && _predictedTrashType != 'Unknown') ...[
                const SizedBox(height: 24),
                _isSearchingBins
                    ? CircularProgressIndicator(color: theme.colorScheme.primary)
                    : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _searchAndDisplayBins,
                          icon: const Icon(Icons.location_on),
                          label: Text('Find Nearest $_predictedTrashType Bins'),
                        ),
                      ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function for image error display
  Widget _buildImageErrorWidget() {
    return Container(
      color: Colors.red.withValues(alpha: 0.2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.redAccent, size: 60),
          const SizedBox(height: 10),
          const Text(
            'Error loading image',
            style: TextStyle(color: Colors.redAccent, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper function to build consistent action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isLarge = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isLarge ? 24 : 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: isLarge
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
