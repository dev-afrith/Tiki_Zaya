import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/screens/main_navigation.dart';
import 'package:mobile/screens/reset_password_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final bool isPasswordReset;

  const VerificationScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() { _errorMessage = 'Please enter all 6 digits'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      if (widget.isPasswordReset) {
        // For password reset, we just verify the OTP and then go to reset screen
        // We don't save token yet because resetPassword will require OTP again (for security)
        // Or we could pass it. Let's just navigate.
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(email: widget.email, otp: otp),
            ),
          );
        }
      } else {
        final result = await ApiService.verifyOTP(widget.email, otp);

        if (result.containsKey('token')) {
          await ApiService.saveToken(result['token']);
          await ApiService.saveUser(result['user']);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
              (route) => false,
            );
          }
        } else {
          setState(() { _errorMessage = result['message'] ?? 'Verification failed'; });
        }
      }
    } catch (e) {
      setState(() { _errorMessage = 'Connection error'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _resendOTP() async {
    try {
      await ApiService.resendOTP(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resentment successfully')),
        );
      }
    } catch (e) {
      setState(() { _errorMessage = 'Failed to resend OTP'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 80, color: Color(0xFFFF006E)),
                const SizedBox(height: 24),
                const Text(
                  'Verify Email',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 48),

                // OTP Inputs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) => _buildOTPField(index)),
                ),

                const SizedBox(height: 32),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF006E))),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF006E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('VERIFY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: _resendOTP,
                  child: const Text('Resend Code', style: TextStyle(color: Color(0xFFFF006E))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF006E))),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (index == 5 && value.isNotEmpty) {
            _verify();
          }
        },
      ),
    );
  }
}
