import 'package:flutter/material.dart';

class Socialbuttons extends StatelessWidget {
  final VoidCallback? onGoogleTap;
  final VoidCallback? onAppleTap;

  const Socialbuttons({super.key, this.onGoogleTap, this.onAppleTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _socialButton(
            icon: Image.asset("images/google.png", height: 20),
            text: "GOOGLE",
            onTap: onGoogleTap ?? () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _socialButton(
            icon: const Icon(Icons.apple, color: Colors.white, size: 20),
            text: "APPLE",
            onTap: onAppleTap ?? () {},
          ),
        ),
      ],
    );
  }

  Widget _socialButton({
    required Widget icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2A2A3F)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
