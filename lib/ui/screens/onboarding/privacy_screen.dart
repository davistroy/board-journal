import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Privacy screen - terms and privacy acceptance.
///
/// Per PRD Section 5.0:
/// - Terms of Service link
/// - Privacy Policy link
/// - Required checkbox: "I accept the Terms of Service and Privacy Policy"
/// - Flow: Welcome -> Privacy -> OAuth -> First Entry (Home)
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _acceptedTerms = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.onboardingWelcome),
        ),
        title: const Text('Privacy & Terms'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Privacy Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Your Privacy Matters',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Before you start journaling, please review our terms and privacy policy. '
                'We take your privacy seriously and want you to understand how we protect your data.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Terms of Service Link
              _PolicyLink(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                description: 'Rules for using Boardroom Journal',
                onTap: () => _showPolicyDialog(
                  context,
                  'Terms of Service',
                  _termsOfServiceText,
                ),
              ),

              const SizedBox(height: 16),

              // Privacy Policy Link
              _PolicyLink(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                description: 'How we collect, use, and protect your data',
                onTap: () => _showPolicyDialog(
                  context,
                  'Privacy Policy',
                  _privacyPolicyText,
                ),
              ),

              const Spacer(),

              // Acceptance Checkbox
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: (value) {
                  setState(() {
                    _acceptedTerms = value ?? false;
                  });
                },
                title: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'I accept the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showPolicyDialog(
                                context,
                                'Terms of Service',
                                _termsOfServiceText,
                              ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showPolicyDialog(
                                context,
                                'Privacy Policy',
                                _privacyPolicyText,
                              ),
                      ),
                    ],
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _acceptedTerms
                      ? () => context.go(AppRoutes.onboardingSignin)
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Continue'),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A policy link item.
class _PolicyLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PolicyLink({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

// Placeholder policy texts - these would be replaced with actual legal text
const String _termsOfServiceText = '''
TERMS OF SERVICE

Last updated: January 2025

1. ACCEPTANCE OF TERMS
By accessing or using Boardroom Journal, you agree to be bound by these Terms of Service.

2. DESCRIPTION OF SERVICE
Boardroom Journal is a voice-first career journaling application that provides AI-powered governance features.

3. USER RESPONSIBILITIES
You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account.

4. INTELLECTUAL PROPERTY
The Service and its original content, features, and functionality are owned by Boardroom Journal and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.

5. TERMINATION
We may terminate or suspend your account and bar access to the Service immediately, without prior notice or liability, for any reason.

6. LIMITATION OF LIABILITY
In no event shall Boardroom Journal be liable for any indirect, incidental, special, consequential, or punitive damages.

7. GOVERNING LAW
These Terms shall be governed by the laws of the jurisdiction in which the company is registered.

8. CHANGES TO TERMS
We reserve the right to modify or replace these Terms at any time at our sole discretion.

For questions about these Terms, please contact us at support@boardroomjournal.com.
''';

const String _privacyPolicyText = '''
PRIVACY POLICY

Last updated: January 2025

1. INFORMATION WE COLLECT
- Voice recordings and transcriptions of your journal entries
- Account information (email, name) from OAuth providers
- Usage data and analytics

2. HOW WE USE YOUR INFORMATION
- To provide and maintain the Service
- To generate AI-powered briefs and governance insights
- To improve our Service

3. DATA STORAGE
- Your data is stored securely using industry-standard encryption
- Local data is stored on your device using secure storage
- Cloud data is stored on encrypted servers

4. DATA SHARING
We do not sell your personal information. We may share data with:
- AI service providers (for processing entries and generating insights)
- Cloud storage providers (for secure data backup)

5. YOUR RIGHTS
You have the right to:
- Access your personal data
- Request deletion of your data
- Export your data

6. DATA RETENTION
We retain your data for as long as your account is active or as needed to provide you services.

7. SECURITY
We implement appropriate security measures to protect against unauthorized access, alteration, disclosure, or destruction of your data.

8. CHILDREN'S PRIVACY
Our Service is not intended for use by children under the age of 13.

9. CHANGES TO THIS POLICY
We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.

For questions about this Privacy Policy, please contact us at privacy@boardroomjournal.com.
''';
