import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Dialog used for both creating and renaming a subject.
Future<String?> showSubjectDialog(
  BuildContext context, {
  String? initialName,
}) async {
  final c = AppColors.of(context);
  final ctrl = TextEditingController(text: initialName ?? '');
  final isEdit = initialName != null;

  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.borderDefault),
      ),
      title: Text(
        isEdit ? 'Rename Subject' : 'New Subject',
        style: TextStyle(
          color: c.text,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: TextStyle(color: c.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'e.g. Mathematics',
          hintStyle: TextStyle(color: c.hint),
          filled: true,
          fillColor: c.fieldBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.borderDefault),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.borderDefault),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.borderFocus, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final val = ctrl.text.trim();
            if (val.isNotEmpty) Navigator.pop(ctx, val);
          },
          child: Text(
            isEdit ? 'Save' : 'Create',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Confirm delete dialog.
Future<bool> showDeleteConfirmDialog(BuildContext context, String name) async {
  final c = AppColors.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.borderDefault),
      ),
      title: Text(
        'Delete Subject',
        style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Are you sure you want to delete "$name"?\nThis will also remove its chapters and documents.',
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
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
