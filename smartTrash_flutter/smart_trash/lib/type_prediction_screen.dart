import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:smart_trash/app_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Import the new bin search service and models
import 'package:smart_trash/bin_search_service.dart';
import 'package:smart_trash/home_screen.dart' show TrashBin; // Only TrashBin is needed here now

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

  List<TrashBin> _foundBins = []; // New: Stores the list of found bins
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
      _foundBins = []; // Clear previous search results
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
      print('Error picking image: $e');
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
      _foundBins = []; // Clear old bin results
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/predict/trash_type'), // Confirm this is the correct Flask endpoint
      );

      request.files.add(
        await http.MultipartFile.fromBytes(
          'file', // This should match the name expected by your server (e.g., Flask's request.files['image'])
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
        print('Server error: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network or parsing error: $e';
        _predictionResult = "Prediction failed. Check server connection.";
      });
      print('Network or parsing error: $e');
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
      _foundBins = []; // Clear previous results
      _errorMessage = null;
    });

    try {
      final bins = await _binSearchService.findNearestBinsOfType(_predictedTrashType!);
      if (mounted) {
        setState(() {
          _foundBins = bins;
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
      print("Error searching for bins: $e");
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Nearby $_predictedTrashType Bins'),
          content: bins.isEmpty
              ? const Text('No bins of this type found nearby.')
              : SizedBox(
                  width: double.maxFinite,
                  // Constrain height if list can be very long
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: bins.length,
                    itemBuilder: (context, index) {
                      final bin = bins[index];
                      return ListTile(
                        leading: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                        title: Text(bin.name, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Level: ${bin.trashLevel.toStringAsFixed(1)}% | Lat: ${bin.location.latitude.toStringAsFixed(4)}, Lon: ${bin.location.longitude.toStringAsFixed(4)}',
                        ),
                        onTap: () {
                          // Optionally, you could navigate to MapScreen here for this specific bin
                          // Navigator.of(context).pop(); // Close dialog
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => MapScreen(trashBins: [bin], initialTrashBin: bin)));
                        },
                      );
                    },
                  ),
                ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
        title: const Text("Trash Type Predictor"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
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
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_search, size: 100, color: fadedTextColor),
                          SizedBox(height: 10),
                          Text(
                            "No image selected",
                            style: TextStyle(color: fadedTextColor, fontSize: 16),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: kIsWeb
                            ? Image.network(
                                _imageFile!.path,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImageErrorWidget();
                                },
                              )
                            : Image.file(
                                File(_imageFile!.path),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImageErrorWidget();
                                },
                              ),
                      ),
              ),
              const SizedBox(height: 40),

              // Image Selection Buttons
              Wrap(
                spacing: 15,
                runSpacing: 15,
                alignment: WrapAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.camera_alt,
                    label: 'Take Photo',
                    onPressed: () => _pickImage(ImageSource.camera),
                    color: accentColor,
                  ),
                  _buildActionButton(
                    icon: Icons.photo_library,
                    label: 'Choose from Gallery',
                    onPressed: () => _pickImage(ImageSource.gallery),
                    color: accentColor,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Predict button and loading indicator
              _isLoading
                  ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
                  : _serverUrl == null || _serverUrl!.isEmpty
                      ? Text(
                          _errorMessage ?? "Server URL not configured.",
                          style: TextStyle(color: Colors.redAccent, fontSize: 16),
                          textAlign: TextAlign.center,
                        )
                      : _buildActionButton(
                          icon: Icons.cloud_upload,
                          label: 'Predict Trash Type',
                          onPressed: _predictTrashType,
                          color: primaryColor,
                          isLarge: true,
                        ),

              const SizedBox(height: 40),

              // Prediction Result Display
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
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _predictionResult,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: Text(
                          'Error: $_errorMessage',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // NEW: "Show Nearest Bins" button (only visible after a prediction)
              if (_predictedTrashType != null && _predictedTrashType != 'Unknown') ...[
                const SizedBox(height: 30),
                _isSearchingBins
                    ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))
                    : _buildActionButton(
                        icon: Icons.location_on,
                        label: 'Show Nearest $_predictedTrashType Bins',
                        onPressed: _searchAndDisplayBins, // Calls the new search and display method
                        color: primaryColor.withOpacity(0.8), // Slightly subdued accent
                        isLarge: true,
                      ),
              ],
              const SizedBox(height: 20), // Spacing at the bottom
            ],
          ),
        ),
      ),
    );
  }

  // Helper function for image error display
  Widget _buildImageErrorWidget() {
    return Container(
      color: Colors.red.withOpacity(0.2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.redAccent, size: 60),
          SizedBox(height: 10),
          Text(
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
      icon: Icon(icon, size: isLarge ? 28 : 22),
      label: Text(label, style: TextStyle(fontSize: isLarge ? 20 : 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: isLarge
            ? const EdgeInsets.symmetric(horizontal: 40, vertical: 20)
            : const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: color.withOpacity(0.5),
        elevation: 8,
      ),
    );
  }
}
