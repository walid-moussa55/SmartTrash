import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'signup_screen.dart';
import 'theme_provider.dart';
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late AnimationController _floatController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic)));

    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final result = await AuthService().loginWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() { _isLoading = false; });

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? "Login failed."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background gradient ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D1B2A), const Color(0xFF1B2838), const Color(0xFF0D1B2A)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFE3F2FD), const Color(0xFFF3E5F5)],
              ),
            ),
          ),
          // ── Floating decorative circles ──
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final v = _floatController.value;
              return Stack(
                children: [
                  Positioned(
                    top: size.height * 0.05 + math.sin(v * math.pi) * 15,
                    right: -30 + math.cos(v * math.pi) * 10,
                    child: _glowCircle(120, theme.colorScheme.primary.withAlpha(30)),
                  ),
                  Positioned(
                    bottom: size.height * 0.1 + math.cos(v * math.pi) * 20,
                    left: -40 + math.sin(v * math.pi) * 12,
                    child: _glowCircle(160, theme.colorScheme.secondary.withAlpha(25)),
                  ),
                  Positioned(
                    top: size.height * 0.35 + math.sin(v * math.pi * 0.7) * 10,
                    left: size.width * 0.7,
                    child: _glowCircle(80, Colors.green.withAlpha(20)),
                  ),
                ],
              );
            },
          ),
          // ── Content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SlideTransition(
                  position: _slideUp,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Logo + Branding ──
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, math.sin(_floatController.value * math.pi) * 6),
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    theme.colorScheme.primary.withAlpha(40),
                                    theme.colorScheme.primary.withAlpha(10),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withAlpha(30),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Image.asset('assets/images/logo.png', height: 72),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                            ).createShader(bounds),
                            child: Text(
                              "NaqiAI",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                fontSize: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Intelligent Waste Management",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 44),

                          // ── Glass Card ──
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.white).withAlpha(isDark ? 15 : 200),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.grey).withAlpha(isDark ? 20 : 40),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(isDark ? 40 : 15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // ── Email Field ──
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: "Email",
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(60)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: (isDark ? Colors.white : Colors.grey).withAlpha(isDark ? 8 : 15),
                                  ),
                                  validator: (v) =>
                                    (v == null || v.isEmpty || !v.contains('@')) ? 'Enter a valid email' : null,
                                ),
                                const SizedBox(height: 18),

                                // ── Password Field ──
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(60)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: (isDark ? Colors.white : Colors.grey).withAlpha(isDark ? 8 : 15),
                                  ),
                                  validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Enter your password' : null,
                                ),
                                const SizedBox(height: 28),

                                // ── Login Button with gradient ──
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary.withAlpha(80),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isLoading
                                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                        : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Sign Up Link ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account?", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => const SignupScreen(),
                                    transitionsBuilder: (_, a, __, c) =>
                                        FadeTransition(opacity: a, child: SlideTransition(
                                          position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(a),
                                          child: c,
                                        )),
                                    transitionDuration: const Duration(milliseconds: 400),
                                  ),
                                ),
                                child: Text("Sign up", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ),
                            ],
                          ),

                          // ── Theme Toggle ──
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withAlpha(isDark ? 10 : 8),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: IconButton(
                              onPressed: () => ThemeProvider().toggleTheme(),
                              icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
                              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                            ),
                          ),
                        ],
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

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 10)],
      ),
    );
  }
}