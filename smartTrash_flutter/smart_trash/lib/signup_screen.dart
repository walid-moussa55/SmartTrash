import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'theme_provider.dart';
import 'app_theme.dart';
import 'user_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.user;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Les mots de passe ne correspondent pas."),
          backgroundColor: AppTheme.alert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await AuthService().registerWithEmailPassword(
      email, password, role: _selectedRole,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? "Échec de l'inscription."),
          backgroundColor: AppTheme.alert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  InputDecoration _fieldStyle({
    required String hint,
    required IconData prefixData,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      prefixIcon: Icon(prefixData, color: Colors.black87, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF4F4F4),
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(color: AppTheme.alert, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      body: Container(
        // Subtle background gradient from pale green to beige
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: [
              AppTheme.pale.withAlpha(200),
              AppTheme.bg,
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── DÉCORS ENVIRONNEMENTAUX EN ARRIÈRE-PLAN ──
            Positioned(
              top: -80,
              left: -80,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(Icons.energy_savings_leaf_outlined, size: 380, color: AppTheme.primary.withAlpha(8)),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: Transform.rotate(
                angle: 0.3,
                child: Icon(Icons.recycling_rounded, size: 480, color: AppTheme.primary.withAlpha(8)),
              ),
            ),
            Positioned(
              top: size.height * 0.35,
              right: -50,
              child: Transform.rotate(
                angle: -0.15,
                child: Icon(Icons.delete_outline_rounded, size: 250, color: AppTheme.primary.withAlpha(8)),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -40,
              child: Transform.rotate(
                angle: 0.25,
                child: Icon(Icons.eco_outlined, size: 280, color: AppTheme.primary.withAlpha(8)),
              ),
            ),
            // ── CONTENU PRINCIPAL ──
            SafeArea(
              child: Column(
                children: [
                  // ── TOP BAR ──
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48.0 : 24.0,
                      vertical: 24.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NaqiAI',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.question_mark_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── CENTER CARD ──
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Container(
                          width: 540, // Max width for card
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDesktop ? 10 : 15),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // ── DÉCORS INTERNES ──
                              Positioned(
                                top: -60,
                                right: -40,
                                child: Transform.rotate(
                                  angle: 0.2,
                                  child: Icon(Icons.park_rounded, size: 200, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              Positioned(
                                bottom: -40,
                                left: -40,
                                child: Transform.rotate(
                                  angle: -0.3,
                                  child: Icon(Icons.water_drop_outlined, size: 160, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              Positioned(
                                top: 180,
                                left: -40,
                                child: Transform.rotate(
                                  angle: 0.15,
                                  child: Icon(Icons.compost, size: 120, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              Positioned(
                                top: 20,
                                left: 30,
                                child: Transform.rotate(
                                  angle: -0.2,
                                  child: Icon(Icons.emoji_nature_outlined, size: 80, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: -20,
                                child: Transform.rotate(
                                  angle: -0.1,
                                  child: Icon(Icons.solar_power_outlined, size: 140, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              Positioned(
                                top: 140,
                                right: -30,
                                child: Transform.rotate(
                                  angle: 0.25,
                                  child: Icon(Icons.wind_power_outlined, size: 130, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                left: 140,
                                child: Transform.rotate(
                                  angle: -0.15,
                                  child: Icon(Icons.battery_charging_full_rounded, size: 100, color: const Color(0xFF9EAC9F).withAlpha(65)),
                                ),
                              ),
                              // ── FORMULAIRE PRINCIPAL ──
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Icon Logo
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Titles
                                      const Text(
                                        'Inscription',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Rejoignez NaqiAI pour un avenir durable.",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 36),

                                      // Email Field
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'EMAIL PROFESSIONNEL',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        decoration: _fieldStyle(
                                          hint: 'exemple@naqi.ma',
                                          prefixData: Icons.email_outlined,
                                        ),
                                        validator: (v) =>
                                            (v == null || v.isEmpty || !v.contains('@'))
                                                ? 'Email invalide'
                                                : null,
                                      ),
                                      const SizedBox(height: 24),

                                      // Password Field
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'MOT DE PASSE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        decoration: _fieldStyle(
                                          hint: '••••••••',
                                          prefixData: Icons.lock_outline,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: Colors.black45,
                                              size: 20,
                                            ),
                                            onPressed: () => setState(
                                                () => _obscurePassword = !_obscurePassword),
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) return 'Mot de passe requis';
                                          if (v.length < 8) return 'Minimum 8 caractères';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 24),

                                      // Confirm Password Field
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'CONFIRMER MOT DE PASSE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        decoration: _fieldStyle(
                                          hint: '••••••••',
                                          prefixData: Icons.lock_reset_outlined,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: Colors.black45,
                                              size: 20,
                                            ),
                                            onPressed: () => setState(
                                                () => _obscureConfirmPassword = !_obscureConfirmPassword),
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) return 'Confirmez le mot de passe';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 24),

                                      // Role Dropdown
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'TYPE DE COMPTE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<UserRole>(
                                        value: _selectedRole,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        dropdownColor: Colors.white,
                                        decoration: _fieldStyle(
                                          hint: '',
                                          prefixData: Icons.person_outline,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: UserRole.user,
                                            child: Text('Utilisateur standard'),
                                          ),
                                          DropdownMenuItem(
                                            value: UserRole.worker,
                                            child: Text('Agent de collecte'),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedRole = v);
                                        },
                                      ),
                                      const SizedBox(height: 32),

                                      // Sign Up Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _signup,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: const [
                                                    Text(
                                                      "Créer un compte",
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.arrow_forward, size: 18),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),

                                      // Login Link
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Déjà un compte? ',
                                            style: TextStyle(fontSize: 13, color: Colors.black54),
                                          ),
                                          GestureDetector(
                                            onTap: () => Navigator.pushReplacement(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (_, __, ___) =>
                                                    const LoginScreen(),
                                                transitionsBuilder: (_, a, __, c) =>
                                                    FadeTransition(opacity: a, child: c),
                                                transitionDuration:
                                                    const Duration(milliseconds: 300),
                                              ),
                                            ),
                                            child: const Text(
                                              "Se connecter",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── FOOTER ──
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48.0 : 24.0,
                      vertical: 24.0,
                    ),
                    child: isDesktop
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '© 2024 NAQIAI. INTELLIGENT SUSTAINABILITY.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                  color: AppTheme.mid,
                                ),
                              ),
                              Row(
                                children: [
                                  _footerLink('PRIVACY POLICY'),
                                  const SizedBox(width: 20),
                                  _footerLink('TERMS OF SERVICE'),
                                  const SizedBox(width: 32),
                                  _darkModeToggle(),
                                ],
                              )
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _footerLink('PRIVACY POLICY'),
                                  const SizedBox(width: 20),
                                  _footerLink('TERMS OF SERVICE'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _darkModeToggle(),
                              const SizedBox(height: 16),
                              const Text(
                                '© 2024 NAQIAI. INTELLIGENT SUSTAINABILITY.',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                  color: AppTheme.mid,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerLink(String text) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: AppTheme.mid,
        ),
      ),
    );
  }

  Widget _darkModeToggle() {
    return GestureDetector(
      onTap: () => ThemeProvider().toggleTheme(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(15),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.dark_mode_rounded, size: 14, color: Colors.black87),
            SizedBox(width: 8),
            Text(
              'Mode sombre',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
