import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/app/core/network/network_service.dart';
import 'package:spy_love/app/core/theme/app_colors.dart';
import 'package:spy_love/app/core/theme/app_tokens.dart';
import 'package:spy_love/app/core/widgets/app_button.dart';
import 'package:spy_love/app/core/widgets/app_card.dart';
import 'package:spy_love/app/core/widgets/app_states.dart';
import 'package:spy_love/app/core/widgets/app_text_field.dart';
import 'package:spy_love/app/core/widgets/responsive_scaffold.dart';
import 'package:spy_love/app/modules/auth/controllers/auth_controller.dart';

class AuthView extends StatelessWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) => const _AuthForm();
}

class _AuthForm extends StatefulWidget {
  const _AuthForm();

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _tenantController = TextEditingController();
  bool _isRegister = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _tenantController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final network = context.read<NetworkService>();
    final auth = context.read<AuthController>();
    if (!await network.ensureConnected()) return;

    if (_isRegister) {
      await auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        tenantName: _tenantController.text.trim(),
      );
    } else {
      await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final network = context.read<NetworkService>();
    final auth = context.read<AuthController>();
    if (!await network.ensureConnected()) return;
    if (!mounted) return;
    await auth.loginWithGoogle(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final network = context.watch<NetworkService>();

    return Scaffold(
      backgroundColor: tokens.background,
      body: ScaledTextScope(
        child: SafeArea(
          child: ResponsiveBody(
            maxWidth: 480,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: tokens.primarySoft,
                          shape: BoxShape.circle,
                          boxShadow: tokens.cardShadow,
                        ),
                        child: Icon(
                          Icons.health_and_safety_rounded,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.consented,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 12, color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'SPY LOVE ECOSYSTEM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Consent-First Device Safety',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Transparent mutual monitoring built for family care and trusted teams.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: tokens.surfaceContainerLow,
                  elevated: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: tokens.successSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_open_rounded, size: 18, color: tokens.consentedLabel),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Trust & Consent Guarantee', style: theme.textTheme.titleMedium),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.consented,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No hidden spyware. All monitored devices receive bidirectional pairing verification and persistent real-time consent audit indicators.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: auth.isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceContainer,
                                  borderRadius: BorderRadius.circular(AppRadius.badge),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _AuthTab(
                                        label: 'Sign In',
                                        selected: !_isRegister,
                                        onTap: () => setState(() => _isRegister = false),
                                      ),
                                    ),
                                    Expanded(
                                      child: _AuthTab(
                                        label: 'Create Account',
                                        selected: _isRegister,
                                        onTap: () => setState(() => _isRegister = true),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (!network.isConnected) ...[
                                OfflineBanner(onRetry: network.refreshStatus),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (_isRegister) ...[
                                AppTextField(
                                  controller: _tenantController,
                                  label: 'Family Circle or Team Workspace',
                                  hint: 'The Morrison Family Circle',
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Every member will share mutual view access within this space.',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: tokens.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                AppTextField(
                                  controller: _nameController,
                                  label: 'Full name',
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              AppTextField(
                                controller: _emailController,
                                label: _isRegister
                                    ? 'Caregiver / Admin Email'
                                    : 'Email address',
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) =>
                                    v == null || !v.contains('@') ? 'Invalid email' : null,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppTextField(
                                controller: _passwordController,
                                label: 'Secure Password',
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                validator: (v) =>
                                    v == null || v.length < 10 ? 'Min 10 characters' : null,
                              ),
                              if (auth.errorMessage.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  auth.errorMessage,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              AppButton(
                                label: _isRegister
                                    ? 'Continue to Workspace Setup'
                                    : 'Sign in',
                                loading: auth.isLoading,
                                onPressed: auth.isLoading ? null : _submit,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                    child: Text(
                                      'OR VERIFY WITH',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        letterSpacing: 0.6,
                                        fontWeight: FontWeight.w700,
                                        color: tokens.secondaryText,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppButton(
                                label: 'Continue with Google',
                                icon: Icons.g_mobiledata,
                                variant: AppButtonVariant.secondary,
                                loading: auth.isGoogleLoading,
                                onPressed: auth.isGoogleLoading ? null : _signInWithGoogle,
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.badge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : tokens.secondaryText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
