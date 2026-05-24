import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'auth_service.dart'; 
import 'user_model.dart';
import 'app_settings.dart';
import 'debug_utils.dart'; 

// --- Visual Constants (NaqiAI System) ---
const _kBg = Color(0xFFF5F3EE);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2DDD5);
const _kPale = Color(0xFFDCF0E0);
const _kMid = Color(0xFF5C8E60);
const _kPrimary = Color(0xFF2A4A30);
const _kTextSec = Color(0xFF7A8A7C);
const _kAlert = Color(0xFFB86B2A);

class ProfileSettingsScreen extends StatefulWidget {
  final AppUser currentUser; 

  const ProfileSettingsScreen({super.key, required this.currentUser});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final AppSettings _appSettings = AppSettings();

  late TextEditingController _emailController;
  late TextEditingController _passwordController; 
  late TextEditingController _confirmPasswordController;

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

    _containerVolumeController = TextEditingController(text: _appSettings.containerVolume?.toString() ?? '');
    _containerWeightController = TextEditingController(text: _appSettings.containerWeight?.toString() ?? '');
    _rotageServerUrlController = TextEditingController(text: _appSettings.rotageServerUrl ?? '');

    _appSettings.loadSettings().then((_) {
      if (mounted) {
        _containerVolumeController.text = _appSettings.containerVolume?.toString() ?? '';
        _containerWeightController.text = _appSettings.containerWeight?.toString() ?? '';
        _rotageServerUrlController.text = _appSettings.rotageServerUrl ?? '';
      }
    });
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final fb_auth.User? firebaseUser = _authService.currentFirebaseAuthUser;
      if (firebaseUser == null) throw Exception("Session expriée. Veuillez vous reconnecter.");

      if (widget.currentUser.role != UserRole.admin) {
        if (_emailController.text.trim() != firebaseUser.email) {
          await firebaseUser.verifyBeforeUpdateEmail(_emailController.text.trim());
        }
      }

      if (_showPasswordFields && _passwordController.text.isNotEmpty) {
        if (_passwordController.text == _confirmPasswordController.text) {
          await firebaseUser.updatePassword(_passwordController.text);
          setState(() => _showPasswordFields = false);
        }
      }

      if (widget.currentUser.role == UserRole.worker) {
        await _appSettings.saveContainerVolume(double.tryParse(_containerVolumeController.text));
        await _appSettings.saveContainerWeight(double.tryParse(_containerWeightController.text));
      }

      if (widget.currentUser.role == UserRole.admin) {
        await _appSettings.saveRotageServerUrl(_rotageServerUrlController.text.trim());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour avec succès !")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.05), // Effet d'ombrage de fond de la pop-up
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PROFILE & SETTINGS", style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
            border: Border.all(color: _kBorder, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 40),
                    _buildUserInfoSection(),
                    if (widget.currentUser.role != UserRole.admin) ...[
                      const SizedBox(height: 20),
                      _buildPasswordSection(),
                    ],
                    if (widget.currentUser.role == UserRole.worker) ...[
                      const SizedBox(height: 20),
                      _buildSettingsSection("LIVREUR (GLOBAL)", [
                        _buildNaqiField(_containerVolumeController, "Volume Conteneur (L)", Icons.inventory_2_outlined),
                        _buildNaqiField(_containerWeightController, "Poids Max (kg)", Icons.scale_outlined),
                      ]),
                    ],
                    if (widget.currentUser.role == UserRole.admin) ...[
                      const SizedBox(height: 20),
                      _buildSettingsSection("ADMINISTRATEUR (GLOBAL)", [
                        _buildNaqiField(_rotageServerUrlController, "URL Serveur Routage", Icons.lan_outlined),
                      ]),
                    ],
                    const SizedBox(height: 40),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: _kPale, shape: BoxShape.circle),
          child: const Icon(Icons.account_circle_rounded, size: 80, color: _kPrimary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(8)),
          child: Text(
            widget.currentUser.role.name.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    return _buildSettingsSection("INFORMATIONS PERSONNELLES", [
      _buildNaqiField(
        _emailController, 
        "Adresse Email", 
        Icons.email_outlined,
        readOnly: widget.currentUser.role == UserRole.admin,
      ),
    ]);
  }

  Widget _buildPasswordSection() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("MODIFIER LE MOT DE PASSE", style: TextStyle(color: _kTextSec, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          trailing: Switch(
            value: _showPasswordFields,
            onChanged: (v) => setState(() => _showPasswordFields = v),
            activeColor: _kMid,
          ),
        ),
        if (_showPasswordFields) ...[
          const SizedBox(height: 10),
          _buildNaqiField(_passwordController, "Nouveau mot de passe", Icons.lock_outline, obscure: true),
          const SizedBox(height: 12),
          _buildNaqiField(_confirmPasswordController, "Confirmer le mot de passe", Icons.lock_clock_outlined, obscure: true),
        ],
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _kTextSec, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        ...fields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: f)),
      ],
    );
  }

  Widget _buildNaqiField(TextEditingController controller, String label, IconData icon, {bool readOnly = false, bool obscure = false}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscure,
      style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w700, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextSec, fontSize: 13, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: _kMid, size: 20),
        filled: true,
        fillColor: _kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _kMid, width: 2)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return _isLoading
        ? const CircularProgressIndicator(color: _kPrimary)
        : SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _updateProfile,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: const Text("ENREGISTRER LES MODIFICATIONS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          );
  }
}