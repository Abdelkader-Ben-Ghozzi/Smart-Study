import 'package:app1/screens/Register.dart';
import 'package:app1/screens/forgot_password.dart';
import 'package:app1/screens/home_screen.dart';
import 'package:app1/widgets/socialButtons.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:gap/gap.dart';
import 'package:app1/services/api_service.dart';
import 'package:app1/theme/app_color.dart';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _leftSlide;
  late Animation<Offset> _rightSlide;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _leftSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-2.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rightSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // ADD THIS ↓
    Future.delayed(const Duration(seconds: 1), () {
      _controller.forward().whenComplete(() async {
        final storage = const FlutterSecureStorage();
        final rememberMe = await storage.read(key: 'remember_me');
        final token = await storage.read(key: 'token');

        if (rememberMe == 'true' && token != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: SlideTransition(
              position: _leftSlide,
              child: Image.asset("images/left.png", width: 300),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: SlideTransition(
              position: _rightSlide,
              child: Image.asset("images/right.png", width: 300),
            ),
          ),
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset("images/logo.png", scale: 0.5),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: const Text(
                  "Smart Study",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN (Login)
// ════════════════════════════════════════════════════════════════════════════

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late AnimationController _controller;
  late Animation<Offset> _leftImageAnimation;
  late Animation<Offset> _rightImageAnimation;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  late TextEditingController emailController;
  late TextEditingController passwordController;
  late ApiService api;

  bool _isChecked = false;
  bool _isLoading = false;
  String? _formError;

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    emailController = TextEditingController();
    passwordController = TextEditingController();
    api = ApiService();

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

    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // ── Load saved credentials if remember me was checked ──
    _loadSavedCredentials();
  }

  // ── Load saved credentials ────────────────────────────────────────────────
  Future<void> _loadSavedCredentials() async {
    final rememberMe = await _storage.read(key: 'remember_me');
    if (rememberMe == 'true') {
      final savedEmail = await _storage.read(key: 'saved_email');
      final savedPassword = await _storage.read(key: 'saved_password');
      if (savedEmail != null && savedPassword != null) {
        setState(() {
          emailController.text = savedEmail;
          passwordController.text = savedPassword;
          _isChecked = true;
        });
      }
    }
  }

  // ── Save or clear credentials ─────────────────────────────────────────────
  Future<void> _handleRememberMe(String email, String password) async {
    if (_isChecked) {
      await _storage.write(key: 'remember_me', value: 'true');
      await _storage.write(key: 'saved_email', value: email);
      await _storage.write(key: 'saved_password', value: password);
    } else {
      await _storage.delete(key: 'remember_me');
      await _storage.delete(key: 'saved_email');
      await _storage.delete(key: 'saved_password');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Field decoration ──────────────────────────────────────────────────────
  InputDecoration _dec({
    required String hint,
    required IconData icon,
    required FocusNode focusNode,
    Widget? suffix,
  }) {
    final bool focused = focusNode.hasFocus;
    final Color border = focused
        ? AppColors.borderFocus
        : AppColors.borderDefault;
    final Color iconCol = focused ? AppColors.iconFocus : AppColors.iconDefault;

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
  Widget _glow({required Widget child, required FocusNode focusNode}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (focusNode.hasFocus)
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

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _errorBanner() {
    if (_formError == null) return const SizedBox.shrink();
    return Column(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
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
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: const Column(
                            children: [
                              Text(
                                'LOGIN TO',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                ),
                              ),
                              Text(
                                'YOUR ACCOUNT',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Gap(80),

                      const Text(
                        'Enter your login information',
                        style: TextStyle(
                          color: AppColors.subtitle,
                          fontSize: 13,
                        ),
                      ),

                      const Gap(35),

                      _glow(
                        focusNode: _emailFocus,
                        child: TextField(
                          controller: emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
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
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _passwordFocus.hasFocus
                                    ? AppColors.iconFocus
                                    : AppColors.iconDefault,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Gap(6),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isChecked = !_isChecked),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: _isChecked
                                        ? AppColors.primary
                                        : AppColors.fieldBg,
                                    border: Border.all(
                                      color: _isChecked
                                          ? AppColors.primary
                                          : AppColors.borderDefault,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _isChecked
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember me',
                                  style: TextStyle(
                                    color: AppColors.hint,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.subtitle,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),

                      const Gap(16),
                      _errorBanner(),

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
                                  setState(() {
                                    _formError = null;
                                    _isLoading = true;
                                  });

                                  if (emailController.text.trim().isEmpty) {
                                    setState(() {
                                      _formError = 'Please enter your email';
                                      _isLoading = false;
                                    });
                                    return;
                                  }
                                  if (!RegExp(
                                    r'^[\w.-]+@[\w.-]+\.\w{2,}$',
                                  ).hasMatch(emailController.text.trim())) {
                                    setState(() {
                                      _formError =
                                          'Please enter a valid email address';
                                      _isLoading = false;
                                    });
                                    return;
                                  }
                                  if (passwordController.text.isEmpty) {
                                    setState(() {
                                      _formError = 'Please enter your password';
                                      _isLoading = false;
                                    });
                                    return;
                                  }

                                  await _handleRememberMe(
                                    emailController.text.trim(),
                                    passwordController.text,
                                  );

                                  try {
                                    final response = await api.login(
                                      email: emailController.text.trim(),
                                      password: passwordController.text,
                                    );
                                    if (response['success'] == true) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HomeScreen(),
                                        ),
                                      );
                                    } else {
                                      setState(
                                        () => _formError =
                                            response['message'] ??
                                            'Login failed',
                                      );
                                    }
                                  } on SocketException {
                                    setState(
                                      () =>
                                          _formError = 'No internet connection',
                                    );
                                  } on TimeoutException {
                                    setState(
                                      () => _formError =
                                          'Request timed out, please try again',
                                    );
                                  } catch (e) {
                                    setState(
                                      () => _formError =
                                          'Something went wrong, please try again',
                                    );
                                  } finally {
                                    setState(() => _isLoading = false);
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
                                  'LOGIN',
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

                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade800)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Or',
                              style: TextStyle(
                                color: Color(0xFF3E4460),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade800)),
                        ],
                      ),

                      const Gap(16),

                      SizedBox(
                        width: double.infinity,
                        child: Socialbuttons(
                          onGoogleTap: () {},
                          onAppleTap: () {},
                        ),
                      ),

                      const Gap(20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: AppColors.subtitle,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ).then((_) {
                                _controller.reset();
                                _controller.forward();
                              });
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Gap(24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
