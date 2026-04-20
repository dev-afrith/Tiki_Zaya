import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/screens/main_navigation.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();
  bool _isLoading = false;
  bool _isUsernameAvailable = false;
  String? _usernameError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      setState(() { _usernameError = null; _isUsernameAvailable = false; });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() { _usernameError = 'Use only lowercase, numbers, and underscores'; _isUsernameAvailable = false; });
      return;
    }

    // Debounce username check
    _checkUsernameAvailability(username);
  }

  Future<void> _checkUsernameAvailability(String username) async {
    // In a real app, you'd call an API. For now, let's just do a search users check.
    try {
      final results = await ApiService.searchUsers(username);
      final exists = results.any((u) => u['username'] == username);
      setState(() {
        _isUsernameAvailable = !exists;
        _usernameError = exists ? 'Username is already taken' : null;
      });
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    if (!_isUsernameAvailable) return;

    setState(() { _isLoading = true; _generalError = null; });

    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = {
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'country': _countryController.text.trim(),
        'email': user.email,
        'phone': user.phoneNumber,
      };

      // Since the user doesn't exist in MongoDB yet, we can't use 'updateProfile'.
      // We need a 'createProfile' endpoint or use the same update logic if the backend handles it.
      // For this refactor, I'll update the backend user controller to handle create-if-missing.
      final result = await ApiService.updateProfile(data);

      if (result.containsKey('_id')) {
        await ApiService.saveUser(result);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      } else {
        setState(() { _generalError = result['message'] ?? 'Failed to save profile'; });
      }
    } catch (e) {
      setState(() { _generalError = 'An error occurred while saving your profile'; });
    } finally {
      setState(() { _isLoading = false; });
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
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text('Complete Your Profile', 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                const SizedBox(height: 12),
                Text('Choose a unique username to represent you on Tiki Zaya.', 
                  style: TextStyle(color: Colors.grey[500], fontSize: 16)
                ),
                const SizedBox(height: 48),

                _buildTextField(
                  controller: _usernameController,
                  hint: 'Username',
                  icon: Icons.alternate_email,
                  suffix: _isUsernameAvailable 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                ),
                if (_usernameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(_usernameError!, style: const TextStyle(color: Color(0xFFFF006E), fontSize: 12)),
                  ),

                const SizedBox(height: 24),

                _buildTextField(
                  controller: _bioController,
                  hint: 'Tell us about yourself...',
                  icon: Icons.info_outline,
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                _buildTextField(
                  controller: _countryController,
                  hint: 'Country',
                  icon: Icons.public_outlined,
                ),

                const Spacer(),

                if (_generalError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(child: Text(_generalError!, style: const TextStyle(color: Color(0xFFFF006E)))),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading || !_isUsernameAvailable ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF006E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 10,
                      shadowColor: const Color(0xFFFF006E).withValues(alpha: 0.3),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('GET STARTED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
