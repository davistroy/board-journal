import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';

/// Sign-in screen - OAuth authentication options.
///
/// Per PRD Section 5.0:
/// - Apple Sign-In button (required for iOS)
/// - Google Sign-In button
/// - Microsoft Sign-In button
/// - "Skip for now" option (local-only mode)
/// - Flow: Welcome -> Privacy -> OAuth -> First Entry (Home)
class SigninScreen extends ConsumerStatefulWidget {
  const SigninScreen({super.key});

  @override
  ConsumerState<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends ConsumerState<SigninScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authNotifierProvider);

    // Listen for auth state changes
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.isAuthenticated) {
        // Navigate to home on successful auth
        _completeOnboardingAndNavigate();
      } else if (next.status == AuthStatus.error) {
        setState(() {
          _isLoading = false;
          _errorMessage = next.errorMessage;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.onboardingPrivacy),
        ),
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Sign-in Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.login_outlined,
                  size: 48,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Sign in to sync',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Sign in to sync your journal across devices and enable cloud backup',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: colorScheme.onErrorContainer,
                        ),
                        onPressed: () {
                          setState(() => _errorMessage = null);
                          ref.read(authNotifierProvider.notifier).clearError();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Sign-in buttons
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                // Apple Sign-In (show on iOS, or all platforms for testing)
                if (Platform.isIOS || Platform.isMacOS) ...[
                  _SignInButton(
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    onPressed: _signInWithApple,
                  ),
                  const SizedBox(height: 12),
                ],

                // Google Sign-In
                _SignInButton(
                  icon: Icons.g_mobiledata,
                  iconSize: 32,
                  label: 'Continue with Google',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  borderColor: colorScheme.outline,
                  onPressed: _signInWithGoogle,
                ),

                const SizedBox(height: 12),

                // Microsoft Sign-In
                _SignInButton(
                  icon: Icons.window,
                  label: 'Continue with Microsoft',
                  backgroundColor: const Color(0xFF2F2F2F),
                  foregroundColor: Colors.white,
                  onPressed: _signInWithMicrosoft,
                ),
              ],

              const Spacer(),

              // Skip option
              if (!_isLoading) ...[
                Text(
                  'or',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _skipSignIn,
                  child: const Text('Skip for now (local only)'),
                ),

                const SizedBox(height: 8),

                Text(
                  'You can sign in later to enable sync',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authNotifierProvider.notifier).signInWithApple();

    if (!result.success && mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();

    if (!result.success && mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
    }
  }

  Future<void> _signInWithMicrosoft() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authNotifierProvider.notifier).signInWithMicrosoft();

    if (!result.success && mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
    }
  }

  Future<void> _skipSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authNotifierProvider.notifier).skipSignIn();

    if (!result.success && mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
    }
  }

  Future<void> _completeOnboardingAndNavigate() async {
    await ref.read(authNotifierProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }
}

/// Custom sign-in button matching provider branding.
class _SignInButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  const _SignInButton({
    required this.icon,
    this.iconSize = 24,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: borderColor != null
              ? BorderSide(color: borderColor!)
              : BorderSide.none,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
