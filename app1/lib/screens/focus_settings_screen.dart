// lib/screens/focus_settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import '../providers/focus_provider.dart';
import '../theme/app_colors.dart';
import '../models/focus_session.dart';
import '../services/focus_service.dart';
import 'active_focus_screen.dart';

// ── Installed apps provider ────────────────────────────────────────────────
final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  if (!Platform.isAndroid) return [];
  final apps = await FlutterDeviceApps.listApps(
    includeIcons: true,
    includeSystem: false,
    onlyLaunchable: true,
  );
  // Filter out SmartStudy itself
  apps.removeWhere((a) => a.packageName == 'com.example.app1');
  apps.sort(
    (a, b) => (a.appName ?? '').toLowerCase().compareTo(
      (b.appName ?? '').toLowerCase(),
    ),
  );
  return apps;
});

enum _SortMode { alphabetical, screenTime }

class FocusSettingsScreen extends ConsumerStatefulWidget {
  final bool startOnSave;
  const FocusSettingsScreen({super.key, this.startOnSave = true});

  @override
  ConsumerState<FocusSettingsScreen> createState() =>
      _FocusSettingsScreenState();
}

class _FocusSettingsScreenState extends ConsumerState<FocusSettingsScreen> {
  int _durationMinutes = 50;
  Set<String> _blockedApps = {};
  String _searchQuery = '';
  bool _saving = false;
  _SortMode _sortMode = _SortMode.alphabetical;
  Map<String, int> _usageMinutes = {};
  bool _loadingUsage = false;

  static const _durations = [30, 60, 90];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(focusSettingsProvider).valueOrNull;
      if (s != null) {
        setState(() {
          _durationMinutes = s.durationMinutes;
          _blockedApps = s.blockedApps.toSet();
        });
      }
    });
  }

  Future<void> _loadUsageStats() async {
    if (_loadingUsage) return;
    setState(() => _loadingUsage = true);
    try {
      final stats = await FocusService.getUsageStats();
      setState(() => _usageMinutes = stats);
    } catch (_) {}
    setState(() => _loadingUsage = false);
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;

    if (!await FocusService.hasOverlayPermission()) {
      final ok = await _showPermissionDialog(
        title: 'Display over other apps',
        body:
            'SmartStudy needs this to show the focus timer bubble '
            'while you use your device.',
        actionLabel: 'Open Settings',
        onAction: FocusService.requestOverlayPermission,
      );
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!await FocusService.hasOverlayPermission()) return false;
    }

    if (!await FocusService.hasAccessibilityPermission()) {
      final ok = await _showPermissionDialog(
        title: 'Accessibility permission',
        body:
            'SmartStudy uses the Accessibility Service to detect '
            'when a blocked app is opened and send you back immediately.'
            '\n\nIn the next screen: tap "SmartStudy Focus" → turn ON.',
        actionLabel: 'Open Accessibility Settings',
        onAction: FocusService.requestAccessibilityPermission,
      );
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!await FocusService.hasAccessibilityPermission()) return false;
    }

    return true;
  }

  Future<bool> _showPermissionDialog({
    required String title,
    required String body,
    required String actionLabel,
    required Future<void> Function() onAction,
  }) async {
    final c = AppColors.of(context);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: c.borderDefault),
            ),
            title: Text(
              title,
              style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
            ),
            content: Text(
              body,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Not now',
                  style: TextStyle(color: c.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  await onAction();
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveAndStart() async {
    setState(() => _saving = true);

    final settings = FocusSettings(
      durationMinutes: _durationMinutes,
      blockedApps: _blockedApps.toList(),
    );
    await ref.read(focusSettingsProvider.notifier).save(settings);

    if (!widget.startOnSave) {
      setState(() => _saving = false);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final ok = await _ensurePermissions();
    if (!ok) {
      setState(() => _saving = false);
      return;
    }

    final started = await ref
        .read(activeFocusProvider.notifier)
        .startSession(_durationMinutes, _blockedApps.toList());

    setState(() => _saving = false);
    if (!mounted) return;

    if (started) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ActiveFocusScreen(blockedPackages: _blockedApps.toList()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not start. Check your connection.'),
          backgroundColor: AppColors.of(context).error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  String _fmtUsage(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        title: Text(
          widget.startOnSave ? 'Focus Setup' : 'Focus Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                // ── Duration ──────────────────────────────────────────────
                _SectionLabel('Session duration'),
                Row(
                  children: [
                    ..._durations.map(
                      (d) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _DurationChip(
                            minutes: d,
                            selected: _durationMinutes == d,
                            onTap: () => setState(() => _durationMinutes = d),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _DurationChip(
                        minutes: 0,
                        selected: !_durations.contains(_durationMinutes),
                        isCustom: true,
                        customLabel: !_durations.contains(_durationMinutes)
                            ? '${_durationMinutes}m'
                            : null,
                        onTap: _showCustomDuration,
                      ),
                    ),
                  ],
                ),

                // ── Apps to block ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 4),
                  child: Divider(color: c.divider),
                ),
                _SectionLabel(
                  'Apps to block'
                  '${_blockedApps.isNotEmpty ? '  (${_blockedApps.length})' : ''}',
                ),

                if (!Platform.isAndroid)
                  _IosManualEntry(
                    blockedApps: _blockedApps,
                    onAdd: (n) => setState(() => _blockedApps.add(n)),
                    onRemove: (n) => setState(() => _blockedApps.remove(n)),
                  )
                else ...[
                  // ── Sort toggle ──────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SortTab(
                            label: 'A–Z',
                            selected: _sortMode == _SortMode.alphabetical,
                            onTap: () => setState(
                              () => _sortMode = _SortMode.alphabetical,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _SortTab(
                            label: 'Screen time',
                            selected: _sortMode == _SortMode.screenTime,
                            onTap: () {
                              setState(() => _sortMode = _SortMode.screenTime);
                              _loadUsageStats();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Search ───────────────────────────────────────────
                  Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: c.fieldBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      style: TextStyle(fontSize: 14, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(fontSize: 14, color: c.hint),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: c.iconDefault,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  if (_sortMode == _SortMode.screenTime && _loadingUsage)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: c.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),

                  // ── App list ─────────────────────────────────────────
                  ref
                      .watch(installedAppsProvider)
                      .when(
                        loading: () => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: c.primary,
                                  strokeWidth: 2,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Loading your apps...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.subtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Could not load apps: $e',
                            style: TextStyle(fontSize: 13, color: c.subtitle),
                          ),
                        ),
                        data: (apps) {
                          var filtered = _searchQuery.isEmpty
                              ? apps
                              : apps
                                    .where(
                                      (a) => (a.appName ?? '')
                                          .toLowerCase()
                                          .contains(_searchQuery),
                                    )
                                    .toList();

                          // Sort by screen time if selected
                          if (_sortMode == _SortMode.screenTime &&
                              _usageMinutes.isNotEmpty) {
                            filtered = List.from(filtered);
                            filtered.sort((a, b) {
                              final aMin =
                                  _usageMinutes[a.packageName ?? ''] ?? 0;
                              final bMin =
                                  _usageMinutes[b.packageName ?? ''] ?? 0;
                              return bMin.compareTo(aMin);
                            });
                          }

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No apps found',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.subtitle,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: filtered.map((app) {
                              final pkgName = app.packageName ?? '';
                              final usageMin = _usageMinutes[pkgName];
                              return _AppListItem(
                                app: app,
                                checked: _blockedApps.contains(pkgName),
                                usageLabel:
                                    (_sortMode == _SortMode.screenTime &&
                                        usageMin != null &&
                                        usageMin > 0)
                                    ? _fmtUsage(usageMin)
                                    : null,
                                onTap: () {
                                  if (pkgName.isEmpty) return;
                                  setState(() {
                                    if (_blockedApps.contains(pkgName)) {
                                      _blockedApps.remove(pkgName);
                                    } else {
                                      _blockedApps.add(pkgName);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                ],
              ],
            ),
          ),

          // ── Bottom button ──────────────────────────────────────────────
          Container(
            color: c.bg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAndStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        widget.startOnSave ? 'Start Focus Session' : 'Save',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomDuration() async {
    int temp = _durationMinutes;
    final c = AppColors.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.borderDefault),
        ),
        title: Text('Custom duration', style: TextStyle(color: c.text)),
        content: StatefulBuilder(
          builder: (ctx, set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$temp minutes',
                style: TextStyle(
                  color: c.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: c.primary,
                  inactiveTrackColor: c.borderDefault,
                  thumbColor: c.primary,
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 10,
                  max: 180,
                  divisions: 17,
                  value: temp.toDouble(),
                  onChanged: (v) => set(() => temp = v.round()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _durationMinutes = temp);
              Navigator.pop(ctx);
            },
            child: Text('Set', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sort tab widget
// ─────────────────────────────────────────────────────────────────────────────
class _SortTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label == 'A–Z'
                  ? Icons.sort_by_alpha_rounded
                  : Icons.bar_chart_rounded,
              size: 14,
              color: selected ? c.primary : c.subtitle,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? c.primary : c.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App list item
// ─────────────────────────────────────────────────────────────────────────────
class _AppListItem extends StatelessWidget {
  final AppInfo app;
  final bool checked;
  final String? usageLabel;
  final VoidCallback onTap;

  const _AppListItem({
    required this.app,
    required this.checked,
    required this.onTap,
    this.usageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final icon = app.iconBytes;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: checked ? c.primary.withOpacity(0.08) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? c.primary.withOpacity(0.4) : c.borderDefault,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: icon != null
                  ? Image.memory(icon, width: 36, height: 36, fit: BoxFit.cover)
                  : Container(
                      width: 36,
                      height: 36,
                      color: c.fieldBg,
                      child: Icon(
                        Icons.apps_rounded,
                        size: 20,
                        color: c.iconDefault,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName ?? 'Unknown App',
                    style: TextStyle(fontSize: 14, color: c.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (usageLabel != null)
                    Text(
                      usageLabel!,
                      style: TextStyle(fontSize: 11, color: c.subtitle),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: checked ? c.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: checked ? c.primary : c.borderDefault,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS manual entry
// ─────────────────────────────────────────────────────────────────────────────
class _IosManualEntry extends StatefulWidget {
  final Set<String> blockedApps;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  const _IosManualEntry({
    required this.blockedApps,
    required this.onAdd,
    required this.onRemove,
  });
  @override
  State<_IosManualEntry> createState() => _IosManualEntryState();
}

class _IosManualEntryState extends State<_IosManualEntry> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'iOS does not allow reading installed apps. Enter app names manually.',
          style: TextStyle(fontSize: 12, color: c.subtitle, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: c.fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.borderDefault),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: TextStyle(fontSize: 14, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'e.g. Instagram',
                    hintStyle: TextStyle(fontSize: 14, color: c.hint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onSubmitted: (v) {
                    final n = v.trim();
                    if (n.isNotEmpty) {
                      widget.onAdd(n);
                      _ctrl.clear();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final n = _ctrl.text.trim();
                if (n.isNotEmpty) {
                  widget.onAdd(n);
                  _ctrl.clear();
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.blockedApps
              .map(
                (name) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: TextStyle(fontSize: 13, color: c.text)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.onRemove(name),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: c.iconDefault,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.9,
          color: c.subtitle,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final bool isCustom;
  final String? customLabel;
  final VoidCallback onTap;

  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.12) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.primary : c.borderDefault),
        ),
        child: Column(
          children: [
            Text(
              isCustom ? (customLabel ?? '+') : '$minutes',
              style: TextStyle(
                fontSize: isCustom && customLabel != null ? 16 : 20,
                fontWeight: FontWeight.w600,
                color: selected ? c.primary : c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isCustom ? 'custom' : 'min',
              style: TextStyle(fontSize: 11, color: c.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}
