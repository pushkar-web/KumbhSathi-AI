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

/// Premium login — DESIGN.md §6.5 "Sanctum".
///
/// Full-bleed [AppColors.heroGradient] with the auth watermark at low opacity
/// under [AppColors.scrimGradient]; a centered floating card (max-w 440,
/// radius modal, raised shadow) holding the logo chip, a 2x2 tonal role
/// selector, phone + password fields, [PrimaryCta] login, OTP alternative and
/// register link. Minimal [GovFooter] below the card.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.registeredPhone});
  final String? registeredPhone;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _role;
  String _language = 'en';
  bool _obscure = true;
  bool _loading = false;
  bool _roleError = false;

  @override
  void initState() {
    super.initState();
    if (widget.registeredPhone != null) {
      _phone.text = widget.registeredPhone!;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final roleMissing = _role == null;
    final valid = _formKey.currentState!.validate();
    if (roleMissing || !valid) {
      setState(() => _roleError = roleMissing);
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(authStateProvider.notifier).login(
          phone: '+91${_phone.text.trim()}',
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      final err = ref.read(authStateProvider).error ?? 'Login failed';
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
          const _LoginBackdrop(),
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
                          .animate(
                              delay: const Duration(milliseconds: 300))
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stagger(0, const Center(child: _LoginLogoChip())),
            const SizedBox(height: AppSpacing.lg),
            _stagger(
              1,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Sign in to continue to KumbhSathi AI',
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.inkMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _LoginLangChip(
                    value: _language,
                    onChanged: (v) => setState(() => _language = v ?? 'en'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _stagger(
              2,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LoginFieldLabel('Select role'),
                  _LoginRoleGrid(
                    selected: _role,
                    onSelect: (r) => setState(() {
                      _role = r;
                      _roleError = false;
                    }),
                  ),
                  if (_roleError)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Please select a role to continue',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            _stagger(
              3,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LoginFieldLabel('Phone number'),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Enter 10-digit mobile number',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
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
                      suffixIcon: const Icon(Symbols.phone_iphone, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().length != 10)
                        ? 'Enter a valid 10-digit number'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  const _LoginFieldLabel('Password'),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Symbols.lock, size: 20),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Symbols.visibility
                              : Symbols.visibility_off,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Minimum 6 characters'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _stagger(
              4,
              PrimaryCta(
                label: 'Login',
                icon: Symbols.login,
                loading: _loading,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _stagger(
              5,
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.inkMedium),
                    ),
                    GestureDetector(
                      onTap: () => context.push(Routes.register),
                      child: Text(
                        'Register here',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed heroGradient + watermark at low opacity under the scrim.
class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

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

class _LoginLogoChip extends StatelessWidget {
  const _LoginLogoChip();

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
        height: 48,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Symbols.temple_hindu,
          size: 40,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _LoginFieldLabel extends StatelessWidget {
  const _LoginFieldLabel(this.label);
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

class _LoginRole {
  const _LoginRole(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

/// 2x2 grid of tonal segmented role tiles (icon + label).
class _LoginRoleGrid extends StatelessWidget {
  const _LoginRoleGrid({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  static const List<_LoginRole> _roles = [
    _LoginRole('family', 'Family', Symbols.family_restroom),
    _LoginRole('police', 'Police', Symbols.local_police),
    _LoginRole('volunteer', 'Volunteer', Symbols.volunteer_activism),
    _LoginRole('admin', 'Admin', Symbols.admin_panel_settings),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile(_LoginRole role) => Expanded(
          child: _LoginRoleTile(
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

class _LoginRoleTile extends StatelessWidget {
  const _LoginRoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });
  final _LoginRole role;
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
          color: selected ? AppColors.primaryContainer : AppColors.surfaceSunken,
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

class _LoginLangChip extends StatelessWidget {
  const _LoginLangChip({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.language, size: 16, color: AppColors.inkMedium),
          const SizedBox(width: AppSpacing.xs),
          DropdownButton<String>(
            value: value,
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(AppRadius.input),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
            icon: const Icon(
              Symbols.keyboard_arrow_down,
              size: 16,
              color: AppColors.inkMedium,
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
              DropdownMenuItem(value: 'mr', child: Text('मराठी')),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}


