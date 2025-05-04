import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/text_field_input.dart';
import '../resources/auth_methods.dart';
import 'competition_management_screen.dart';
import 'athlete_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedRole = 'public'; // Default role

  @override
  void initState() {
    super.initState();
    // Delay execution until context is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractArguments();
    });
  }

  void _extractArguments() {
    // Extract role information from route parameters
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      setState(() {
        _selectedRole = arguments['selectedRole'] ?? 'public';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use AuthMethods for login
      final authMethods = AuthMethods();
      String res = await authMethods.loginUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return; // Check if component is still mounted

      if (res == "success") {
        // Get user data
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();

        if (!mounted) return; // Check again if component is still mounted

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          String userRole = userData['role'] ?? 'public';

          // Navigate to different pages based on user role
          if (userRole == 'referee') {
            // Referee role navigates to competition management page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CompetitionManagementScreen(),
              ),
            );
          } else if (userRole == 'athlete') {
            // Athlete role navigates to athlete home page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AthleteHomeScreen(
                  userId: _auth.currentUser!.uid,
                ),
              ),
            );
          } else {
            // Other roles navigate to profile page
            Navigator.pushReplacementNamed(context, '/athlete-edit-profile');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User profile not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Login failed, show specific error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase authentication errors
      String errorMessage;

      if (e.code == 'user-not-found') {
        errorMessage = "No account exists with this email address";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email format";
      } else if (e.code == 'user-disabled') {
        errorMessage = "This account has been disabled";
      } else if (e.code == 'too-many-requests') {
        errorMessage = "Too many login attempts. Please try again later";
      } else {
        errorMessage = "Login failed: ${e.message}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return; // Check if component is still mounted

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Please enter your email to receive a password reset link'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (emailController.text.trim().isEmpty) {
                  throw FirebaseAuthException(
                    code: 'invalid-email',
                    message: 'Please enter your email address',
                  );
                }

                await _auth.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );

                if (!mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Password reset link has been sent to your email'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                Navigator.pop(context);
                String errorMessage;

                if (e.code == 'user-not-found') {
                  errorMessage = 'No account exists with this email address';
                } else if (e.code == 'invalid-email') {
                  errorMessage = 'Invalid email format';
                } else {
                  errorMessage = 'Failed to send reset link: ${e.message}';
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send reset link: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // Convert English role identifier to display name
  String _getRoleDisplayName(String roleIdentifier) {
    switch (roleIdentifier) {
      case 'athlete':
        return 'Athlete';
      case 'referee':
        return 'Referee';
      case 'public':
        return 'Public';
      default:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get role display name
    String roleDisplayName = _getRoleDisplayName(_selectedRole);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Back',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text(
              'Forgot Password?',
              style:
                  TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Logo or icon
                  Icon(
                    Icons.sports_gymnastics,
                    size: 80,
                    color: primaryColor.withOpacity(0.8),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Login as $roleDisplayName',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your credentials to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Email field with improved styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextFieldInput(
                      textEditingController: _emailController,
                      hintText: 'Enter your email',
                      textInputType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password field with improved styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextFieldInput(
                      textEditingController: _passwordController,
                      hintText: 'Enter your password',
                      textInputType: TextInputType.text,
                      isPass: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Use CustomButton instead of original button
                  CustomButton(
                    text: 'Login',
                    onTap: loginUser,
                    isLoading: _isLoading,
                    backgroundColor: primaryColor,
                    height: 50,
                    borderRadius: 12,
                    icon: const Icon(Icons.login),
                    hasShadow: true,
                  ),
                  const SizedBox(height: 24),
                  // Sign up option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: _navigateToRegister,
                        child: const Text(
                          "Register now",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
