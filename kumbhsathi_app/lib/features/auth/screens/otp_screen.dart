import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/gov_footer.dart';
import '../../../shared/widgets/gradient_button.dart';

/// Premium OTP verification — DESIGN.md §6.5 "Sanctum".
///
/// Same chrome as login (heroGradient + watermark + scrim, floating card).
/// Six digit boxes (radius 14, accent focus ring) with auto-advance, and a
/// countdown ring drawn around a 48px lock icon gating the resend flow.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.phone = '+91 98765 43210'});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _resendSeconds = 120;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtp();
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    final cleanPhone = widget.phone.replaceAll(' ', '');
    final ok =
        await ref.read(authStateProvider.notifier).sendOtp(phone: cleanPhone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      final err = ref.read(authStateProvider).error ?? 'Failed to send OTP';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent successfully (Use 123456)')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit OTP')),
      );
      return;
    }
    setState(() => _loading = true);
    final cleanPhone = widget.phone.replaceAll(' ', '');
    final ok = await ref.read(authStateProvider.notifier).verifyOtp(
          phone: cleanPhone,
          otp: otp,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      final err =
          ref.read(authStateProvider).error ?? 'OTP verification failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() {});
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChanged(int i, String v) {
    if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      FocusScope.of(context).unfocus();
    }
  }

  /// Staggered entrance for the card sections (≤6, 50ms apart).
  Widget _stagger(int index, Widget child) => child
      .animate(delay: Duration(milliseconds: 50 * index))
      .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut)
      .slideY(begin: 0.06, duration: AppMotion.enter, curve: AppMotion.easeOut);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _OtpBackdrop(),
          SafeArea(
            child: Stack(
              children: [
                if (context.canPop())
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                      icon: const Icon(Symbols.arrow_back,
                          color: Colors.white),
                    ),
                  ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: AppSpacing.xl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCard(context)
                              .animate()
                              .fadeIn(
                                  duration: AppMotion.enter,
                                  curve: AppMotion.easeOut)
                              .slideY(
                                  begin: 0.06,
                                  duration: AppMotion.enter,
                                  curve: AppMotion.easeOut),
                          const SizedBox(height: AppSpacing.xl),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.sheet),
                            child: const GovFooter(),
                          )
                              .animate(
                                  delay: const Duration(milliseconds: 300))
                              .fadeIn(duration: AppMotion.enter),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canResend = _secondsLeft <= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.modal),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stagger(
            0,
            _OtpCountdownRing(progress: _secondsLeft / _resendSeconds),
          ),
          const SizedBox(height: AppSpacing.lg),
          _stagger(
            1,
            Column(
              children: [
                Text(
                  'Verify phone number',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text.rich(
                  TextSpan(
                    text: 'Enter the 6-digit code sent to ',
                    style:
                        text.bodyMedium?.copyWith(color: AppColors.inkMedium),
                    children: [
                      TextSpan(
                        text: widget.phone,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _stagger(
            2,
            LayoutBuilder(
              builder: (context, constraints) {
                final boxWidth =
                    ((constraints.maxWidth - 5 * AppSpacing.sm) / 6)
                        .clamp(40.0, 54.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (i) => _OtpDigitBox(
                      width: boxWidth,
                      controller: _controllers[i],
                      node: _nodes[i],
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _stagger(
            3,
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.schedule,
                        size: 16, color: AppColors.inkMedium),
                    const SizedBox(width: AppSpacing.sm),
                    canResend
                        ? Text(
                            'Ready to resend',
                            style: text.bodyMedium
                                ?.copyWith(color: AppColors.success),
                          )
                        : Text.rich(
                            TextSpan(
                              text: 'Resend OTP in ',
                              style: text.bodyMedium
                                  ?.copyWith(color: AppColors.inkMedium),
                              children: [
                                TextSpan(
                                  text: _timerLabel,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
                TextButton(
                  onPressed: canResend && !_loading
                      ? () {
                          _startTimer();
                          _sendOtp();
                        }
                      : null,
                  child: const Text('Resend OTP'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _stagger(
            4,
            PrimaryCta(
              label: 'Verify & Proceed',
              icon: Symbols.arrow_forward,
              loading: _loading,
              onPressed: _verifyOtp,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _stagger(
            5,
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Symbols.edit, size: 16),
              label: const Text('Change Phone Number'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed heroGradient + watermark at low opacity under the scrim.
class _OtpBackdrop extends StatelessWidget {
  const _OtpBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
        ),
        Image.asset(
          'assets/images/auth_bg.png',
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.07),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.scrimGradient),
        ),
      ],
    );
  }
}

/// Countdown ring (accent) drawn around a 48px tonal lock icon disc.
class _OtpCountdownRing extends StatelessWidget {
  const _OtpCountdownRing({required this.progress});

  /// 1.0 = full time remaining, 0.0 = ready to resend.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.linear,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                color: AppColors.accent,
                backgroundColor: AppColors.surfaceSunken,
              ),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.lock,
              size: 24,
              fill: 1,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single OTP digit box — radius 14, accent focus ring, auto-advance.
class _OtpDigitBox extends StatelessWidget {
  const _OtpDigitBox({
    required this.width,
    required this.controller,
    required this.node,
    required this.onChanged,
  });
  final double width;
  final TextEditingController controller;
  final FocusNode node;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: node,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: AppColors.surfaceSunken,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.hairline, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
