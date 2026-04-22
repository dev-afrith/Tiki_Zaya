import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/notification_service.dart';
import 'package:mobile/screens/forgot_password_screen.dart';
import 'package:mobile/screens/main_navigation.dart';
import 'package:mobile/screens/signup_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/widgets/auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic>? _phoneAccounts;
  String? _selectedUsername;
  String? _selectedDisplayName;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleNextOrLogin() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username or phone number');
      return;
    }

    final isPhone = RegExp(r'^\d{10}$').hasMatch(identifier);

    // If it's a phone number and we haven't selected an account yet
    if (isPhone && _phoneAccounts == null && _selectedUsername == null) {
      setState(() { _isLoading = true; _errorMessage = null; });
      try {
        final accounts = await ApiService.getAccountsByPhone(identifier);
        if (accounts.isEmpty) {
          setState(() => _errorMessage = 'No accounts linked to this phone number');
        } else if (accounts.length == 1) {
          // Skip selection, direct to password
          setState(() {
            _selectedUsername = accounts[0]['username'];
            _selectedDisplayName = accounts[0]['displayName'];
          });
        } else {
          // Show selection
          setState(() => _phoneAccounts = accounts);
        }
      } catch (e) {
        setState(() => _errorMessage = 'Connection error. Please try again.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Either it's a username explicitly typed, OR we have a selected username
    final loginTarget = _selectedUsername ?? identifier;
    final password = _passwordController.text;

    // If it's not a phone, we need to ask for password simultaneously if empty
    // Actually, if it's not a phone, the UI will show password field immediately.
    // So if password is empty, block.
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final result = await ApiService.login(loginTarget, password);
      if ((result['accessToken'] ?? result['token']) != null && result['user'] is Map<String, dynamic>) {
        await ApiService.saveSession(result);
        await NotificationService.initialize();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        setState(() => _errorMessage = (result['message'] ?? 'Login failed').toString());
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetSelection() {
    setState(() {
      _phoneAccounts = null;
      _selectedUsername = null;
      _selectedDisplayName = null;
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  Widget _buildAccountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthTitle('Select Account'),
        const SizedBox(height: 8),
        Text(
          'Multiple accounts found for this number',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        ..._phoneAccounts!.map((acc) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedUsername = acc['username'];
                  _selectedDisplayName = acc['displayName'];
                  _phoneAccounts = null;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFF3B8E).withOpacity(0.2),
                      child: Text(
                        (acc['displayName'] ?? '?')[0].toUpperCase(),
                        style: GoogleFonts.outfit(color: const Color(0xFFFF3B8E), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc['displayName'] ?? '',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Text(
                            '@${acc['username']}',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _resetSelection,
          child: Text('Use a different number', style: GoogleFonts.outfit(color: Colors.white70)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final identifier = _identifierController.text.trim();
    // Show password field if we have a selected username, OR if user has typed something that isn't a 10 digit phone
    final bool isPhoneCandidate = RegExp(r'^\d{1,10}$').hasMatch(identifier);
    final bool showPassword = _selectedUsername != null || (identifier.isNotEmpty && !isPhoneCandidate);

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
                
                if (_phoneAccounts != null)
                  _buildAccountSelector()
                else ...[
                  AuthTitle(_selectedUsername != null ? 'Welcome Back' : 'Login Now'),
                  const SizedBox(height: 18),
                  
                  if (_selectedUsername != null) ...[
                    // Phase 2 display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedDisplayName ?? '', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                Text('@$_selectedUsername', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _resetSelection,
                            child: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    // Phase 1 display
                    AuthTextField(
                      controller: _identifierController,
                      hint: 'Username or Phone Number',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.text,
                      autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber],
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (showPassword || _selectedUsername != null) ...[
                    AuthTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        child: const Text('Forgot password?', style: TextStyle(color: Color(0xFFFF3B8E))),
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: const Color(0xFFFF3B8E), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  AuthPrimaryButton(
                    label: (_selectedUsername != null || showPassword) ? 'LOGIN' : 'CONTINUE',
                    onPressed: _isLoading ? null : _handleNextOrLogin,
                    loading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Don\'t have an account? ', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.65), fontSize: 15)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                        child: Text('Create One', style: GoogleFonts.outfit(color: const Color(0xFFFF3B8E), fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
