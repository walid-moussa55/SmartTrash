import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'user_model.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Optional: Add confirm password controller
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Optional: for form validation
  bool _isLoading = false; // To show loading indicator
  UserRole _selectedRole = UserRole.user;  // Default role

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signup() async {
    // Optional: Add form validation
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Optional: Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!"), backgroundColor: Colors.orange),
      );
      return;
    }


    setState(() { _isLoading = true; }); // Show loading indicator

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final user = await AuthService().registerWithEmailPassword(email, password, role: _selectedRole);

    if (!mounted) return; // Check if still mounted

    setState(() { _isLoading = false; }); // Hide loading indicator

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(currentUser: user)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Signup failed. Please try again later or use a different email."),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Logo ---
                  Image.asset(
                    'assets/images/logo.png', // <<< Your logo path
                    height: screenHeight * 0.12, // Slightly smaller than login? Adjust as needed
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // --- Welcoming Text ---
                  Text(
                    "Create Account",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Get started by filling out the form below.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  // --- Email Field ---
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
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
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (!value.contains(RegExp(r'[0-9]'))) {
                        return 'Password must contain at least one number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Optional: Confirm Password Field ---
                  TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        prefixIcon: Icon(Icons.lock_reset_outlined, color: Theme.of(context).primaryColor),
                        border: OutlineInputBorder(
                           borderRadius: BorderRadius.circular(12.0),
                         ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      obscureText: true,
                      validator: (value) {
                         if (value == null || value.isEmpty) {
                           return 'Please confirm your password';
                         }
                         if (value != _passwordController.text) {
                           return 'Passwords do not match';
                         }
                         return null;
                       },
                      ),
                  const SizedBox(height: 30),

                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: "Account Type",
                      prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: [
                      DropdownMenuItem(
                        value: UserRole.user,
                        child: Text('Regular User'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.worker,
                        child: Text('Collection Worker'),
                      ),
                    ],
                    onChanged: (UserRole? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select an account type';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),


                  const SizedBox(height: 30), // Adjust spacing if confirm password is removed

                  // --- Sign Up Button ---
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _signup,
                    child: const Text("Sign Up", style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 20),

                  // --- Login Link ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder( // Use transition
                              pageBuilder: (_, __, ___) => LoginScreen(),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        },
                        child: Text(
                            "Log in",
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