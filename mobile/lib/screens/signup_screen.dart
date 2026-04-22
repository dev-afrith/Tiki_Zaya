import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/screens/main_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/widgets/auth_ui.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        if (_ageFrom(picked) < 13) {
          _errorMessage = 'You must be at least 13 years old to use TikiZaya';
        } else {
          _errorMessage = null;
        }
      });
    }
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your display name';
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username)) {
      setState(() {
        _errorMessage = 'Username must be 3-30 characters with letters, numbers, or underscores';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
      });
      return;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() {
        _errorMessage = 'Valid 10-digit phone number strictly required (digits only)';
      });
      return;
    }

    if (_dateOfBirth == null || _ageFrom(_dateOfBirth!) < 13) {
      setState(() {
        _errorMessage = 'You must be at least 13 years old to use TikiZaya';
      });
      return;
    }

    if (password.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
      setState(() {
        _errorMessage = 'Password must be 8+ characters with a letter and number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.register(
        username: username,
        email: email,
        phone: phone,
        password: password,
        dateOfBirth: _dateOfBirth!,
        name: name,
      );

      if ((result['accessToken'] ?? result['token']) != null) {
        await ApiService.saveSession(result);
        await NotificationService.initialize();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
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
                                controller: _usernameController,
                                hint: 'Username',
                                icon: Icons.alternate_email_rounded,
                                autofillHints: const [AutofillHints.username],
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
                                controller: _phoneController,
                                hint: 'Phone Number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                autofillHints: const [AutofillHints.telephoneNumber],
                              ),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: _isLoading ? null : _pickDob,
                                child: AbsorbPointer(
                                  child: AuthTextField(
                                    controller: _dobController,
                                    hint: 'Date of Birth',
                                    icon: Icons.cake_outlined,
                                  ),
                                ),
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
