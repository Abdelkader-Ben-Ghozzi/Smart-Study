import 'package:app1/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app1/theme/app_color.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';

// ── Shared helpers ────────────────────────────────────────────────────────────

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

ButtonStyle _btnStyle() => ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  elevation: 4,
  shadowColor: AppColors.primary,
);

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 1 — Forgot Password (Enter Email)
// ─────────────────────────────────────────────────────────────────────────────
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();
  String? _formError;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<Offset> _leftImageAnimation;
  late Animation<Offset> _rightImageAnimation;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

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
    _emailFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const _BackButton(),
                  SizedBox(height: screenHeight * 0.22),
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: const SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Forgot your password?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              "Don't worry! Please enter your email\nto reset your password.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.subtitle,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _glow(
                    focusNode: _emailFocus,
                    isError: _formError != null,
                    child: TextField(
                      controller: _emailController,
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
                        isError: _formError != null,
                      ),
                    ),
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.borderError,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: const TextStyle(
                              color: AppColors.borderError,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: _btnStyle(),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _formError = null);
                              if (_emailController.text.trim().isEmpty) {
                                setState(
                                  () => _formError = 'Please enter your email',
                                );
                                return;
                              }
                              if (!RegExp(
                                r'^[\w.-]+@[\w.-]+\.\w{2,}$',
                              ).hasMatch(_emailController.text.trim())) {
                                setState(
                                  () => _formError =
                                      'Please enter a valid email address',
                                );
                                return;
                              }
                              setState(() => _isLoading = true);
                              final response = await ApiService().checkEmail(
                                _emailController.text.trim(),
                              );
                              setState(() => _isLoading = false);
                              if (response['success'] == true) {
                                Navigator.push(
                                  context,
                                  _slideRoute(
                                    ChooseOtpMethodPage(
                                      email: _emailController.text.trim(),
                                      maskedEmail: response['masked_email'],
                                      maskedPhone: response['masked_phone'],
                                    ),
                                  ),
                                );
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
                              'CONTINUE',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 1.5 — Choose OTP Method
// ─────────────────────────────────────────────────────────────────────────────
class ChooseOtpMethodPage extends StatefulWidget {
  final String email;
  final String maskedEmail;
  final String maskedPhone;
  const ChooseOtpMethodPage({
    super.key,
    required this.email,
    required this.maskedEmail,
    required this.maskedPhone,
  });
  @override
  State<ChooseOtpMethodPage> createState() => _ChooseOtpMethodPageState();
}

class _ChooseOtpMethodPageState extends State<ChooseOtpMethodPage>
    with SingleTickerProviderStateMixin {
  String _selected = 'email';
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<Offset> _leftImageAnimation;
  late Animation<Offset> _rightImageAnimation;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _methodCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool chosen = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: chosen
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.fieldBg,
          border: Border.all(
            color: chosen ? AppColors.primary : AppColors.borderDefault,
            width: chosen ? 2 : 1.5,
          ),
          boxShadow: chosen
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chosen
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.fieldBgFocus,
              ),
              child: Icon(
                icon,
                color: chosen ? AppColors.primary : AppColors.iconDefault,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: chosen ? Colors.white : AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: chosen ? AppColors.text : AppColors.subtitle,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chosen ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: chosen ? AppColors.primary : AppColors.borderDefault,
                  width: 2,
                ),
              ),
              child: chosen
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const _BackButton(),
                  SizedBox(height: screenHeight * 0.18),
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: const SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'How to receive your code?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Choose where you want us to send\nyour verification code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.subtitle,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  _methodCard(
                    value: 'email',
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'Send code to ${widget.maskedEmail}',
                  ),
                  const SizedBox(height: 16),
                  _methodCard(
                    value: 'phone',
                    icon: Icons.phone_outlined,
                    title: 'Phone Number',
                    subtitle: 'Send code to ${widget.maskedPhone}',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: _btnStyle(),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              final response = await ApiService().sendOtp(
                                widget.email,
                                _selected,
                              );
                              setState(() => _isLoading = false);
                              if (response['success'] == true) {
                                Navigator.push(
                                  context,
                                  _slideRoute(
                                    VerifyAccountPage(
                                      method: _selected,
                                      email: widget.email,
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(response['message']),
                                    backgroundColor: AppColors.borderError,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
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
                              'SEND CODE',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 2 — Verify Account (OTP)
// ─────────────────────────────────────────────────────────────────────────────
class VerifyAccountPage extends StatefulWidget {
  final String method;
  final String email;
  const VerifyAccountPage({
    super.key,
    required this.method,
    required this.email,
  });
  @override
  State<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends State<VerifyAccountPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  late AnimationController _controller;
  late Animation<Offset> _leftImageAnimation;
  late Animation<Offset> _rightImageAnimation;

  static const int _maxResend = 3;
  static const int _maxAttempts = 10;
  static const int _expirySeconds = 300;

  int _resendCount = 0;
  int _attemptCount = 0;
  int _secondsLeft = _expirySeconds;
  bool _isExpired = false;
  bool _isLocked = false;
  String? _otpError;
  Timer? _expiryTimer;

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
    _controller.forward();
    for (final f in _focusNodes) {
      f.addListener(() => setState(() {}));
    }
    for (final c in _otpControllers) {
      c.addListener(() => setState(() {}));
    }
    _startTimer();
  }

  void _startTimer() {
    _expiryTimer?.cancel();
    setState(() {
      _secondsLeft = _expirySeconds;
      _isExpired = false;
    });
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _isExpired = true;
          timer.cancel();
        }
      });
    });
  }

  String get _timerDisplay {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _resend() async {
    if (_resendCount >= _maxResend) return;
    final response = await ApiService().sendOtp(widget.email, widget.method);
    if (response['success'] == true) {
      setState(() {
        _resendCount++;
        _attemptCount = 0;
        _otpError = null;
        _isLocked = false;
        for (final c in _otpControllers) {
          c.clear();
        }
      });
      _startTimer();
    } else {
      setState(() => _otpError = response['message']);
    }
  }

  void _verify(BuildContext context) async {
    if (_isLocked) {
      setState(
        () => _otpError = 'Too many attempts. Please request a new code.',
      );
      return;
    }
    if (_isExpired) {
      setState(() => _otpError = 'Code has expired. Please request a new one.');
      return;
    }
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 5) {
      setState(() => _otpError = 'Please enter the complete 5-digit code.');
      return;
    }
    final response = await ApiService().verifyOtp(widget.email, otp);
    if (response['success'] == true) {
      _expiryTimer?.cancel();
      Navigator.push(
        context,
        _slideRoute(
          CreateNewPasswordPage(
            email: widget.email,
            resetToken: response['reset_token'],
          ),
        ),
      );
    } else {
      if (response['locked'] == true) {
        setState(() {
          _isLocked = true;
          _isExpired = true;
        });
        _expiryTimer?.cancel();
      }
      if (response['expired'] == true) {
        setState(() => _isExpired = true);
      }
      setState(() => _otpError = response['message']);
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _controller.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isEmail = widget.method == 'email';
    final bool canResend = _resendCount < _maxResend;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(
            top: 2,
            left: 0,
            child: SlideTransition(
              position: _leftImageAnimation,
              child: Image.asset(
                isEmail ? "images/left.png" : "images/orange_right.png",
                width: 250,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SlideTransition(
              position: _rightImageAnimation,
              child: Image.asset(
                isEmail ? "images/left1.png" : "images/orange_left.png",
                width: 250,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const _BackButton(),
                  SizedBox(height: screenHeight * 0.18),

                  // ── Title ──
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Enter Your OTP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isEmail
                              ? 'A verification code was sent to your email.'
                              : 'A verification code was sent to your phone.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.subtitle,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEmail
                                    ? Icons.email_outlined
                                    : Icons.phone_outlined,
                                color: AppColors.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isEmail ? 'Via Email' : 'Via Phone',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Timer + attempts ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 15,
                            color: _isExpired
                                ? AppColors.borderError
                                : _secondsLeft <= 60
                                ? Colors.orange
                                : AppColors.subtitle,
                          ),
                          const SizedBox(width: 5),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isExpired
                                  ? AppColors.borderError
                                  : _secondsLeft <= 60
                                  ? Colors.orange
                                  : AppColors.subtitle,
                            ),
                            child: Text(_isExpired ? 'Expired' : _timerDisplay),
                          ),
                        ],
                      ),
                      if (!_isLocked)
                        Text(
                          '${_maxAttempts - _attemptCount} attempts left',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_maxAttempts - _attemptCount) <= 3
                                ? Colors.orange
                                : AppColors.subtitle,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── OTP boxes ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      5,
                      (i) => _OtpBox(
                        controller: _otpControllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (v) {
                          if (v.length == 1 && i < 4) {
                            _focusNodes[i + 1].requestFocus();
                          } else if (v.isEmpty && i > 0)
                            _focusNodes[i - 1].requestFocus();
                          setState(() {});
                        },
                        isError: _otpError != null,
                        isLocked: _isLocked || _isExpired,
                      ),
                    ),
                  ),

                  // ── OTP error ──
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _otpError != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Icon(
                                  _isLocked
                                      ? Icons.lock_outline
                                      : Icons.error_outline,
                                  color: AppColors.borderError,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _otpError!,
                                    style: const TextStyle(
                                      color: AppColors.borderError,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 28),

                  // ── Verify button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: (_isLocked || _isExpired)
                          ? ElevatedButton.styleFrom(
                              backgroundColor: AppColors.fieldBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            )
                          : _btnStyle(),
                      onPressed: _isLocked ? null : () => _verify(context),
                      child: Text(
                        _isExpired && !_isLocked ? 'Code Expired' : 'VERIFY',
                        style: TextStyle(
                          fontSize: 15,
                          color: (_isLocked || _isExpired)
                              ? AppColors.subtitle
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Resend row ──
                  Center(
                    child: _isLocked
                        ? GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Go back and try again',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.subtitle,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: "Didn't receive code? ",
                                    ),
                                    TextSpan(
                                      text: canResend
                                          ? 'Resend Now'
                                          : 'No resends left',
                                      style: TextStyle(
                                        color: canResend
                                            ? AppColors.primary
                                            : AppColors.subtitle,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: canResend
                                          ? (TapGestureRecognizer()
                                              ..onTap = _resend)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Resends remaining: ',
                                    style: TextStyle(
                                      color: AppColors.subtitle,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    children: List.generate(_maxResend, (i) {
                                      final used = i < _resendCount;
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: used
                                              ? AppColors.borderDefault
                                              : AppColors.primary,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 3 — Create New Password
// ─────────────────────────────────────────────────────────────────────────────
class CreateNewPasswordPage extends StatefulWidget {
  final String email;
  final String resetToken;
  const CreateNewPasswordPage({
    super.key,
    required this.email,
    required this.resetToken,
  });
  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _confirmError;
  String? _formError;
  bool _attemptedSubmit = false;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<Offset> _leftImageAnimation;
  late Animation<Offset> _rightImageAnimation;

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
    _controller.forward();
    _passwordFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
    _confirmController.addListener(_validateConfirm);
    _passwordController.addListener(_validateConfirm);
  }

  void _validateConfirm() {
    if (_attemptedSubmit || _confirmController.text.isNotEmpty) {
      setState(() {
        _confirmError = _confirmController.text == _passwordController.text
            ? null
            : 'Passwords do not match';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bool hasErr = _confirmError != null;

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const _BackButton(),
                  SizedBox(height: screenHeight * 0.18),

                  const SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Create New Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Set a strong password to secure your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.subtitle,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  _glow(
                    focusNode: _passwordFocus,
                    child: TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePass,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                      ),
                      decoration: _dec(
                        hint: 'New Password',
                        icon: Icons.lock_outline,
                        focusNode: _passwordFocus,
                        suffix: _vis(
                          obscure: _obscurePass,
                          fn: _passwordFocus,
                          onTap: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _glow(
                        focusNode: _confirmFocus,
                        isError: hasErr,
                        child: TextField(
                          controller: _confirmController,
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
                            isError: hasErr,
                            suffix: _vis(
                              obscure: _obscureConfirm,
                              fn: _confirmFocus,
                              isError: hasErr,
                              onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: hasErr
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6, left: 6),
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

                  const SizedBox(height: 16),

                  // ── Form error banner ──
                  if (_formError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: _btnStyle(),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() {
                                _attemptedSubmit = true;
                                _formError = null;
                              });
                              _validateConfirm();
                              if (_confirmController.text !=
                                  _passwordController.text) {
                                return;
                              }
                              if (_passwordController.text.isEmpty) {
                                setState(
                                  () => _formError = 'Please enter a password',
                                );
                                return;
                              }

                              setState(() => _isLoading = true);
                              final response = await ApiService().resetPassword(
                                email: widget.email,
                                resetToken: widget.resetToken,
                                password: _passwordController.text,
                              );
                              setState(() => _isLoading = false);

                              if (response['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Password reset successfully!',
                                    ),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
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
                              'RESET PASSWORD',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault, width: 1.5),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white70,
          size: 16,
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isError;
  final bool isLocked;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.isError = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = controller.text.isNotEmpty;
    final bool focused = focusNode.hasFocus;

    final Color borderColor = isLocked
        ? AppColors.borderDefault
        : isError && filled
        ? AppColors.borderError
        : filled || focused
        ? AppColors.primary
        : AppColors.borderDefault;

    final Color fillColor = isLocked
        ? AppColors.fieldBg.withOpacity(0.5)
        : isError && filled
        ? AppColors.borderError.withOpacity(0.1)
        : filled
        ? AppColors.primary.withOpacity(0.18)
        : focused
        ? AppColors.fieldBgFocus
        : AppColors.fieldBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if ((focused || filled) && !isLocked && !isError)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
            )
          else if (isError && filled)
            BoxShadow(
              color: AppColors.borderError.withOpacity(0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        enabled: !isLocked,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isLocked ? AppColors.subtitle : Colors.white,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.borderDefault.withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation helper
// ─────────────────────────────────────────────────────────────────────────────
PageRouteBuilder _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}
