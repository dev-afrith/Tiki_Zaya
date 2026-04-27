import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/theme_controller.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/archived_contents_screen.dart';
import 'package:mobile/utils/update_checker.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _user;
  bool _isPrivate = false;
  bool _isLoading = true;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = await ApiService.getUser();
    setState(() {
      _user = user;
      _isPrivate = user?['isPrivate'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    await appThemeController.setThemeMode(mode);
    try {
      final updated = await ApiService.updateProfile({
        'themePreference': isDark ? 'dark' : 'light',
      });
      await ApiService.saveUser(updated);
      if (mounted) {
        setState(() {
          _user = updated;
        });
      }
    } catch (_) {
      // Keep local theme change even if network update fails.
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() { _isPrivate = value; });
    try {
      final result = await ApiService.togglePrivacy();
      // Update local storage
      final user = await ApiService.getUser();
      if (user != null) {
        user['isPrivate'] = result['isPrivate'];
        await ApiService.saveUser(user);
      }
    } catch (e) {
      // Revert if failed
      if (!mounted) return;
      setState(() { _isPrivate = !value; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update privacy setting')),
      );
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Change Password', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(oldPasswordController, 'Old Password', true),
              const SizedBox(height: 16),
              _buildDialogField(newPasswordController, 'New Password', true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                setDialogState(() { isSaving = true; });
                try {
                  final result = await ApiService.changePassword(
                    oldPasswordController.text,
                    newPasswordController.text,
                  );
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(result['message'] ?? 'Password changed')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Error changing password')),
                  );
                } finally {
                  setDialogState(() { isSaving = false; });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF006E)),
              child: isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Change', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, bool obscure) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF006E))),
      ),
    );
  }

  Future<void> _updateAccountDetails(Map<String, dynamic> payload) async {
    try {
      final updated = await ApiService.updateProfile(payload);
      await ApiService.saveUser(updated);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _isPrivate = updated['isPrivate'] ?? _isPrivate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account details updated')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update account details')),
      );
    }
  }

  void _showEditAccountField({
    required String title,
    required String field,
    required String initialValue,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final valueController = TextEditingController(text: initialValue);
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valueController,
                keyboardType: keyboardType,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: title,
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF006E))),
                ),
              ),
              const SizedBox(height: 14),
              _buildDialogField(passwordController, 'Current Password', true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      await _updateAccountDetails({
                        field: valueController.text.trim(),
                        'currentPassword': passwordController.text,
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF006E)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDobDialog() {
    DateTime selected = DateTime.tryParse((_user?['dateOfBirth'] ?? '').toString()) ?? DateTime(DateTime.now().year - 18);
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Edit Date of Birth', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_formatDob(selected.toIso8601String()), style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.calendar_month, color: Colors.white70),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(now.year - 100),
                    lastDate: now,
                  );
                  if (picked != null) setDialogState(() => selected = picked);
                },
              ),
              const SizedBox(height: 14),
              _buildDialogField(passwordController, 'Current Password', true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      await _updateAccountDetails({
                        'dateOfBirth': selected.toIso8601String(),
                        'currentPassword': passwordController.text,
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF006E)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDob(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Not provided';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    await UpdateChecker.checkAndShowDialog(context);
    if (mounted) setState(() => _checkingUpdate = false);
  }

  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will be deleted permanently. All your videos, comments, and messages will be removed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ApiService.deleteAccount();
      await ApiService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF6F7FB);
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? Colors.white54 : Colors.black54;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF006E))),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: fg),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text('Settings', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Theme'),
          SwitchListTile(
            title: Text('Dark Mode', style: TextStyle(color: fg)),
            subtitle: Text(
              'Switch between light and dark theme.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: appThemeController.isDarkMode,
            onChanged: _toggleTheme,
            activeColor: const Color(0xFFFF006E),
          ),

          _buildSectionHeader('Account Info'),
          ListTile(
            leading: Icon(Icons.alternate_email_rounded, color: muted),
            title: Text('Username', style: TextStyle(color: fg)),
            subtitle: Text((_user?['username'] ?? 'Not provided').toString(), style: TextStyle(color: muted)),
            trailing: Icon(Icons.edit_outlined, color: muted),
            onTap: () => _showEditAccountField(
              title: 'Edit Username',
              field: 'username',
              initialValue: (_user?['username'] ?? '').toString(),
            ),
          ),
          ListTile(
            leading: Icon(Icons.email_outlined, color: muted),
            title: Text('Email', style: TextStyle(color: fg)),
            subtitle: Text((_user?['email'] ?? 'Not provided').toString(), style: TextStyle(color: muted)),
            trailing: Icon(Icons.edit_outlined, color: muted),
            onTap: () => _showEditAccountField(
              title: 'Edit Email',
              field: 'email',
              initialValue: (_user?['email'] ?? '').toString(),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          ListTile(
            leading: Icon(Icons.phone_outlined, color: muted),
            title: Text('Phone', style: TextStyle(color: fg)),
            subtitle: Text((_user?['phone'] ?? 'Not provided').toString(), style: TextStyle(color: muted)),
            trailing: Icon(Icons.edit_outlined, color: muted),
            onTap: () => _showEditAccountField(
              title: 'Edit Phone Number',
              field: 'phone',
              initialValue: (_user?['phone'] ?? '').toString(),
              keyboardType: TextInputType.phone,
            ),
          ),
          ListTile(
            leading: Icon(Icons.cake_outlined, color: muted),
            title: Text('Date of Birth', style: TextStyle(color: fg)),
            subtitle: Text(_formatDob((_user?['dateOfBirth'] ?? '').toString()), style: TextStyle(color: muted)),
            trailing: Icon(Icons.edit_outlined, color: muted),
            onTap: _showEditDobDialog,
          ),

          _buildSectionHeader('Account'),
          SwitchListTile(
            title: Text('Private Account', style: TextStyle(color: fg)),
            subtitle: Text('Only people you approve can see your videos.', style: TextStyle(color: muted, fontSize: 12)),
            value: _isPrivate,
            onChanged: _togglePrivacy,
            activeColor: const Color(0xFFFF006E),
          ),
          ListTile(
            leading: Icon(Icons.lock_outline, color: muted),
            title: Text('Change Password', style: TextStyle(color: fg)),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: _showChangePasswordDialog,
          ),
          
          _buildSectionHeader('More Info'),
          ListTile(
            leading: Icon(Icons.info_outline, color: muted),
            title: Text('About Tiki Zaya', style: TextStyle(color: fg)),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutTikiZayaScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: muted),
            title: Text('Help Center', style: TextStyle(color: fg)),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpCentreScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.archive_outlined, color: muted),
            title: Text('Archived Contents', style: TextStyle(color: fg)),
            trailing: Icon(Icons.chevron_right, color: muted),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivedContentsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.system_update_alt_rounded, color: muted),
            title: Text('Check for Updates', style: TextStyle(color: fg)),
            subtitle: Text('Install the latest APK without Play Store.', style: TextStyle(color: muted, fontSize: 12)),
            trailing: _checkingUpdate
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.chevron_right, color: muted),
            onTap: _checkForUpdates,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            subtitle: const Text('This will be deleted permanently', style: TextStyle(color: Colors.white54, fontSize: 12)),
            onTap: _confirmDeleteAccount,
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white12 : Colors.white,
                foregroundColor: const Color(0xFFFF006E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.grey[700] : Colors.black45,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class AboutTikiZayaScreen extends StatelessWidget {
  const AboutTikiZayaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF6F7FB);
    final card = isDark ? const Color(0xFF111217) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subtitleColor = isDark ? Colors.white70 : Colors.black87;
    final bodyColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    TextStyle sectionTitleStyle = TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w700);
    TextStyle subTitleStyle = TextStyle(color: subtitleColor, fontSize: 15, fontWeight: FontWeight.w600);
    TextStyle bodyStyle = TextStyle(color: bodyColor, fontSize: 14, height: 1.5);

    Widget bullet(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 6, color: bodyColor),
            ),
            Expanded(child: Text(text, style: bodyStyle)),
          ],
        ),
      );
    }

    Widget sectionHeader(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: subTitleStyle),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('About TikiZaya', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy Policy for TikiZaya', style: sectionTitleStyle),
              const SizedBox(height: 6),
              Text('Last updated: 21.04.2026', style: bodyStyle),
              const SizedBox(height: 10),
              Text('TikiZaya is a product of Zaya Code Hub (www.zayacodehub.in) and is developed by Muhammad Afrith.', style: bodyStyle),
              const SizedBox(height: 8),
              Text('This Privacy Policy explains how we collect, use, and protect your information when you use the TikiZaya mobile application.', style: bodyStyle),

              sectionHeader('1. Information We Collect'),
              Text('a. Account Information', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('We may collect basic information such as your name, email address, and phone number when you sign in using Google or mobile authentication.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('b. User Content', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('We collect content you create, upload, or share, including videos, captions, comments, and profile information.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('c. Usage Data', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('We may collect information about how you use the app, such as interactions, preferences, and activity logs.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('d. Device Information', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('We may collect device-related information such as device type, OS version, and app performance data.', style: bodyStyle),

              sectionHeader('2. How We Use Your Information'),
              Text('We use your information to:', style: bodyStyle),
              bullet('Provide and improve our services'),
              bullet('Enable video sharing and social interactions'),
              bullet('Personalize your experience'),
              bullet('Maintain security and prevent misuse'),
              bullet('Analyze performance and usage'),

              sectionHeader('3. Content Storage'),
              Text('Videos and content uploaded to TikiZaya may be stored on secure cloud services. By uploading content, you grant us permission to store and display it within the app.', style: bodyStyle),

              sectionHeader('4. Sharing of Information'),
              Text('We do not sell your personal data. We may share data:', style: bodyStyle),
              bullet('With service providers (e.g., cloud storage, analytics)'),
              bullet('If required by law or legal process'),

              sectionHeader('5. Data Security'),
              Text('We implement reasonable security measures to protect your data. However, no system is completely secure.', style: bodyStyle),

              sectionHeader('6. User Control'),
              Text('You can:', style: bodyStyle),
              bullet('Update or delete your profile'),
              bullet('Remove your uploaded content'),
              bullet('Contact us for data-related requests'),

              sectionHeader('7. Children\'s Privacy'),
              Text('TikiZaya is not intended for children under 13. We do not knowingly collect data from children.', style: bodyStyle),

              sectionHeader('8. Changes to This Policy'),
              Text('We may update this Privacy Policy from time to time. Changes will be reflected with an updated date.', style: bodyStyle),

              sectionHeader('9. Contact Us'),
              Text('Zaya Code Hub\nWebsite: www.zayacodehub.in\nDeveloper: Muhammad Afrith', style: bodyStyle),

              const SizedBox(height: 26),
              Divider(color: borderColor),
              const SizedBox(height: 18),

              Text('Terms & Conditions for TikiZaya', style: sectionTitleStyle),
              const SizedBox(height: 6),
              Text('Last updated: 21.04.2026', style: bodyStyle),
              const SizedBox(height: 10),
              Text('TikiZaya is a product of Zaya Code Hub (www.zayacodehub.in) and is developed by Muhammad Afrith.', style: bodyStyle),
              const SizedBox(height: 8),
              Text('By using TikiZaya, you agree to the following terms:', style: bodyStyle),

              sectionHeader('1. Use of the App'),
              Text('You agree to use the app responsibly and not engage in:', style: bodyStyle),
              bullet('Illegal activities'),
              bullet('Uploading harmful, abusive, or inappropriate content'),
              bullet('Violating others\' rights'),

              sectionHeader('2. User Content'),
              Text('You are responsible for the content you upload. By posting content, you grant TikiZaya the right to display and distribute it within the platform.', style: bodyStyle),

              sectionHeader('3. Account Responsibility'),
              Text('You are responsible for maintaining the security of your account and any activity under it.', style: bodyStyle),

              sectionHeader('4. Content Moderation'),
              Text('We reserve the right to:', style: bodyStyle),
              bullet('Remove content that violates guidelines'),
              bullet('Block or suspend accounts'),
              bullet('Take action on reported content'),

              sectionHeader('5. Intellectual Property'),
              Text('All app design, branding, and content (excluding user-generated content) belong to TikiZaya / Zaya Code Hub.', style: bodyStyle),

              sectionHeader('6. Termination'),
              Text('We may suspend or terminate access to the app if users violate these terms.', style: bodyStyle),

              sectionHeader('7. Limitation of Liability'),
              Text('TikiZaya is provided "as is." We are not responsible for any damages or losses resulting from app usage.', style: bodyStyle),

              sectionHeader('8. Changes to Terms'),
              Text('We may update these terms at any time. Continued use of the app means you accept the updated terms.', style: bodyStyle),

              sectionHeader('9. Contact'),
              Text('Zaya Code Hub\nWebsite: www.zayacodehub.in\nDeveloper: Muhammad Afrith', style: bodyStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class HelpCentreScreen extends StatelessWidget {
  const HelpCentreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF6F7FB);
    final card = isDark ? const Color(0xFF111217) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subtitleColor = isDark ? Colors.white70 : Colors.black87;
    final bodyColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    TextStyle sectionTitleStyle = TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w700);
    TextStyle subTitleStyle = TextStyle(color: subtitleColor, fontSize: 15, fontWeight: FontWeight.w600);
    TextStyle bodyStyle = TextStyle(color: bodyColor, fontSize: 14, height: 1.5);

    Widget bullet(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 6, color: bodyColor),
            ),
            Expanded(child: Text(text, style: bodyStyle)),
          ],
        ),
      );
    }

    Widget sectionHeader(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: subTitleStyle),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Help Centre', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Help Centre - TikiZaya', style: sectionTitleStyle),
              const SizedBox(height: 10),
              Text('Welcome to the TikiZaya Help Centre 👋', style: bodyStyle),
              Text('Find answers to common questions and learn how to use the app easily.', style: bodyStyle),

              sectionHeader('🔐 Account & Login'),
              Text('How do I sign in?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Use Google Sign-In or mobile OTP to log in securely.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('I can\'t log in', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Check your internet connection and make sure your OTP or Google account details are correct.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('How do I edit my profile?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Go to your profile -> Tap "Edit Profile" -> Update your information.', style: bodyStyle),

              sectionHeader('🎥 Videos & Uploads'),
              Text('How do I upload a video?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Tap the "+" button -> Select or record a video -> Edit -> Post.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('Why is my video not uploading?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Ensure you have a stable internet connection and the video size is supported. Try again.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('Can I delete my video?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Yes. Open your video -> Tap options -> Select "Delete".', style: bodyStyle),

              sectionHeader('🎬 Editing Features'),
              Text('How do I trim a video?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Use the trim slider in the editor before posting.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('Can I add music or effects?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Yes, use the editing tools to add music, filters, text, and effects.', style: bodyStyle),

              sectionHeader('💬 Interactions'),
              Text('How do I like or comment?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Tap the heart icon to like and use the comment section below the video.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('How do I report content?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Tap options on a video -> Select "Report".', style: bodyStyle),

              sectionHeader('🚫 Safety & Privacy'),
              Text('How do I block a user?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Go to the user\'s profile -> Tap options -> Select "Block".', style: bodyStyle),
              const SizedBox(height: 10),
              Text('How do I report a user?', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Use the report option from their profile or content.', style: bodyStyle),

              sectionHeader('⚙️ App Issues'),
              Text('App is slow or crashing', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Restart the app or update to the latest version.', style: bodyStyle),
              const SizedBox(height: 10),
              Text('Videos are not loading', style: subTitleStyle),
              const SizedBox(height: 4),
              Text('Check your internet connection and try again.', style: bodyStyle),

              sectionHeader('📩 Contact Support'),
              Text('Still need help? Contact us:', style: bodyStyle),
              const SizedBox(height: 10),
              bullet('Zaya Code Hub'),
              bullet('Website: www.zayacodehub.in'),
              bullet('Email: afrithafrith1507@gmail.com'),
              bullet('Phone: +91 7397463508'),
              bullet('Developer: Muhammad Afrith'),
              const SizedBox(height: 10),
              Text('We\'re here to support you 🚀', style: bodyStyle),
            ],
          ),
        ),
      ),
    );
  }
}
