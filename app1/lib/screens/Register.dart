import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../widgets/socialButtons.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:app1/theme/app_color.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  late AnimationController _controller;
  late Animation<Offset> _leftImageAnimation;
  late Animation<Offset> _rightImageAnimation;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  final ApiService api = ApiService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  String? _confirmError;
  String? _formError;
  bool _isLoading = false;
  bool _attemptedSubmit = false;

  // ── Password rule getters ─────────────────────────────────────────────────
  bool get _hasUppercase => passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasMinLength => passwordController.text.length >= 8;
  bool get _hasSpecialChar =>
      passwordController.text.contains(RegExp(r'[-*?@]'));
  bool get _passwordValid =>
      _hasUppercase && _hasLowercase && _hasMinLength && _hasSpecialChar;

  // ── Phone rule getter ─────────────────────────────────────────────────────
  bool get _phoneValid =>
      RegExp(r'^[2459]\d{7}$').hasMatch(phoneController.text.trim());

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _leftImageAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _rightImageAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 1, curve: Curves.easeOut),
          ),
        );

    _controller.forward();

    for (final node in [
      _nameFocus,
      _phoneFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      node.addListener(() => setState(() {}));
    }

    confirmController.addListener(_validateConfirm);
    passwordController.addListener(_validateConfirm);
    // rebuild on typing for rule indicators
    passwordController.addListener(() => setState(() {}));
    phoneController.addListener(() => setState(() {}));
  }

  void _validateConfirm() {
    if (_attemptedSubmit || confirmController.text.isNotEmpty) {
      setState(() {
        _confirmError = confirmController.text == passwordController.text
            ? null
            : 'Passwords do not match';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in [
      nameController,
      phoneController,
      emailController,
      passwordController,
      confirmController,
    ])
      c.dispose();
    for (final n in [
      _nameFocus,
      _phoneFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
    ])
      n.dispose();
    super.dispose();
  }

  // ── Field decoration ──────────────────────────────────────────────────────
  InputDecoration _dec({
    required String hint,
    required IconData icon,
    required FocusNode focusNode,
    Widget? suffix,
    bool isError = false,
  }) {
    final bool focused = focusNode.hasFocus;
    final Color border = isError
        ? AppColors.borderError
        : focused
        ? AppColors.borderFocus
        : AppColors.borderDefault;
    final Color iconCol = isError
        ? AppColors.borderError
        : focused
        ? AppColors.iconFocus
        : AppColors.iconDefault;

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
      prefixIcon: Icon(icon, color: iconCol, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: focused ? AppColors.fieldBgFocus : AppColors.fieldBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 2.0),
      ),
    );
  }

  // ── Glow wrapper ──────────────────────────────────────────────────────────
  Widget _glow({
    required Widget child,
    required FocusNode focusNode,
    bool isError = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isError)
            BoxShadow(
              color: AppColors.borderError.withOpacity(0.28),
              blurRadius: 12,
              spreadRadius: 1,
            )
          else if (focusNode.hasFocus)
            BoxShadow(
              color: AppColors.borderFocus.withOpacity(0.28),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
      ),
      child: child,
    );
  }

  // ── Visibility toggle ─────────────────────────────────────────────────────
  Widget _vis({
    required bool obscure,
    required VoidCallback onTap,
    required FocusNode fn,
    bool isError = false,
  }) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: isError
            ? AppColors.borderError
            : fn.hasFocus
            ? AppColors.iconFocus
            : AppColors.iconDefault,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  // ── Rule row (shared for password + phone) ────────────────────────────────
  Widget _ruleRow(bool passed, String label) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        fontSize: 12,
        color: passed ? const Color(0xFF4CAF50) : AppColors.subtitle,
      ),
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
                  : AppColors.fieldBg,
              border: Border.all(
                color: passed
                    ? const Color(0xFF4CAF50)
                    : AppColors.borderDefault,
                width: 1.5,
              ),
            ),
            child: passed
                ? const Icon(Icons.check, size: 10, color: Color(0xFF4CAF50))
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // ── Password rules widget ─────────────────────────────────────────────────
  Widget _passwordRules() {
    if (passwordController.text.isEmpty) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ruleRow(_hasMinLength, 'At least 8 characters'),
            const SizedBox(height: 6),
            _ruleRow(_hasUppercase, 'At least one uppercase letter (A-Z)'),
            const SizedBox(height: 6),
            _ruleRow(_hasLowercase, 'At least one lowercase letter (a-z)'),
            const SizedBox(height: 6),
            _ruleRow(
              _hasSpecialChar,
              'At least one special character (- * ? @)',
            ),
          ],
        ),
      ),
    );
  }

  // ── Phone hint widget ─────────────────────────────────────────────────────
  Widget _phoneHint() {
    if (phoneController.text.isEmpty) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: _ruleRow(
          _phoneValid,
          _phoneValid
              ? 'Valid phone number'
              : 'Must start with 2, 4, 5 or 9 and be 8 digits',
        ),
      ),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _errorBanner() {
    if (_formError == null) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.borderError.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.borderError.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.borderError,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formError!,
                    style: const TextStyle(
                      color: AppColors.borderError,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasConfirmError = _confirmError != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Decorative images ──
          Positioned(
            top: 2,
            left: 0,
            child: SlideTransition(
              position: _leftImageAnimation,
              child: Image.asset("images/left.png", width: 250),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SlideTransition(
              position: _rightImageAnimation,
              child: Image.asset("images/left1.png", width: 250),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Gap(80),

                    // ── Title ──
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: const Text(
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),

                    const Gap(60),

                    const Text(
                      'Enter your information below',
                      style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                    ),

                    const Gap(28),

                    // ── Full Name ──
                    _glow(
                      focusNode: _nameFocus,
                      child: TextField(
                        controller: nameController,
                        focusNode: _nameFocus,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                        decoration: _dec(
                          hint: 'Full Name',
                          icon: Icons.person_outline,
                          focusNode: _nameFocus,
                        ),
                      ),
                    ),

                    const Gap(14),

                    // ── Phone ──
                    _glow(
                      focusNode: _phoneFocus,
                      child: TextField(
                        controller: phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: _dec(
                          hint: 'Phone Number',
                          icon: Icons.phone_outlined,
                          focusNode: _phoneFocus,
                        ),
                      ),
                    ),

                    // ── Phone hint ──
                    _phoneHint(),

                    const Gap(14),

                    // ── Email ──
                    _glow(
                      focusNode: _emailFocus,
                      child: TextField(
                        controller: emailController,
                        focusNode: _emailFocus,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                        decoration: _dec(
                          hint: 'Email Address',
                          icon: Icons.email_outlined,
                          focusNode: _emailFocus,
                        ),
                      ),
                    ),

                    const Gap(14),

                    // ── Password ──
                    _glow(
                      focusNode: _passwordFocus,
                      child: TextField(
                        controller: passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                        ),
                        decoration: _dec(
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          focusNode: _passwordFocus,
                          suffix: _vis(
                            obscure: _obscurePassword,
                            fn: _passwordFocus,
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Password rules ──
                    _passwordRules(),

                    const Gap(14),

                    // ── Confirm Password ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _glow(
                          focusNode: _confirmFocus,
                          isError: hasConfirmError,
                          child: TextField(
                            controller: confirmController,
                            focusNode: _confirmFocus,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                            ),
                            decoration: _dec(
                              hint: 'Confirm Password',
                              icon: Icons.lock_outline,
                              focusNode: _confirmFocus,
                              isError: hasConfirmError,
                              suffix: _vis(
                                obscure: _obscureConfirm,
                                fn: _confirmFocus,
                                isError: hasConfirmError,
                                onTap: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── Confirm error ──
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: hasConfirmError
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.borderError,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _confirmError!,
                                        style: const TextStyle(
                                          color: AppColors.borderError,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),

                    const Gap(26),

                    // ── Error banner ──
                    _errorBanner(),

                    // ── Sign Up Button ──
                    // ── Sign Up Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.primary,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() => _formError = null);

                                // ── Name ──
                                if (nameController.text.trim().isEmpty) {
                                  setState(
                                    () => _formError =
                                        'Please enter your full name',
                                  );
                                  return;
                                }

                                // ── Phone ──
                                if (phoneController.text.trim().isEmpty) {
                                  setState(
                                    () => _formError =
                                        'Please enter your phone number',
                                  );
                                  return;
                                }
                                if (!_phoneValid) {
                                  setState(
                                    () => _formError =
                                        'Phone must start with 2, 4, 5 or 9 and be 8 digits',
                                  );
                                  return;
                                }

                                // ── Email ──
                                if (emailController.text.trim().isEmpty) {
                                  setState(
                                    () => _formError =
                                        'Please enter your email address',
                                  );
                                  return;
                                }
                                if (!RegExp(
                                  r'^[\w.-]+@[\w.-]+\.\w{2,}$',
                                ).hasMatch(emailController.text.trim())) {
                                  setState(
                                    () => _formError =
                                        'Please enter a valid email address',
                                  );
                                  return;
                                }

                                // ── Password ──
                                if (passwordController.text.isEmpty) {
                                  setState(
                                    () =>
                                        _formError = 'Please enter a password',
                                  );
                                  return;
                                }
                                if (!_passwordValid) {
                                  setState(
                                    () => _formError =
                                        'Password does not meet the requirements',
                                  );
                                  return;
                                }

                                // ── Confirm ──
                                if (confirmController.text.isEmpty) {
                                  setState(
                                    () => _formError =
                                        'Please confirm your password',
                                  );
                                  return;
                                }
                                if (confirmController.text !=
                                    passwordController.text) {
                                  setState(
                                    () => _formError = 'Passwords do not match',
                                  );
                                  return;
                                }

                                // ── Call API ──
                                setState(() => _isLoading = true);

                                final response = await api.register(
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  email: emailController.text.trim(),
                                  password: passwordController.text,
                                );

                                setState(() => _isLoading = false);

                                if (response['success'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Registered successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  Navigator.pop(context);
                                } else {
                                  setState(
                                    () => _formError = response['message'],
                                  );
                                }
                              },
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'SIGN UP',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                      ),
                    ),

                    const Gap(24),

                    // ── OR Divider ──
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade800)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Or',
                            style: TextStyle(
                              color: AppColors.hint,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade800)),
                      ],
                    ),

                    const Gap(16),

                    Socialbuttons(onGoogleTap: () {}, onAppleTap: () {}),

                    const Gap(20),

                    // ── Login redirect ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: AppColors.subtitle,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Gap(40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
