import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shared official-government footer from the Stitch auth screens:
/// Gov of India seal, "Powered by AI • Ministry of Electronics & IT",
/// policy links and copyright line.
class GovFooter extends StatelessWidget {
  const GovFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Image.asset('assets/images/gov_seal.png',
              height: 48, fit: BoxFit.contain),
          const SizedBox(height: 8),
          Text(
            'Powered by AI • Ministry of Electronics & IT',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 8,
            children: [
              for (final label in const ['Privacy Policy', 'Help Desk', 'Terms of Service'])
                Text(label,
                    style: text.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '© 2024 KumbhSathi AI • Government of India Initiative',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
