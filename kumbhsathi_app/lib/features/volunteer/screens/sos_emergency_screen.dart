import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/offline_banner.dart';

/// SOS Emergency — volunteer-only emergency alert dispatch for critical
/// situations (medical, lost child, crowd surge, security). Offline-safe
/// with hive queue.
class SosEmergencyScreen extends ConsumerStatefulWidget {
  const SosEmergencyScreen({super.key});

  @override
  ConsumerState<SosEmergencyScreen> createState() =>
      _SosEmergencyScreenState();
}

class _SosEmergencyScreenState extends ConsumerState<SosEmergencyScreen> {
  bool _loading = true;
  _SosType? _selectedType;
  final _descController = TextEditingController();
  String? _photoPath;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 400)).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
      );
      if (xFile != null && mounted) {
        setState(() => _photoPath = xFile.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access camera.')),
      );
    }
  }

  Future<void> _sendSos() async {
    if (_selectedType == null) return;
    setState(() => _sending = true);

    final messenger = ScaffoldMessenger.of(context);
    final online = ref.read(isOnlineProvider);

    try {
      // Simulate a small network delay
      await Future<void>.delayed(const Duration(milliseconds: 800));

      if (!online) {
        await ref.read(hiveServiceProvider).queueRequest(
          path: '/volunteers/vol-8842/sos',
          method: 'POST',
          body: {
            'type': _selectedType!.label,
            'description': _descController.text.trim(),
            'sector': 'Sector 4',
            'has_photo': _photoPath != null,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          },
        );
        messenger.showSnackBar(const SnackBar(
          content: Text('SOS saved offline — will dispatch when online'),
        ));
      }
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Failed to send SOS. Please try again.'),
      ));
    }
  }

  void _reset() {
    setState(() {
      _selectedType = null;
      _descController.clear();
      _photoPath = null;
      _sent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.emergency, color: AppColors.danger, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Emergency SOS',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        shape: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: _loading
                  ? const _SosSkeleton()
                  : _sent
                      ? _buildConfirmation(theme)
                      : _buildForm(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutterMobile,
          AppSpacing.base, AppSpacing.gutterMobile, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              children: [
                const Icon(Symbols.warning, size: 20, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Use only for genuine emergencies. False alerts may result in disciplinary action.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onDangerContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),

          const SizedBox(height: AppSpacing.lg),

          // Emergency type selector
          Text(
            'EMERGENCY TYPE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          )
              .animate(delay: 50.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.6,
            children: [
              for (final type in _SosType.values)
                _SosTypeCard(
                  type: type,
                  selected: _selectedType == type,
                  onTap: () => setState(() => _selectedType = type),
                ),
            ],
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),

          const SizedBox(height: AppSpacing.lg),

          // Location
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: const Icon(Symbols.location_on,
                      size: 22, color: AppColors.accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sector 4 · Near Medical Camp',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.gps_fixed,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'GPS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate(delay: 150.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),

          const SizedBox(height: AppSpacing.base),

          // Description
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Description',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe the situation briefly…',
                    hintStyle: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.inkFaint),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                ),
              ],
            ),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),

          const SizedBox(height: AppSpacing.base),

          // Photo
          AppCard(
            onTap: _capturePhoto,
            child: _photoPath != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.input),
                        child: Image.file(
                          File(_photoPath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Symbols.check_circle,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'Photo captured',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _capturePhoto,
                            child: const Text('Retake'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(AppRadius.input),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Icon(Symbols.add_a_photo,
                            size: 22,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Photo (optional)',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Capture the situation for responders',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),

          const SizedBox(height: AppSpacing.xl),

          // Send CTA
          _SosSendButton(
            enabled: _selectedType != null,
            loading: _sending,
            onPressed: _selectedType != null ? _sendSos : null,
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
        ],
      ),
    );
  }

  Widget _buildConfirmation(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutterMobile),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.check_circle,
                size: 48, color: AppColors.success),
          )
              .animate()
              .fadeIn(duration: 240.ms)
              .scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'SOS Alert Sent',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Emergency services have been notified.\nHelp is on the way.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
              .animate(delay: 150.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _SosConfirmRow(
                  label: 'SOS ID',
                  value: 'SOS-${DateTime.now().millisecondsSinceEpoch % 100000}',
                ),
                const Divider(height: AppSpacing.xl),
                _SosConfirmRow(
                  label: 'Type',
                  value: _selectedType?.label ?? 'Unknown',
                ),
                const Divider(height: AppSpacing.xl),
                const _SosConfirmRow(
                  label: 'Location',
                  value: 'Sector 4 · Medical Camp',
                ),
                const Divider(height: AppSpacing.xl),
                const _SosConfirmRow(
                  label: 'ETA Responder',
                  value: '~3 minutes',
                ),
              ],
            ),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: AppSpacing.xl),
          PrimaryCta.tonal(
            label: 'Report Another Emergency',
            icon: Symbols.add,
            onPressed: _reset,
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.06),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SOS types
// ---------------------------------------------------------------------------

enum _SosType {
  medical('Medical\nEmergency', Symbols.local_hospital, AppColors.danger,
      AppColors.dangerContainer),
  lostChild('Lost Child\nSpotted', Symbols.child_care, AppColors.accent,
      AppColors.accentContainer),
  crowdSurge('Crowd\nSurge', Symbols.groups, AppColors.warning,
      AppColors.warningContainer),
  security('Security\nThreat', Symbols.shield, AppColors.primary,
      AppColors.primaryContainer);

  const _SosType(this.label, this.icon, this.color, this.container);

  final String label;
  final IconData icon;
  final Color color;
  final Color container;
}

class _SosTypeCard extends StatelessWidget {
  const _SosTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final _SosType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.exit,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? type.container : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? type.color : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, size: 28, color: type.color),
              const SizedBox(height: AppSpacing.sm),
              Text(
                type.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? type.color
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send button (danger-themed CTA)
// ---------------------------------------------------------------------------

class _SosSendButton extends StatelessWidget {
  const _SosSendButton({
    required this.enabled,
    required this.loading,
    this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(AppRadius.button));

    return AnimatedOpacity(
      duration: AppMotion.exit,
      opacity: enabled ? 1.0 : 0.55,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.danger, Color(0xFFA32929)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : theme.colorScheme.surfaceContainerHigh,
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.3),
                    offset: const Offset(0, 6),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled && !loading ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.emergency,
                            size: 22, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'SEND SOS ALERT',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: enabled
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation row
// ---------------------------------------------------------------------------

class _SosConfirmRow extends StatelessWidget {
  const _SosConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _SosSkeleton extends StatelessWidget {
  const _SosSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.gutterMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShimmerBox(height: 52, radius: AppRadius.input),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(width: 140, height: 16),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 90, radius: AppRadius.card)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: ShimmerBox(height: 90, radius: AppRadius.card)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 90, radius: AppRadius.card)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: ShimmerBox(height: 90, radius: AppRadius.card)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 80, radius: AppRadius.card),
          SizedBox(height: AppSpacing.base),
          ShimmerBox(height: 130, radius: AppRadius.card),
          SizedBox(height: AppSpacing.base),
          ShimmerBox(height: 80, radius: AppRadius.card),
          SizedBox(height: AppSpacing.xl),
          ShimmerBox(height: 56, radius: AppRadius.button),
        ],
      ),
    );
  }
}
