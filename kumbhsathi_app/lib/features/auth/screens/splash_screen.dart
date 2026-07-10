import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';

/// Premium splash screen — DESIGN.md §6.5 "Sanctum".
///
/// Full-bleed [AppColors.heroGradient] with the auth watermark at low opacity
/// + scrim; centered app icon with scale-in animation, app title in
/// [displayLarge], tagline, and gov footer line. Auto-navigates after ~2.5s
/// to onboarding (first install) or login/home (returning user).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Wait for the splash animation to play.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final auth = ref.read(authStateProvider);

    // If already authenticated, go straight to home.
    if (auth.status == AuthStatus.authenticated) {
      context.go(Routes.home);
      return;
    }

    // Check if onboarding has been completed.
    final storage = ref.read(secureStorageProvider);
    final onboardingDone = await storage.read('onboarding_done');
    if (!mounted) return;

    if (onboardingDone == 'true') {
      context.go(Routes.login);
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient + watermark + scrim.
          const _SplashBackdrop(),
          // Content.
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(flex: 3),
                  // App icon with scale + fade.
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.hero),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1.4,
                      ),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.temple_hindu,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                        duration: AppMotion.enter,
                        curve: AppMotion.easeOut,
                      )
                      .fadeIn(
                        duration: AppMotion.enter,
                        curve: AppMotion.easeOut,
                      ),
                  const SizedBox(height: AppSpacing.xl),
                  // App name.
                  Text(
                    'KumbhSathi AI',
                    style: text.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut)
                      .slideY(
                        begin: 0.06,
                        duration: AppMotion.enter,
                        curve: AppMotion.easeOut,
                      ),
                  const SizedBox(height: AppSpacing.sm),
                  // Tagline.
                  Text(
                    'Missing-Person Incident Management\n& Decision Support OS',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  )
                      .animate(delay: 350.ms)
                      .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut),
                  const Spacer(flex: 4),
                  // Loading indicator.
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      strokeCap: StrokeCap.round,
                      color: AppColors.accent,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  )
                      .animate(delay: 500.ms)
                      .fadeIn(duration: AppMotion.enter),
                  const SizedBox(height: AppSpacing.xxl),
                  // Gov footer text.
                  Text(
                    'Government of India Initiative\nKumbh Mela 2027',
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  )
                      .animate(delay: 600.ms)
                      .fadeIn(duration: AppMotion.enter),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed heroGradient + watermark at low opacity under the scrim.
class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

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
          opacity: const AlwaysStoppedAnimation(0.06),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.scrimGradient),
        ),
      ],
    );
  }
}
