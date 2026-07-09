import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Initials avatar on a deterministic tonal background (DESIGN.md §5).
/// Never loads remote images for people — privacy + offline-first.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(
    this.name, {
    super.key,
    this.size = 40,
    this.statusDot,
  });

  final String name;
  final double size;

  /// Optional presence/status dot color (e.g. AppColors.success).
  final Color? statusDot;

  static const _palette = [
    (bg: Color(0xFFD6E5FA), fg: Color(0xFF0B4FA3)),
    (bg: Color(0xFFFDEBD7), fg: Color(0xFFB35F04)),
    (bg: Color(0xFFDCF3E8), fg: Color(0xFF13704A)),
    (bg: Color(0xFFEDE3FA), fg: Color(0xFF6A3AA6)),
    (bg: Color(0xFFFBE3E3), fg: Color(0xFFA13030)),
    (bg: Color(0xFFDDEAFB), fg: Color(0xFF245B9C)),
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = _palette[name.hashCode.abs() % _palette.length];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: TextStyle(
              color: c.fg,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.38,
            ),
          ),
        ),
        if (statusDot != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: statusDot,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
