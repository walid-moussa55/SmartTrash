import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'auth_service.dart';
import 'login_screen.dart';
import 'user_model.dart';
import 'app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  UserRole _selectedRole = UserRole.user;

  late AnimationController _animController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final result = await AuthService().registerWithEmailPassword(email, password, role: _selectedRole);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? "Signup failed."), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)));
    final fadeIn = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animController, curve: const Interval(0.1, 0.6)));

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient Background ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F0C29), const Color(0xFF302B63), const Color(0xFF24243e)]
                    : [const Color(0xFFE8EAF6), const Color(0xFFE3F2FD), Colors.white],
              ),
            ),
          ),
          // ── Floating Decorative Circles ──
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, _) {
              final v = _floatController.value;
              return Stack(
                children: [
                  Positioned(
                    top: size.height * 0.05 + 8 * math.sin(v * math.pi),
                    right: -30,
                    child: _decorCircle(100, AppTheme.primaryPurple.withAlpha(isDark ? 25 : 35)),
                  ),
                  Positioned(
                    bottom: size.height * 0.1 - 6 * math.cos(v * math.pi),
                    left: -40,
                    child: _decorCircle(120, const Color(0xFF00BCD4).withAlpha(isDark ? 20 : 30)),
                  ),
                ],
              );
            },
          ),
          // ── Main Content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SlideTransition(
                  position: slideUp,
                  child: FadeTransition(
                    opacity: fadeIn,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(200),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 120)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(isDark ? 40 : 15), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Logo ──
                            AnimatedBuilder(
                              animation: _floatController,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, 3 * math.sin(_floatController.value * math.pi)),
                                child: child,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryPurple.withAlpha(30), const Color(0xFF00BCD4).withAlpha(20)],
                                  ),
                                ),
                                child: Image.asset('assets/images/logo.png', height: 50),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [AppTheme.primaryPurple, const Color(0xFF00BCD4)],
                              ).createShader(bounds),
                              child: Text("Create Account", style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: -0.5,
                              )),
                            ),
                            const SizedBox(height: 4),
                            Text("Join NaqiAI today", style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14,
                            )),
                            const SizedBox(height: 28),

                            // ── Fields ──
                            _styledField(
                              controller: _emailController,
                              label: "Email",
                              icon: Icons.email_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter your email';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _styledField(
                              controller: _passwordController,
                              label: "Password",
                              icon: Icons.lock_outline,
                              isDark: isDark,
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter a password';
                                if (v.length < 8) return 'Min 8 characters';
                                if (!v.contains(RegExp(r'[0-9]'))) return 'Include at least one number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _styledField(
                              controller: _confirmPasswordController,
                              label: "Confirm Password",
                              icon: Icons.lock_reset_outlined,
                              isDark: isDark,
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Confirm your password';
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // ── Role Dropdown ──
                            DropdownButtonFormField<UserRole>(
                              initialValue: _selectedRole,
                              decoration: InputDecoration(
                                labelText: "Account Type",
                                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryPurple.withAlpha(180)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: const [
                                DropdownMenuItem(value: UserRole.user, child: Text('Regular User')),
                                DropdownMenuItem(value: UserRole.worker, child: Text('Collection Worker')),
                              ],
                              onChanged: (v) { if (v != null) setState(() => _selectedRole = v); },
                              validator: (v) => v == null ? 'Select an account type' : null,
                            ),
                            const SizedBox(height: 28),

                            // ── Gradient Sign Up Button ──
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryPurple, Color(0xFF00BCD4)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.primaryPurple.withAlpha(80), blurRadius: 15, offset: const Offset(0, 5)),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                      : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // ── Login Link ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Already have an account?", style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                )),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacement(context, PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => const LoginScreen(),
                                    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                                  )),
                                  child: Text("Log in", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryPurple.withAlpha(180)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}