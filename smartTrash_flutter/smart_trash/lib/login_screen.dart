import 'package:flutter/material.dart';
import 'package:smart_trash/user_model.dart';
import 'auth_service.dart';
import 'debug_utils.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'user_model.dart';    // Ensure this path is correct for your UserRole enum
import 'debug_utils.dart';  // Ensure this path is correct for DebugLogger

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Optional: for form validation
  bool _isLoading = false; // To show loading indicator

  void _login() async {
    // Optional: Add form validation
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    setState(() { _isLoading = true; }); // Show loading indicator

    final email = _emailController.text.trim(); // Trim whitespace
    final password = _passwordController.text;

    final AppUser? appUser = await AuthService().loginWithEmailPassword(email, password);

    // Check if the widget is still mounted before navigating or showing snackbar
    if (!mounted) return;

    setState(() { _isLoading = false; }); // Hide loading indicator

    if ( appUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(currentUser: appUser)), // Pass to HomeScreen
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login failed. Please check your credentials."),
          backgroundColor: Colors.redAccent, // More visible error
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive adjustments
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Remove AppBar for a cleaner look, handle back navigation if needed elsewhere
      // appBar: AppBar(title: Text("Login")),
      body: SafeArea( // Ensure content doesn't overlap with status bar/notches
        child: Center(
          child: SingleChildScrollView( // Prevent overflow on smaller screens
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08), // Responsive padding
            child: Form( // Optional: Wrap in Form for validation
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Logo ---
                  Image.asset(
                    'assets/images/logo.png', // <<< Your logo path
                    height: screenHeight * 0.15, // Responsive height
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // --- Welcoming Text ---
                  Text(
                    "Welcome Back!",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Log in to monitor your smart trash bins.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  // --- Email Field ---
                  TextFormField( // Use TextFormField for validation features
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0), // Rounded corners
                      ),
                      filled: true, // Add subtle background fill
                      fillColor: Colors.grey[100],
                    ),
                    // Optional: Add validation
                    // validator: (value) {
                    //   if (value == null || value.isEmpty || !value.contains('@')) {
                    //     return 'Please enter a valid email';
                    //   }
                    //   return null;
                    // },
                  ),
                  const SizedBox(height: 16),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      // Add suffix icon for password visibility toggle if needed
                    ),
                    obscureText: true,
                    // Optional: Add validation
                    // validator: (value) {
                    //   if (value == null || value.isEmpty) {
                    //     return 'Please enter your password';
                    //   }
                    //   return null;
                    // },
                  ),
                  const SizedBox(height: 30),

                  // --- Login Button ---
                  _isLoading
                      ? const CircularProgressIndicator() // Show loading indicator
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50), // Full width button
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0), // Match text field corners
                      ),
                      backgroundColor: Theme.of(context).primaryColor, // Use theme color
                      foregroundColor: Colors.white, // Text color
                    ),
                    onPressed: _login,
                    child: const Text("Login", style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 20),

                  // --- Sign Up Link ---
                  Row( // Keep text and button on the same line
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            // Use a Fade transition for smoother navigation
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => SignupScreen(),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                        child: Text(
                            "Sign up",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}