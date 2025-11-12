import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:passage/models/user_profile.dart';
import 'package:passage/services/local_user_profile_store.dart';
import 'package:passage/services/firestore_user_profile_service.dart';
import 'package:passage/services/firebase_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed seller creation from Edit Profile as per request

class EditProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;
  const EditProfileScreen({super.key, required this.initialProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bioCtrl;

  // Avatar state: prefer bytes (picked locally). Fallback to URL for existing profiles.
  Uint8List? _avatarBytes;
  late String _avatarUrl;

  String _gender = '';
  DateTime? _dob;

  String _dialCode = '+1';
  String _flagEmoji = '🇺🇸';

  // Seller creation controls moved to Settings screen

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p.fullName);
    _usernameCtrl = TextEditingController(text: p.username);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
    _bioCtrl = TextEditingController(text: p.bio);
    _avatarBytes = p.avatarBytes;
    _avatarUrl = p.avatarUrl;
    _gender = p.gender;
    _dob = p.dob;
    // Seller creation moved to Settings; nothing to init here
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rawPhone = _phoneCtrl.text.trim();
    final normalizedPhone = rawPhone.isEmpty
        ? ''
        : (rawPhone.startsWith('+') ? rawPhone : '$_dialCode $rawPhone');
    var updated = widget.initialProfile.copyWith(
      fullName: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: normalizedPhone,
      bio: _bioCtrl.text.trim(),
      gender: _gender,
      dob: _dob,
      // If new avatar bytes are present, we'll upload and replace avatarUrl below
      avatarUrl: _avatarBytes != null ? '' : _avatarUrl.trim(),
      avatarBytes: _avatarBytes,
    );
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to save changes.')),
        );
        return;
      }

      // Upload avatar if user selected a new one
      if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
        final uploaded = await FirebaseStorageService.uploadUserAvatar(
          _avatarBytes!,
          userId: user.uid,
          extension: 'jpg',
        );
        _avatarUrl = uploaded.downloadUrl;
        updated = updated.copyWith(avatarUrl: _avatarUrl);
      }

      // Persist to Firestore (users/{uid})
      await FirestoreUserProfileService.save(updated);

      // Update local cache for instant UI reflection
      await LocalUserProfileStore.save(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  // Seller creation bottom sheet moved to Settings

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year - 10, now.month, now.day),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _pickCountryDialCode() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country c) {
        setState(() {
          _dialCode = '+${c.phoneCode}';
          _flagEmoji = c.flagEmoji;
        });
      },
    );
  }

  Future<void> _showAvatarActionSheet() async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: Colors.indigo),
                title: const Text('Take photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.teal),
                title: const Text('Upload from gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromGallery();
                },
              ),
              // Removed generic file picker to avoid web plugin crash; gallery covers file upload on web
              if (_avatarBytes != null || _avatarUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarBytes = null;
                      _avatarUrl = '';
                    });
                  },
                ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 1024);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo captured')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to capture photo')));
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo selected from gallery')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick from gallery')));
    }
  }

  // File picking via ImagePicker (gallery) is supported on web; dedicated file picker removed

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.teal),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              backgroundImage: _avatarBytes != null
                                  ? MemoryImage(_avatarBytes!)
                                  : (_avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null),
                              child: (_avatarBytes == null && _avatarUrl.isEmpty)
                                  ? const Icon(Icons.person, size: 36)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _showAvatarActionSheet,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personal Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              Text('Update your basic profile details',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter your name';
                        if (v.trim().length < 2) return 'Name must be at least 2 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Please enter a username';
                        if (val.length < 3) return 'Username must be at least 3 characters';
                        if (!RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(val)) return 'Only letters, numbers, dot and underscore';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                       onChanged: null,
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Please enter your email';
                        if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Seller profile controls moved to Settings
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pickCountryDialCode,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_flagEmoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text(_dialCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down, color: Colors.blue),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      ),
                      validator: (v) {
                        final raw = (v ?? '').trim();
                        if (raw.isEmpty) return null; // optional
                        final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 7) return 'Enter a valid phone number';
                        return null;
                      },
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender.isEmpty ? null : _gender,
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            onChanged: (v) => setState(() => _gender = v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _pickDob,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date of birth',
                                prefixIcon: Icon(Icons.cake_outlined),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _dob == null ? 'Select date' : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            label: const Text('Save changes'),
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
      ),
    );
  }
}
