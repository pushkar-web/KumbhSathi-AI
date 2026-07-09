import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/gov_footer.dart';
import '../../../shared/widgets/gradient_button.dart';

/// Premium registration — DESIGN.md §6.5 "Sanctum".
///
/// Same chrome as login (heroGradient + watermark + scrim, floating card
/// max-w 440 / radius modal / raised shadow) with a 3-step flow:
/// Details → Security → Preferences (role as 2x2 tonal tile grid + language).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _securityKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'family';
  String _language = 'en';
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  int _step = 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (_detailsKey.currentState?.validate() ?? false) {
        setState(() => _step = 1);
      }
      return;
    }
    if (_step == 1) {
      if (_securityKey.currentState?.validate() ?? false) {
        setState(() => _step = 2);
      }
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final ok = await ref.read(authStateProvider.notifier).register(
          fullName: _name.text.trim(),
          phone: '+91${_phone.text.trim()}',
          password: _password.text,
          role: _role,
          email: _email.text.trim(),
          languageCode: _language,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please login.')),
      );
      context.go(Routes.login, extra: _phone.text.trim());
    } else {
      final err = ref.read(authStateProvider).error ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
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
          const _RegBackdrop(),
          SafeArea(
            child: Center(
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
                        borderRadius: BorderRadius.circular(AppRadius.sheet),
                        child: const GovFooter(),
                      )
                          .animate(delay: const Duration(milliseconds: 300))
                          .fadeIn(duration: AppMotion.enter),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.modal),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stagger(
            0,
            Center(
              child: Column(
                children: [
                  const _RegLogoChip(),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    'Create account',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Join the official Kumbh Mela platform',
                    textAlign: TextAlign.center,
                    style:
                        text.bodyMedium?.copyWith(color: AppColors.inkMedium),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _stagger(1, _RegStepRail(step: _step)),
          const SizedBox(height: AppSpacing.lg),
          _stagger(
            2,
            AnimatedSize(
              duration: AppMotion.enter,
              curve: AppMotion.easeOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: AppMotion.enter,
                switchInCurve: AppMotion.easeOut,
                switchOutCurve: AppMotion.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey<int>(_step),
                  child: _buildStep(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _stagger(
            3,
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: PrimaryCta.tonal(
                      label: 'Back',
                      onPressed:
                          _loading ? null : () => setState(() => _step -= 1),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  flex: 2,
                  child: PrimaryCta(
                    label: _step == 2 ? 'Create Account' : 'Continue',
                    icon: _step == 2
                        ? Symbols.how_to_reg
                        : Symbols.arrow_forward,
                    loading: _loading,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _stagger(
            4,
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => context.pop(),
                child: const Text('Already have an account? Login'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildDetailsStep(context);
      case 1:
        return _buildSecurityStep(context);
      default:
        return _buildPreferencesStep(context);
    }
  }

  Widget _buildDetailsStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RegFieldLabel('Full name'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: Icon(Symbols.person, size: 20),
            ),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Enter your name' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          const _RegFieldLabel('Phone number'),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: '10-digit mobile number',
              prefixIcon: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  '+91',
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.inkMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
            validator: (v) => (v == null || v.trim().length != 10)
                ? 'Enter a valid 10-digit number'
                : null,
          ),
          const SizedBox(height: AppSpacing.base),
          const _RegFieldLabel('Email (optional)'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Enter your email address',
              prefixIcon: Icon(Symbols.mail, size: 20),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              return value.contains('@') && value.contains('.')
                  ? null
                  : 'Enter a valid email address';
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _securityKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RegFieldLabel('Password'),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Create a strong password',
              prefixIcon: const Icon(Symbols.lock, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure ? Symbols.visibility : Symbols.visibility_off,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          const _RegFieldLabel('Confirm password'),
          TextFormField(
            controller: _confirm,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Symbols.lock_reset, size: 20),
              suffixIcon: IconButton(
                tooltip:
                    _obscureConfirm ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirm
                      ? Symbols.visibility
                      : Symbols.visibility_off,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Use at least 6 characters. Your credentials are stored securely.',
            style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RegFieldLabel('Select role'),
        _RegRoleGrid(
          selected: _role,
          onSelect: (r) => setState(() => _role = r),
        ),
        const SizedBox(height: AppSpacing.base),
        const _RegFieldLabel('Preferred language'),
        DropdownButtonFormField<String>(
          initialValue: _language,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Symbols.language, size: 20),
          ),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'hi', child: Text('Hindi')),
            DropdownMenuItem(value: 'mr', child: Text('Marathi')),
            DropdownMenuItem(value: 'bn', child: Text('Bengali')),
            DropdownMenuItem(value: 'ta', child: Text('Tamil')),
          ],
          onChanged: (v) => setState(() => _language = v ?? 'en'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You can change your language anytime from settings.',
          style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
        ),
      ],
    );
  }
}

/// Full-bleed heroGradient + watermark at low opacity under the scrim.
class _RegBackdrop extends StatelessWidget {
  const _RegBackdrop();

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

class _RegLogoChip extends StatelessWidget {
  const _RegLogoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Image.asset(
        'assets/images/logo.png',
        height: 44,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Symbols.temple_hindu,
          size: 36,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Filled pill rail step indicator: Details → Security → Preferences.
class _RegStepRail extends StatelessWidget {
  const _RegStepRail({required this.step});
  final int step;

  static const List<String> _names = ['Details', 'Security', 'Preferences'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _names.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.enter,
                  curve: AppMotion.easeOut,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        i <= step ? AppColors.primary : AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'STEP ${step + 1} OF ${_names.length} — ${_names[step].toUpperCase()}',
          style: text.labelSmall?.copyWith(
            color: AppColors.inkFaint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _RegFieldLabel extends StatelessWidget {
  const _RegFieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
        ),
      );
}

class _RegRole {
  const _RegRole(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

/// 2x2 grid of tonal segmented role tiles (icon + label).
class _RegRoleGrid extends StatelessWidget {
  const _RegRoleGrid({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  static const List<_RegRole> _roles = [
    _RegRole('family', 'Family', Symbols.family_restroom),
    _RegRole('police', 'Police', Symbols.local_police),
    _RegRole('volunteer', 'Volunteer', Symbols.volunteer_activism),
    _RegRole('admin', 'Admin', Symbols.admin_panel_settings),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile(_RegRole role) => Expanded(
          child: _RegRoleTile(
            role: role,
            selected: selected == role.id,
            onTap: () => onSelect(role.id),
          ),
        );
    return Column(
      children: [
        Row(children: [
          tile(_roles[0]),
          const SizedBox(width: AppSpacing.sm),
          tile(_roles[1]),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          tile(_roles[2]),
          const SizedBox(width: AppSpacing.sm),
          tile(_roles[3]),
        ]),
      ],
    );
  }
}

class _RegRoleTile extends StatelessWidget {
  const _RegRoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });
  final _RegRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: role.label,
      child: AnimatedContainer(
        duration: AppMotion.exit,
        curve: Curves.easeOut,
        height: 52,
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primaryContainer : AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: 1.4,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.input),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  role.icon,
                  size: 20,
                  fill: selected ? 1 : 0,
                  color: selected ? AppColors.primary : AppColors.inkMedium,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    role.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? AppColors.onPrimaryContainer
                              : AppColors.inkMedium,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
