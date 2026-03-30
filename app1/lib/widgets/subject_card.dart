import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../theme/app_colors.dart';

/// Palette of accent colors assigned round-robin to subjects.
const _kAccents = [
  Color(0xFF3055E7), // blue
  Color(0xFF7C3AED), // violet
  Color(0xFF0EA5E9), // sky
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
];

Color _accentFor(int id) => _kAccents[id % _kAccents.length];

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = _accentFor(subject.id);
    final initials = subject.name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Accent strip + initials ──
            Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withOpacity(0.18), accent.withOpacity(0.06)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    top: -12,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // ── Options menu ──
                  Positioned(
                    top: 6,
                    right: 4,
                    child: _OptionsMenu(
                      onRename: onRename,
                      onDelete: onDelete,
                      accent: accent,
                      colors: c,
                    ),
                  ),
                ],
              ),
            ),

            // ── Name + stats ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Chip(
                        icon: Icons.layers_outlined,
                        label: '${subject.chaptersCount}',
                        accent: accent,
                        colors: c,
                      ),
                      const SizedBox(width: 6),
                      _Chip(
                        icon: Icons.description_outlined,
                        label: '${subject.documentsCount}',
                        accent: accent,
                        colors: c,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final AppColorScheme colors;

  const _Chip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsMenu extends StatelessWidget {
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final Color accent;
  final AppColorScheme colors;

  const _OptionsMenu({
    required this.onRename,
    required this.onDelete,
    required this.accent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: colors.textSecondary,
      ),
      color: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderDefault),
      ),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v == 'rename') onRename();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: colors.textSecondary),
              const SizedBox(width: 10),
              Text(
                'Rename',
                style: TextStyle(color: colors.text, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFFE53935),
              ),
              const SizedBox(width: 10),
              const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFE53935), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
