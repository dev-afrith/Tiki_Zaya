import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/screens/main_navigation.dart';
import 'package:mobile/screens/profile_setup_screen.dart';
import 'package:mobile/screens/verification_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/widgets/auth_ui.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your display name';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+'), '')
      .replaceAll(RegExp(r'_+$'), '');
    final safeBase = base.isEmpty ? 'user' : base;
    final generatedUsername = '${safeBase}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    try {
      final result = await ApiService.register(generatedUsername, email, password);

      if (result.containsKey('email')) {
        // Success - OTP sent
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationScreen(email: result['email']),
            ),
          );
        }
      } else {
        setState(() { _errorMessage = result['message'] ?? 'Signup failed'; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Connection error. Is the server running?'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _signupWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await AuthService.signInWithGoogle();
      if (credential == null) return;

      final token = await AuthService.getIdToken();
      if (token != null) {
        await ApiService.saveToken(token);
      }

      final user = AuthService.currentUser;
      if (user == null || !mounted) return;

      try {
        final profile = await ApiService.getProfile(user.uid);
        await ApiService.saveUser(profile);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Google sign-up failed';
      });
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
      body: AuthBackground(
        child: AuthScaffoldBody(
          child: Semantics(
            container: true,
            label: 'TikiZaya sign up page',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const AuthBrandHeader(subtitle: 'Create your account to share moments'),
                              const SizedBox(height: 30),
                              const AuthTitle('Sign Up Now'),
                              const SizedBox(height: 18),
                              AuthTextField(
                                controller: _nameController,
                                hint: 'Name (Display Name)',
                                icon: Icons.person_outline,
                                autofillHints: const [AutofillHints.name],
                              ),
                              const SizedBox(height: 14),
                              AuthTextField(
                                controller: _emailController,
                                hint: 'Email Address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                              ),
                              const SizedBox(height: 14),
                              AuthTextField(
                                controller: _passwordController,
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                obscure: _obscurePassword,
                                autofillHints: const [AutofillHints.newPassword],
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const AuthDividerText(text: 'Or continue with'),
                              const SizedBox(height: 14),
                              AuthOutlineButton(
                                onPressed: _isLoading ? null : _signupWithGoogle,
                                icon: Icons.g_mobiledata_rounded,
                                label: 'Continue with Google',
                              ),
                              const SizedBox(height: 16),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFFF3B8E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              AuthPrimaryButton(
                                label: 'SIGN UP',
                                onPressed: _isLoading ? null : _signup,
                                loading: _isLoading,
                              ),
                              const SizedBox(height: 22),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 15,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      'Login',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFFF3B8E),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
