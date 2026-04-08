import 'dart:io';
import 'package:app1/screens/LoginPage.dart';
import 'package:app1/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../providers/home_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Base URL constant — change once, applies everywhere
// ─────────────────────────────────────────────────────────────────────────────
const String _kBaseStorageUrl =
    'https://kasandra-unmeddled-heriberto.ngrok-free.dev/storage/';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  // ── User data ──────────────────────────────────────────────────────────────
  String _name = '';
  String _email = '';
  String _phone = '';
  String?
  _avatarPath; // storage path returned by server e.g. "avatars/1/abc.jpg"
  File? _pendingAvatarFile; // local file selected but not yet uploaded
  bool _isLoading = true;
  bool _uploadingAvatar = false;

  // ── Tabs ───────────────────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Profile form ───────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  String? _profileError;
  String? _profileSuccess;
  bool _savingProfile = false;

  // ── Password form ──────────────────────────────────────────────────────────
  final _currPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _currPassFocus = FocusNode();
  final _newPassFocus = FocusNode();
  final _confirmPassFocus = FocusNode();
  bool _obscureCurr = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _passError;
  String? _passSuccess;
  bool _savingPass = false;

  // ── Password rules ─────────────────────────────────────────────────────────
  bool get _hasUpper => _newPassCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => _newPassCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasLength => _newPassCtrl.text.length >= 8;
  bool get _hasSpecial => _newPassCtrl.text.contains(RegExp(r'[-*?@]'));
  bool get _passValid => _hasUpper && _hasLower && _hasLength && _hasSpecial;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
    for (final n in [
      _nameFocus,
      _emailFocus,
      _phoneFocus,
      _currPassFocus,
      _newPassFocus,
      _confirmPassFocus,
    ]) {
      n.addListener(() => setState(() {}));
    }
    _newPassCtrl.addListener(() => setState(() {}));
    _confirmPassCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _currPassCtrl,
      _newPassCtrl,
      _confirmPassCtrl,
    ]) {
      c.dispose();
    }
    for (final n in [
      _nameFocus,
      _emailFocus,
      _phoneFocus,
      _currPassFocus,
      _newPassFocus,
      _confirmPassFocus,
    ]) {
      n.dispose();
    }
    super.dispose();
  }

  // ── Load profile ───────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final res = await _api.getProfile();
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _name = res['name'] ?? '';
        _email = res['email'] ?? '';
        _phone = res['phone'] ?? '';
        _avatarPath = res['avatar'] as String?;
        _nameCtrl.text = _name;
        _emailCtrl.text = _email;
        _phoneCtrl.text = _phone;
        _isLoading = false;
      });
      // Refresh the home screen greeting
      ref.read(userProvider.notifier).refresh();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  String? get _avatarUrl => _avatarPath != null && _avatarPath!.isNotEmpty
      ? '$_kBaseStorageUrl$_avatarPath'
      : null;

  Future<void> _showAvatarPicker() async {
    final c = AppColors.of(context);
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Profile Photo',
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              _sheetOption(
                c,
                Icons.camera_alt_outlined,
                'Take a Photo',
                'Camera',
                ImageSource.camera,
              ),
              const SizedBox(height: 10),
              _sheetOption(
                c,
                Icons.photo_library_outlined,
                'Choose from Library',
                'Gallery',
                ImageSource.gallery,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    await _pickAndUploadAvatar(choice);
  }

  Widget _sheetOption(
    AppColorScheme c,
    IconData icon,
    String subtitle,
    String title,
    ImageSource source,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.fieldBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    final file = File(picked.path);

    // Show local preview immediately
    setState(() {
      _pendingAvatarFile = file;
      _uploadingAvatar = true;
    });

    final res = await _api.uploadAvatar(filePath: picked.path);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        // Server returns the storage path in 'avatar'
        _avatarPath = res['avatar'] as String?;
        _pendingAvatarFile = null;
        _uploadingAvatar = false;
      });
      ref.read(userProvider.notifier).refresh();
      _showSnack('Profile photo updated', success: true);
    } else {
      setState(() {
        _pendingAvatarFile = null;
        _uploadingAvatar = false;
      });
      _showSnack(res['message'] ?? 'Avatar upload failed', success: false);
    }
  }

  // ── Save profile ───────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    setState(() {
      _profileError = null;
      _profileSuccess = null;
    });
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _profileError = 'Name cannot be empty');
      return;
    }
    setState(() => _savingProfile = true);
    final res = await _api.updateProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _savingProfile = false;
      if (res['success'] == true) {
        _name = _nameCtrl.text.trim();
        _email = _emailCtrl.text.trim();
        _profileSuccess = 'Profile updated successfully';
        ref.read(userProvider.notifier).refresh();
      } else {
        _profileError = res['message'] ?? 'Update failed';
      }
    });
  }

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    setState(() {
      _passError = null;
      _passSuccess = null;
    });
    if (_currPassCtrl.text.isEmpty) {
      setState(() => _passError = 'Enter your current password');
      return;
    }
    if (!_passValid) {
      setState(() => _passError = 'New password does not meet requirements');
      return;
    }
    if (_confirmPassCtrl.text != _newPassCtrl.text) {
      setState(() => _passError = 'Passwords do not match');
      return;
    }
    setState(() => _savingPass = true);
    final res = await _api.changePassword(
      currentPassword: _currPassCtrl.text,
      newPassword: _newPassCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _savingPass = false;
      if (res['success'] == true) {
        _passSuccess = 'Password changed successfully';
        _currPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        _passError = res['message'] ?? 'Failed to change password';
      }
    });
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.borderDefault),
        ),
        title: Text(
          'Log Out',
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.borderError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _api.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  // ── Snackbar helper ────────────────────────────────────────────────────────
  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: success ? c.success : c.borderError,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Field decoration helpers ───────────────────────────────────────────────
  InputDecoration _dec({
    required String hint,
    required IconData icon,
    required FocusNode fn,
    required AppColorScheme c,
    Widget? suffix,
    bool isError = false,
  }) {
    final focused = fn.hasFocus;
    final bdr = isError
        ? c.borderError
        : focused
        ? c.borderFocus
        : c.borderDefault;
    final icn = isError
        ? c.borderError
        : focused
        ? c.iconFocus
        : c.iconDefault;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.hint, fontSize: 14),
      prefixIcon: Icon(icon, color: icn, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: focused ? c.fieldBgFocus : c.fieldBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bdr, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bdr, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: bdr, width: 2.0),
      ),
    );
  }

  Widget _glow({
    required Widget child,
    required FocusNode fn,
    required AppColorScheme c,
    bool isError = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isError)
            BoxShadow(color: c.borderError.withOpacity(0.22), blurRadius: 12)
          else if (fn.hasFocus)
            BoxShadow(color: c.borderFocus.withOpacity(0.22), blurRadius: 14),
        ],
      ),
      child: child,
    );
  }

  Widget _vis({
    required bool obscure,
    required VoidCallback onTap,
    required FocusNode fn,
    required AppColorScheme c,
  }) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: fn.hasFocus ? c.iconFocus : c.iconDefault,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  Widget _ruleRow(bool passed, String label, AppColorScheme c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passed
                  ? const Color(0xFF4CAF50).withOpacity(0.15)
                  : c.fieldBg,
              border: Border.all(
                color: passed ? const Color(0xFF4CAF50) : c.borderDefault,
                width: 1.5,
              ),
            ),
            child: passed
                ? const Icon(Icons.check, size: 10, color: Color(0xFF4CAF50))
                : null,
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 12,
              color: passed ? const Color(0xFF4CAF50) : c.subtitle,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget _banner(String? msg, bool isError, AppColorScheme c) {
    if (msg == null) return const SizedBox.shrink();
    final color = isError ? c.borderError : c.success;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    AppColorScheme c, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: c.primary, size: 17),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _buildHeader(c),
          // ── Tab bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: c.fieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.borderDefault),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: c.subtitle,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Security'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_profileTab(c), _securityTab(c)],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with tappable avatar ────────────────────────────────────────────
  Widget _buildHeader(AppColorScheme c) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
          child: Row(
            children: [
              // ── Avatar (tappable) ──
              GestureDetector(
                onTap: _uploadingAvatar ? null : _showAvatarPicker,
                child: Stack(
                  children: [
                    // Avatar circle
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [c.primary, c.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildAvatarContent(c),
                    ),
                    // Camera badge
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _uploadingAvatar ? c.textSecondary : c.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 2),
                        ),
                        child: _uploadingAvatar
                            ? Padding(
                                padding: const EdgeInsets.all(4),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 1.5,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isNotEmpty ? _name : '—',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _email,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Theme toggle
              Consumer(
                builder: (_, ref, __) {
                  final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
                  return GestureDetector(
                    onTap: () => ref.read(themeModeProvider.notifier).state =
                        isDark ? ThemeMode.light : ThemeMode.dark,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.fieldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.borderDefault),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: c.textSecondary,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 8),

              // Logout
              GestureDetector(
                onTap: _logout,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.borderError.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.borderError.withOpacity(0.25)),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: c.borderError,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(AppColorScheme c) {
    // 1. Show pending local file preview
    if (_pendingAvatarFile != null) {
      return ClipOval(
        child: Image.file(
          _pendingAvatarFile!,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
        ),
      );
    }
    // 2. Show remote avatar
    if (_avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          _avatarUrl!,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          // If image fails to load, fall back to initials
          errorBuilder: (_, __, ___) => _avatarInitials(),
        ),
      );
    }
    // 3. Fallback: initials
    return _avatarInitials();
  }

  Widget _avatarInitials() {
    return Center(
      child: Text(
        _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Profile tab ────────────────────────────────────────────────────────────
  Widget _profileTab(AppColorScheme c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(_profileError, true, c),
          _banner(_profileSuccess, false, c),
          _sectionCard(
            c,
            title: 'Personal Information',
            icon: Icons.person_outline,
            children: [
              _glow(
                fn: _nameFocus,
                c: c,
                child: TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: _dec(
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                    fn: _nameFocus,
                    c: c,
                  ),
                ),
              ),
              const Gap(12),
              _glow(
                fn: _emailFocus,
                c: c,
                child: TextField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: _dec(
                    hint: 'Email Address',
                    icon: Icons.email_outlined,
                    fn: _emailFocus,
                    c: c,
                  ),
                ),
              ),
              const Gap(12),
              _glow(
                fn: _phoneFocus,
                c: c,
                child: TextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: _dec(
                    hint: 'Phone Number',
                    icon: Icons.phone_outlined,
                    fn: _phoneFocus,
                    c: c,
                  ),
                ),
              ),
              const Gap(20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _savingProfile ? null : _saveProfile,
                  child: _savingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const Gap(20),
          _sectionCard(
            c,
            title: 'Documents',
            icon: Icons.folder_outlined,
            children: [_DocumentUploader(api: _api, colors: c)],
          ),
          const Gap(20),
        ],
      ),
    );
  }

  // ── Security tab ───────────────────────────────────────────────────────────
  Widget _securityTab(AppColorScheme c) {
    final mismatch =
        _confirmPassCtrl.text.isNotEmpty &&
        _confirmPassCtrl.text != _newPassCtrl.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(_passError, true, c),
          _banner(_passSuccess, false, c),
          _sectionCard(
            c,
            title: 'Change Password',
            icon: Icons.lock_outline,
            children: [
              _glow(
                fn: _currPassFocus,
                c: c,
                child: TextField(
                  controller: _currPassCtrl,
                  focusNode: _currPassFocus,
                  obscureText: _obscureCurr,
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: _dec(
                    hint: 'Current Password',
                    icon: Icons.lock_outline,
                    fn: _currPassFocus,
                    c: c,
                    suffix: _vis(
                      obscure: _obscureCurr,
                      fn: _currPassFocus,
                      c: c,
                      onTap: () => setState(() => _obscureCurr = !_obscureCurr),
                    ),
                  ),
                ),
              ),
              const Gap(12),
              _glow(
                fn: _newPassFocus,
                c: c,
                child: TextField(
                  controller: _newPassCtrl,
                  focusNode: _newPassFocus,
                  obscureText: _obscureNew,
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: _dec(
                    hint: 'New Password',
                    icon: Icons.lock_outline,
                    fn: _newPassFocus,
                    c: c,
                    suffix: _vis(
                      obscure: _obscureNew,
                      fn: _newPassFocus,
                      c: c,
                      onTap: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
              ),
              if (_newPassCtrl.text.isNotEmpty) ...[
                const Gap(10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.fieldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.borderDefault),
                  ),
                  child: Column(
                    children: [
                      _ruleRow(_hasLength, 'At least 8 characters', c),
                      _ruleRow(_hasUpper, 'One uppercase letter (A–Z)', c),
                      _ruleRow(_hasLower, 'One lowercase letter (a–z)', c),
                      _ruleRow(
                        _hasSpecial,
                        'One special character (- * ? @)',
                        c,
                      ),
                    ],
                  ),
                ),
              ],
              const Gap(12),
              _glow(
                fn: _confirmPassFocus,
                c: c,
                isError: mismatch,
                child: TextField(
                  controller: _confirmPassCtrl,
                  focusNode: _confirmPassFocus,
                  obscureText: _obscureConfirm,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: _dec(
                    hint: 'Confirm New Password',
                    icon: Icons.lock_outline,
                    fn: _confirmPassFocus,
                    c: c,
                    isError: mismatch,
                    suffix: _vis(
                      obscure: _obscureConfirm,
                      fn: _confirmPassFocus,
                      c: c,
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
              ),
              if (mismatch) ...[
                const Gap(6),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: c.borderError, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'Passwords do not match',
                      style: TextStyle(color: c.borderError, fontSize: 12),
                    ),
                  ],
                ),
              ],
              const Gap(20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _savingPass ? null : _changePassword,
                  child: _savingPass
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const Gap(20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document Uploader
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentUploader extends StatefulWidget {
  final ApiService api;
  final AppColorScheme colors;
  const _DocumentUploader({required this.api, required this.colors});

  @override
  State<_DocumentUploader> createState() => _DocumentUploaderState();
}

class _DocumentUploaderState extends State<_DocumentUploader> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  bool _uploading = false;

  AppColorScheme get c => widget.colors;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _loading = true);
    final res = await widget.api.getDocuments();
    if (!mounted) return;
    setState(() {
      _docs = res['success'] == true
          ? List<Map<String, dynamic>>.from(res['data'] ?? [])
          : [];
      _loading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    final res = await widget.api.uploadPdf(
      filePath: file.path!,
      name: file.name,
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    _showSnack(
      res['success'] == true
          ? 'PDF uploaded successfully'
          : res['message'] ?? 'Upload failed',
      success: res['success'] == true,
    );
    if (res['success'] == true) _loadDocs();
  }

  Future<void> _confirmDelete(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.borderDefault),
        ),
        title: Text(
          'Delete Document',
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Remove "${doc['name']}"?',
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.borderError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Validate id exists before calling API
    final id = doc['id'];
    if (id == null) {
      _showSnack('Cannot delete: document ID is missing', success: false);
      return;
    }

    final res = await widget.api.deleteDocument(id as int);
    if (!mounted) return;
    if (res['success'] == true) {
      _loadDocs();
      _showSnack('Document deleted', success: true);
    } else {
      _showSnack(res['message'] ?? 'Delete failed', success: false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: success ? c.success : c.borderError,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.primary.withOpacity(0.5), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: c.primary,
            ),
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: c.primary,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(
              _uploading ? 'Uploading…' : 'Upload PDF',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_loading) ...[
          const Gap(16),
          Center(
            child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
          ),
        ] else if (_docs.isEmpty) ...[
          const Gap(16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  color: c.borderDefault,
                  size: 36,
                ),
                const Gap(8),
                Text(
                  'No documents yet',
                  style: TextStyle(color: c.subtitle, fontSize: 13),
                ),
              ],
            ),
          ),
        ] else ...[
          const Gap(12),
          ..._docs.map((doc) => _docTile(doc)),
        ],
      ],
    );
  }

  Widget _docTile(Map<String, dynamic> doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFE53935),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['name'] ?? 'Document',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtSize(doc['size'] ?? 0),
                  style: TextStyle(color: c.subtitle, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.borderError, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _confirmDelete(doc),
          ),
        ],
      ),
    );
  }
}
