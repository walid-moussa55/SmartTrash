import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'auth_service.dart'; // Assuming your AuthService is in auth_service.dart
import 'user_model.dart';
import 'app_settings.dart';
import 'debug_utils.dart'; // For logging

class ProfileSettingsScreen extends StatefulWidget {
  final AppUser currentUser; // Pass the AppUser object with role

  const ProfileSettingsScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final AppSettings _appSettings = AppSettings();

  // Controllers for editable fields
  late TextEditingController _emailController;
  late TextEditingController _passwordController; // For new password
  late TextEditingController _confirmPasswordController;

  // Role-specific controllers
  late TextEditingController _containerVolumeController;
  late TextEditingController _containerWeightController;
  late TextEditingController _rotageServerUrlController;

  bool _isLoading = false;
  bool _showPasswordFields = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentUser.email);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // Load initial values from AppSettings
    _appSettings.loadSettings().then((_) {
      if (mounted) {
        setState(() {
          _containerVolumeController = TextEditingController(
              text: _appSettings.containerVolume?.toString() ?? '');
          _containerWeightController = TextEditingController(
              text: _appSettings.containerWeight?.toString() ?? '');
          _rotageServerUrlController =
              TextEditingController(text: _appSettings.rotageServerUrl ?? '');
        });
      }
    });

    // Initialize controllers even if AppSettings hasn't loaded yet, they'll update
    _containerVolumeController = TextEditingController(
        text: _appSettings.containerVolume?.toString() ?? '');
    _containerWeightController = TextEditingController(
        text: _appSettings.containerWeight?.toString() ?? '');
    _rotageServerUrlController =
        TextEditingController(text: _appSettings.rotageServerUrl ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _containerVolumeController.dispose();
    _containerWeightController.dispose();
    _rotageServerUrlController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final fb_auth.User? firebaseUser = _authService.currentFirebaseAuthUser;
      if (firebaseUser == null) {
        DebugLogger.addDebugMessage("Error: Firebase user not available for profile update.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication error. Please re-login.")),
        );
        setState(() { _isLoading = false; });
        return;
      }

      // Update Email (User and Worker)
      if (widget.currentUser.role == UserRole.user ||
          widget.currentUser.role == UserRole.worker) {
        if (_emailController.text.trim() != firebaseUser.email) {
          // Email change requires re-authentication or recent login
          try {
            await firebaseUser.updateEmail(_emailController.text.trim());
            widget.currentUser.email = _emailController.text.trim(); // Update local model
            DebugLogger.addDebugMessage("Email updated successfully.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Email updated. May require re-login to take full effect.")),
            );
          } catch (e) {
            DebugLogger.addDebugMessage("Email update failed: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Email update failed: $e. Please re-login and try again.")),
            );
          }
        }
      }

      // Update Password (User and Worker)
      if (_showPasswordFields &&
          _passwordController.text.isNotEmpty &&
          (widget.currentUser.role == UserRole.user ||
              widget.currentUser.role == UserRole.worker)) {
        if (_passwordController.text == _confirmPasswordController.text) {
          try {
            await firebaseUser.updatePassword(_passwordController.text);
            _passwordController.clear();
            _confirmPasswordController.clear();
            setState(() { _showPasswordFields = false; });
            DebugLogger.addDebugMessage("Password updated successfully.");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Password updated successfully.")),
            );
          } catch (e) {
            DebugLogger.addDebugMessage("Password update failed: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Password update failed: $e. Please re-login and try again.")),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Passwords do not match.")),
          );
        }
      }

      // Update Worker-specific fields
      if (widget.currentUser.role == UserRole.worker) {
        final volume = double.tryParse(_containerVolumeController.text);
        final weight = double.tryParse(_containerWeightController.text);
        await _appSettings.saveContainerVolume(volume);
        await _appSettings.saveContainerWeight(weight);
        DebugLogger.addDebugMessage("Worker settings updated.");
      }

      // Update Admin-specific fields
      if (widget.currentUser.role == UserRole.admin) {
        await _appSettings.saveRotageServerUrl(_rotageServerUrlController.text.trim());
        DebugLogger.addDebugMessage("Admin settings updated.");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
    } catch (e) {
      DebugLogger.addDebugMessage("Profile update failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text("Profile Settings")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildUserInfoSection(),
            if (widget.currentUser.role == UserRole.user ||
                widget.currentUser.role == UserRole.worker) ...[
              const SizedBox(height: 20),
              _buildPasswordSection(),
            ],
            if (widget.currentUser.role == UserRole.worker) ...[
              const SizedBox(height: 20),
              _buildWorkerFields(),
            ],
            if (widget.currentUser.role == UserRole.admin) ...[
              const SizedBox(height: 20),
              _buildAdminFields(),
            ],
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Save Changes"),
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Role: ${widget.currentUser.role.name.toUpperCase()}",
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          readOnly: !(widget.currentUser.role == UserRole.user ||
              widget.currentUser.role == UserRole.worker),
          validator: (value) {
            if (value == null || value.isEmpty || !value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          icon: Icon(_showPasswordFields ? Icons.visibility_off : Icons.visibility),
          label: Text(_showPasswordFields ? "Cancel Password Change" : "Change Password"),
          onPressed: () {
            setState(() {
              _showPasswordFields = !_showPasswordFields;
              if (!_showPasswordFields) { // Clear fields if cancelling
                _passwordController.clear();
                _confirmPasswordController.clear();
              }
            });
          },
        ),
        if (_showPasswordFields) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: "New Password",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (value) {
              if (_showPasswordFields && (value == null || value.isEmpty || value.length < 6)) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              labelText: "Confirm New Password",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (value) {
              if (_showPasswordFields && value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ]
      ],
    );
  }


  Widget _buildWorkerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Worker Settings (Global)", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          controller: _containerVolumeController,
          decoration: const InputDecoration(
            labelText: "Container Volume (e.g., Liters)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.format_list_numbered), // Placeholder icon
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _containerWeightController,
          decoration: const InputDecoration(
            labelText: "Container Max Weight (e.g., kg)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.scale),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildAdminFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Admin Settings (Global)", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          controller: _rotageServerUrlController,
          decoration: const InputDecoration(
            labelText: "Rotage Server URL",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }
}