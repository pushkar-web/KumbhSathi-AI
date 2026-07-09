import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Tonal status pill: 6px dot + label (DESIGN.md §5).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key}) : _label = null;
  const StatusBadge.fromLabel(String label, {super.key})
      : status = null, _label = label;

  final CaseStatus? status;
  final String? _label;

  static ({Color fg, Color bg}) colorsFor(CaseStatus s) => switch (s) {
        CaseStatus.pending =>
          (fg: AppColors.warning, bg: AppColors.warningContainer),
        CaseStatus.searching =>
          (fg: AppColors.accentDeep, bg: AppColors.accentContainer),
        CaseStatus.reunited =>
          (fg: AppColors.success, bg: AppColors.successContainer),
        CaseStatus.transferredToHospital =>
          (fg: AppColors.hospital, bg: AppColors.hospitalContainer),
        CaseStatus.unresolved =>
          (fg: AppColors.danger, bg: AppColors.dangerContainer),
      };

  @override
  Widget build(BuildContext context) {
    final s = status ?? CaseStatus.fromString(_label);
    final c = colorsFor(s);
    return _Pill(label: s.label, fg: c.fg, bg: c.bg);
  }
}

/// Priority pill; Critical renders filled for maximum salience.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key}) : _label = null;
  const PriorityBadge.fromLabel(String label, {super.key})
      : priority = null, _label = label;

  final CasePriority? priority;
  final String? _label;

  @override
  Widget build(BuildContext context) {
    final p = priority ?? CasePriority.fromString(_label);
    return switch (p) {
      CasePriority.low => const _Pill(
          label: 'Low', fg: AppColors.success, bg: AppColors.successContainer),
      CasePriority.medium => const _Pill(
          label: 'Medium',
          fg: AppColors.warning,
          bg: AppColors.warningContainer),
      CasePriority.high => const _Pill(
          label: 'High',
          fg: AppColors.accentDeep,
          bg: AppColors.accentContainer),
      CasePriority.critical => const _Pill(
          label: 'Critical',
          fg: Colors.white,
          bg: AppColors.danger,
          dotColor: Colors.white),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.dotColor,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: dotColor ?? fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
