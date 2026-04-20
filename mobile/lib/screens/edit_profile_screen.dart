import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/screens/date_of_birth_picker_screen.dart';
import 'package:mobile/services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _bioLimit = 200;
  static const List<String> _categories = [
    'Tech',
    'Gaming',
    'Education',
    'Fitness',
    'Lifestyle',
    'Travel',
    'Music',
    'Comedy',
    'Other',
  ];

  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _instagramController;
  late final TextEditingController _youtubeController;
  late final TextEditingController _websiteController;

  File? _imageFile;
  String? _webImagePath;
  XFile? _pickedImage;
  String? _existingProfilePic;
  DateTime? _dateOfBirth;
  String _category = '';
  bool _isLoading = false;
  String? _errorMessage;

  late final String _initialName;
  int _nameChangesLastWeek = 0;

  @override
  void initState() {
    super.initState();
    final socialLinks = (widget.user['socialLinks'] as Map<String, dynamic>?) ?? {};

    _usernameController = TextEditingController(text: (widget.user['username'] ?? '').toString());
    _nameController = TextEditingController(text: (widget.user['name'] ?? '').toString());
    _bioController = TextEditingController(text: (widget.user['bio'] ?? '').toString());
    _instagramController = TextEditingController(text: (socialLinks['instagram'] ?? '').toString());
    _youtubeController = TextEditingController(text: (socialLinks['youtube'] ?? '').toString());
    _websiteController = TextEditingController(text: (socialLinks['website'] ?? '').toString());

    _existingProfilePic = ((widget.user['profilePic'] ?? widget.user['profilePhotoUrl']) ?? '').toString();
    final dobRaw = widget.user['dateOfBirth']?.toString();
    if (dobRaw != null && dobRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(dobRaw);
      if (parsed != null) {
        _dateOfBirth = parsed;
      }
    }

    _category = (widget.user['category'] ?? '').toString();
    _initialName = _nameController.text.trim();
    _nameChangesLastWeek = _countNameChangesLastWeek(widget.user['nameChangeHistory']);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  int _countNameChangesLastWeek(dynamic history) {
    if (history is! List) return 0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    var count = 0;
    for (final item in history) {
      final parsed = DateTime.tryParse(item.toString());
      if (parsed != null && parsed.isAfter(weekAgo)) {
        count++;
      }
    }
    return count;
  }

  bool _isValidUrl(String value) {
    if (value.trim().isEmpty) return true;
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _pickedImage = pickedFile;
      if (kIsWeb) {
        _webImagePath = pickedFile.path;
        _imageFile = null;
      } else {
        _imageFile = File(pickedFile.path);
        _webImagePath = null;
      }
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _webImagePath = null;
      _imageFile = null;
      _existingProfilePic = '';
    });
  }

  void _openPhotoActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (context) {
        final hasPhoto = _pickedImage != null || (_existingProfilePic ?? '').isNotEmpty;
        return SafeArea(
          child: Wrap(
            children: [
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: const Text('View Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPhotoViewer();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(hasPhoto ? 'Change Photo' : 'Upload Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoViewer() {
    final currentPhoto = _webImagePath ?? _imageFile?.path ?? _existingProfilePic ?? '';
    if (currentPhoto.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: AspectRatio(
          aspectRatio: 1,
          child: currentPhoto.startsWith('http')
              ? Image.network(currentPhoto, fit: BoxFit.cover)
              : kIsWeb
                  ? Image.network(currentPhoto, fit: BoxFit.cover)
                  : Image.file(File(currentPhoto), fit: BoxFit.cover),
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final selected = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (_) => DateOfBirthPickerScreen(initialDate: _dateOfBirth),
      ),
    );
    if (selected != null) {
      setState(() {
        _dateOfBirth = selected;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newName = _nameController.text.trim();
    final nameChanged = newName != _initialName;
    if (nameChanged && _nameChangesLastWeek >= 2) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You can only change your name 2 times per week';
      });
      return;
    }

    final bio = _bioController.text.trim();
    if (bio.length > _bioLimit) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bio must be $_bioLimit characters or fewer';
      });
      return;
    }

    final instagram = _instagramController.text.trim();
    final youtube = _youtubeController.text.trim();
    final website = _websiteController.text.trim();
    if (!_isValidUrl(instagram) || !_isValidUrl(youtube) || !_isValidUrl(website)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter valid URLs (http/https) for social links';
      });
      return;
    }

    try {
      final updateData = <String, dynamic>{
        'bio': bio,
        'name': newName,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'category': _category,
        'socialLinks': {
          'instagram': instagram,
          'youtube': youtube,
          'website': website,
        },
      };

      if (_pickedImage != null) {
        final upload = await ApiService.uploadProfileImage(_pickedImage!);
        final profilePic = upload['profilePic']?.toString();
        if (profilePic != null && profilePic.isNotEmpty) {
          updateData['profilePic'] = profilePic;
          updateData['profilePhotoUrl'] = profilePic;
        }
      } else if ((_existingProfilePic ?? '').isEmpty) {
        updateData['profilePic'] = '';
        updateData['profilePhotoUrl'] = '';
      }

      final result = await ApiService.updateProfile(updateData);
      if (!result.containsKey('_id') && !result.containsKey('id')) {
        throw Exception((result['message'] ?? 'Failed to update profile').toString());
      }

      await ApiService.saveUser(result);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date of birth';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _openPhotoActions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                      backgroundImage: _webImagePath != null
                          ? NetworkImage(_webImagePath!)
                          : _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : ((_existingProfilePic ?? '').isNotEmpty
                                  ? NetworkImage(_existingProfilePic!)
                                  : null),
                      child: (_webImagePath == null && _imageFile == null && (_existingProfilePic ?? '').isEmpty)
                          ? Text(
                              (_usernameController.text.isNotEmpty ? _usernameController.text[0] : 'U').toUpperCase(),
                              style: TextStyle(color: fg, fontSize: 34, fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton.icon(
                onPressed: _openPhotoActions,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Change profile photo'),
              ),
            ),
            const SizedBox(height: 12),
            _buildReadOnlyField('Username', '@${_usernameController.text}'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Display Name',
              hint: 'Enter your display name',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Name changes used this week: $_nameChangesLastWeek/2',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _bioController,
              label: 'Bio',
              hint: 'Tell people about you',
              maxLines: 4,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_bioController.text.length}/$_bioLimit',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Date of Birth', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDateOfBirth,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_formatDate(_dateOfBirth), style: TextStyle(color: fg))),
                    Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Category', style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category.isEmpty ? null : _category,
              decoration: const InputDecoration(hintText: 'Select category'),
              items: _categories
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _category = value ?? '';
                });
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _instagramController,
              label: 'Instagram URL',
              hint: 'https://instagram.com/yourhandle',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _youtubeController,
              label: 'YouTube URL',
              hint: 'https://youtube.com/@yourchannel',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _websiteController,
              label: 'Website URL',
              hint: 'https://yourwebsite.com',
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black54;
    final fg = isDark ? Colors.white : const Color(0xFF111111);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          ),
          child: Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: label == 'Bio' ? _bioLimit : null,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
          decoration: InputDecoration(hintText: hint),
          onChanged: (_) {
            if (label == 'Bio') setState(() {});
          },
        ),
      ],
    );
  }
}
