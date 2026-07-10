import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/core_providers.dart';
import '../../../shared/widgets/gradient_button.dart';

/// Premium onboarding — 3-page flow introducing the app's capabilities.
///
/// Follows DESIGN.md "Sanctum" design: heroGradient backgrounds, tonal icon
/// discs, staggered entrance animations, dot page indicators with accent
/// active dot, skip + next/get-started CTA.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Symbols.person_search,
      title: 'Find Missing Persons',
      description:
          'AI-powered missing person tracking across the vast Kumbh Mela '
          'grounds. Report, search, and reunite families with intelligent '
          'case management and real-time coordination.',
    ),
    _OnboardingPage(
      icon: Symbols.face,
      title: 'AI-Powered Matching',
      description:
          'On-device face recognition instantly matches found individuals '
          'against reported cases. Offline Aadhaar verification and smart '
          'duplicate detection accelerate reunions.',
    ),
    _OnboardingPage(
      icon: Symbols.cloud_off,
      title: 'Works Offline',
      description:
          'Built for Kumbh Mela\'s challenging connectivity. Every feature '
          'degrades gracefully — registrations, face scans, and AI interviews '
          'all work without internet and sync when connectivity returns.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: AppMotion.enter,
        curve: AppMotion.easeOut,
      );
    } else {
      _complete();
    }
  }

  void _skip() => _complete();

  Future<void> _complete() async {
    final storage = ref.read(secureStorageProvider);
    await storage.write('onboarding_done', 'true');
    if (!mounted) return;
    context.go(Routes.register);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background.
          const _OnboardingBackdrop(),
          // Pages.
          SafeArea(
            child: Column(
              children: [
                // Skip button at top right.
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      right: AppSpacing.base,
                    ),
                    child: TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut),
                // Page content.
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) =>
                        _OnboardingPageView(data: _pages[index]),
                  ),
                ),
                // Bottom controls: dots + button.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.base,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      // Dot indicators.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: AppMotion.enter,
                            curve: AppMotion.easeOut,
                            width: i == _page ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                              delay: 400.ms,
                              duration: AppMotion.enter,
                              curve: AppMotion.easeOut),
                      const SizedBox(height: AppSpacing.xl),
                      // Action button.
                      PrimaryCta(
                        label: isLast ? 'Get Started' : 'Next',
                        icon: isLast
                            ? Symbols.arrow_forward
                            : Symbols.chevron_right,
                        onPressed: _next,
                      )
                          .animate()
                          .fadeIn(
                              delay: 500.ms,
                              duration: AppMotion.enter,
                              curve: AppMotion.easeOut)
                          .slideY(
                              begin: 0.06,
                              delay: 500.ms,
                              duration: AppMotion.enter,
                              curve: AppMotion.easeOut),
                      const SizedBox(height: AppSpacing.md),
                      // Gov text.
                      Text(
                        'Kumbh Mela 2027 • Government of India',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.4),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                      )
                          .animate()
                          .fadeIn(
                              delay: 600.ms,
                              duration: AppMotion.enter),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for a single onboarding page.
class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
}

/// Single onboarding page view with tonal icon disc, title, and description.
class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.data});
  final _OnboardingPage data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tonal icon disc.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.4,
              ),
            ),
            child: Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon,
                  size: 48,
                  fill: 1,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: AppMotion.enter,
                curve: AppMotion.easeOut,
              )
              .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut),
          const SizedBox(height: AppSpacing.xxxl),
          // Title.
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: text.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut)
              .slideY(
                begin: 0.06,
                duration: AppMotion.enter,
                curve: AppMotion.easeOut,
              ),
          const SizedBox(height: AppSpacing.base),
          // Description.
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6,
            ),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: AppMotion.enter, curve: AppMotion.easeOut),
        ],
      ),
    );
  }
}

/// Full-bleed heroGradient + watermark at low opacity under the scrim.
class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

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
          opacity: const AlwaysStoppedAnimation(0.05),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.scrimGradient),
        ),
      ],
    );
  }
}
