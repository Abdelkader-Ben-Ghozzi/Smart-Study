import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../theme/app_colors.dart';

class DeckCard extends StatelessWidget {
  final Deck deck;
  final VoidCallback onTap;

  const DeckCard({super.key, required this.deck, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: c.primary.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Deck icon ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.style_outlined, color: c.primary, size: 20),
            ),
            const SizedBox(height: 12),

            // ── Title ──
            Text(
              deck.title,
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

            // ── Card count + date ──
            Row(
              children: [
                Icon(Icons.layers_outlined, size: 13, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${deck.flashcardsCount} cards',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Review CTA ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 14, color: c.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Review',
                    style: TextStyle(
                      color: c.primary,
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
    );
  }
}
