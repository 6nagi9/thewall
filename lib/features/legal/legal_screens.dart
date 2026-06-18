import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../shared/wall_ui.dart';

/// Effective date shown on the legal documents. Update when policy changes.
const String _kEffectiveDate = '10 June 2026';

/// A section of a legal document: a heading plus one or more paragraphs.
class _Section {
  final String heading;
  final List<String> paragraphs;
  const _Section(this.heading, this.paragraphs);
}

/// Shared scrollable layout for legal documents.
class _LegalScaffold extends StatelessWidget {
  final String title;
  final String intro;
  final List<_Section> sections;
  const _LegalScaffold({
    required this.title,
    required this.intro,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.clay.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('Effective $_kEffectiveDate',
                style: AppTheme.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.clay)),
          ).entrance(0),
          const SizedBox(height: 16),
          Text(intro,
                  style: AppTheme.body(
                      size: 14.5, color: AppTheme.ink200, height: 1.6))
              .entrance(1),
          const SizedBox(height: 8),
          ...sections.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.value.heading,
                        style: AppTheme.display(size: 17)),
                    const SizedBox(height: 8),
                    ...entry.value.paragraphs.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(p,
                              style: AppTheme.body(
                                  size: 13.5,
                                  color: AppTheme.ink300,
                                  height: 1.6)),
                        )),
                  ],
                ).entrance((entry.key + 2).clamp(0, 8)),
              )),
          const SizedBox(height: 32),
          Text('Grievance Officer: grievance@thewall.app · 7-day response',
              style: AppTheme.body(size: 12, color: AppTheme.ink400)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Privacy Policy',
      intro:
          'Known is built consent-first. We process your personal data only '
          'with your consent, and our practices are designed to meet the major '
          'global privacy regimes — the EU/UK GDPR, the California CCPA/CPRA, '
          'and India\'s Digital Personal Data Protection Act, 2023 (DPDP). '
          'This policy explains what we collect, why, and the rights you have '
          'wherever you live.',
      sections: [
        _Section('1. What we collect', [
          '• Your phone number — to authenticate you and to derive a hashed '
              'identity for matching feedback.',
          '• Your display name and the structured feedback you give and '
              'receive (ratings, tags, optional comments).',
          '• A device push token, to notify you about new feedback.',
          '• Basic, pseudonymised usage analytics and crash diagnostics to '
              'improve the app — collected only after you consent, and '
              'switchable off anytime in Settings.',
        ]),
        _Section('2. What we never collect', [
          'We do not store your raw address book. Contacts are hashed on your '
              'device, and we never create a profile for someone who has not '
              'joined and consented. No wall exists for a non-member.',
        ]),
        _Section('3. Legal basis', [
          'We rely on your explicit, withdrawable consent, captured at sign-up '
              '(GDPR Art. 6(1)(a) and 7; DPDP s. 6; and your right to opt out '
              'under the CCPA/CPRA). You may withdraw consent at any time by '
              'deleting your account. We never sell or share your personal '
              'information for cross-context behavioural advertising.',
        ]),
        _Section('4. How feedback visibility works', [
          'Feedback others give you stays private until you choose to make it '
              'public on your Wall. A reviewer may appear "anonymous" to other '
              'users; however, we retain a recoverable identity mapping so we '
              'can comply with lawful requests from competent authorities '
              '(including, in India, under the IT Act). Anonymous never means '
              'anonymous to law enforcement.',
        ]),
        _Section('5. Where your data is stored & international transfers', [
          'Your data is hosted on Google Cloud, encrypted in transit and at '
              'rest, currently in the Mumbai (asia-south1) region. If you use '
              'Known from outside India, your data is transferred to and '
              'processed in India under appropriate safeguards — including '
              'Standard Contractual Clauses for EU/UK users.',
        ]),
        _Section('6. Retention', [
          'Feedback drafted for someone who has not yet joined is encrypted in '
              'escrow and auto-deleted after 30 days if they do not join. When '
              'you delete your account, your profile, your Wall, and feedback '
              'about you are permanently erased.',
        ]),
        _Section('7. Your rights', [
          'Wherever you live, you may access and export your data, request '
              'correction, withdraw consent, and erase your account — all from '
              'Settings. Depending on your jurisdiction you may also have the '
              'right to object to or restrict processing, to data portability '
              '(GDPR), and to opt out of any "sale" or "sharing" and to '
              'non-discrimination (CCPA/CPRA). Indian users have all rights '
              'under the DPDP Act 2023, including grievance redressal via our '
              'Grievance Officer.',
        ]),
        _Section('8. Age', [
          'Known is for users aged 18 and above only.',
        ]),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'Terms of Use',
      intro:
          'By using Known you agree to these terms. Known is a space for '
          'honest, constructive, consent-based interpersonal feedback.',
      sections: [
        _Section('1. Eligibility', [
          'You must be at least 18 years old to use Known.',
        ]),
        _Section('2. Acceptable use', [
          'Give feedback only to people in your contacts or mutual connections '
              '— never strangers. Feedback must be constructive and truthful. '
              'Harassment, hate speech, slurs, threats, and defamatory content '
              'are prohibited and are blocked by automated moderation.',
        ]),
        _Section('3. Moderation and safety', [
          'Comments pass through two-layer moderation. You can block users, '
              'report content, and dispute feedback about you. We may remove '
              'content or suspend accounts that violate these terms.',
        ]),
        _Section('4. Your content and anonymity', [
          'You may edit or delete feedback you have given at any time. Feedback '
              'you receive is yours to disclose or keep private. Reviewer '
              'anonymity is anonymity to other users only, not to lawful '
              'authorities.',
        ]),
        _Section('5. Premium subscriptions', [
          'Premium features are billed through the App Store or Google Play. '
              'Purchases are verified server-side. Manage or cancel your '
              'subscription through your store account.',
        ]),
        _Section('6. Disclaimer and liability', [
          'Feedback reflects the subjective opinions of individual reviewers, '
              'not statements of fact by Known. To the extent permitted by '
              'law, Known is not liable for user-generated content.',
        ]),
        _Section('7. Governing law', [
          'These terms are governed by the laws of India, and disputes are '
              'subject to the jurisdiction of the courts of India. Nothing here '
              'removes any mandatory consumer-protection or data-protection '
              'rights you have under the laws of your country of residence — '
              'those rights continue to apply to you regardless of this clause.',
        ]),
      ],
    );
  }
}
