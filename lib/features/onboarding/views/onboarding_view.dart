import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spy_love/core/onboarding/onboarding_controller.dart';
import 'package:spy_love/core/theme/app_tokens.dart';
import 'package:spy_love/shared/widgets/app_button.dart';
import 'package:spy_love/shared/widgets/responsive_scaffold.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _page = PageController();
  int _index = 0;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      icon: Icons.favorite_rounded,
      title: 'Consent first, always',
      body:
          'Spy Love is a family device circle where every monitored person opts in. '
          'Nothing is hidden: both sides see what is shared and can pause or stop anytime.',
    ),
    _OnboardPage(
      icon: Icons.handshake_outlined,
      title: 'Mutual pairing',
      body:
          'Link phones with a short code or QR. The monitored phone confirms before any '
          'location, usage, or activity data leaves the device.',
    ),
    _OnboardPage(
      icon: Icons.privacy_tip_outlined,
      title: 'Permissions you control',
      body:
          'Android and iOS permissions are requested only for the scopes you enable. '
          'You can revoke them in system settings or pause sharing from Account.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<OnboardingController>().complete();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final last = _index >= _pages.length - 1;

    return Scaffold(
      backgroundColor: tokens.background,
      body: ScaledTextScope(
        child: SafeArea(
          child: ResponsiveBody(
            maxWidth: 480,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Skip onboarding',
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Semantics(
                              image: true,
                              label: p.title,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: tokens.primarySoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p.icon,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              p.title,
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              p.body,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: tokens.secondaryText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => Semantics(
                      label: 'Page ${i + 1} of ${_pages.length}',
                      selected: i == _index,
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? theme.colorScheme.primary
                              : tokens.border,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Semantics(
                    button: true,
                    label: last ? 'Get started' : 'Next onboarding page',
                    child: AppButton(
                      label: last ? 'Get started' : 'Next',
                      onPressed: () {
                        if (last) {
                          _finish();
                        } else {
                          _page.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                        }
                      },
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

class _OnboardPage {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}
