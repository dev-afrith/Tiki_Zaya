import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/forgot_password_screen.dart';
import 'package:mobile/screens/main_navigation.dart';
import 'package:mobile/screens/profile_setup_screen.dart';
import 'package:mobile/screens/signup_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/widgets/auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await AuthService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      await _onAuthSuccess();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed';
      });
    } catch (e) {
      setState(() { _errorMessage = 'An unexpected error occurred'; });
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final userCred = await AuthService.signInWithGoogle();
      if (userCred != null) {
        await _onAuthSuccess();
      }
    } catch (e) {
      setState(() { _errorMessage = 'Google Sign-In failed'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _onAuthSuccess() async {
    final token = await AuthService.getIdToken();
    if (token == null) return;

    // We store the token in local storage for ApiService to use
    await ApiService.saveToken(token);

    // Check if user exists in our DB
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final profile = await ApiService.getProfile(user.uid);
      if (profile.containsKey('username')) {
        await ApiService.saveUser(profile);
        if (mounted) {
          final status = (profile['status'] ?? '').toString();
          if (status == 'blocked') {
            await AuthService.logout();
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Your account is blocked. Contact support.';
            });
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } catch (e) {
      // If 404, we assume user needs setup
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
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
            label: 'TikiZaya login page',
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
                              const AuthBrandHeader(subtitle: 'Share your moments'),
                              const SizedBox(height: 34),
                              const AuthTitle('Login Now'),
                              const SizedBox(height: 18),
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
                                autofillHints: const [AutofillHints.password],
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
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                          );
                                        },
                                  child: const Text('Forgot password?', style: TextStyle(color: Color(0xFFFF3B8E))),
                                ),
                              ),
                              const SizedBox(height: 22),
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
                                label: 'LOGIN',
                                onPressed: _isLoading ? null : _loginWithEmailPassword,
                                loading: _isLoading,
                              ),
                              const SizedBox(height: 14),
                              const AuthDividerText(text: 'Or continue with'),
                              const SizedBox(height: 14),
                              AuthOutlineButton(
                                onPressed: _isLoading ? null : _loginWithGoogle,
                                icon: Icons.g_mobiledata_rounded,
                                label: 'Continue with Google',
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Don\'t have an account? ',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withValues(alpha: 0.65),
                                      fontSize: 15,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Create One',
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
