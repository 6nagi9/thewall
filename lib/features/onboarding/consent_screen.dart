import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';
import '../legal/legal_screens.dart';

/// DPDP consent + 18+ gate + claim-your-wall. Mandatory, non-skippable.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final _nameCtrl = TextEditingController();
  bool _consent = false;
  bool _age = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed =>
      _consent && _age && _nameCtrl.text.trim().isNotEmpty && !_saving;

  Future<void> _claim() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      await ref.read(repoProvider).completeOnboarding(
            displayName: _nameCtrl.text.trim(),
            phoneNumber: phone,
          );
      // Router redirects to home once the user doc shows onboarded.
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const ScreenHeader(
              kicker: 'One last thing',
              title: 'Claim your wall',
            ),
            Text(
              'Known only works because everyone agrees to the same rules. '
              'Here\'s exactly what we do with your data:',
              style: AppTheme.body(
                  size: 14, color: AppTheme.ink300, height: 1.55),
            ).entrance(++i),
            const SizedBox(height: 20),
            _ConsentPoint(
              icon: Icons.lock_outline,
              title: 'Minimal data',
              text:
                  'Your phone number and the structured feedback you give and receive. Nothing else.',
            ).entrance(++i),
            _ConsentPoint(
              icon: Icons.visibility_off_outlined,
              title: 'You control disclosure',
              text:
                  'Feedback others write stays private until YOU choose to make it public.',
            ).entrance(++i),
            _ConsentPoint(
              icon: Icons.contacts_outlined,
              title: 'Contacts never leave your device',
              text:
                  'They\'re hashed on-device — we never store your raw address book.',
            ).entrance(++i),
            _ConsentPoint(
              icon: Icons.delete_outline,
              title: 'Leave anytime',
              text:
                  'Export or permanently delete all your data from Settings.',
            ).entrance(++i),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your display name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ).entrance(++i),
            const SizedBox(height: 12),
            WallCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _age,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _age = v ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('I confirm I am 18 years or older.',
                        style: AppTheme.body(
                            size: 14, color: AppTheme.ink100)),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _consent = v ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'I consent to Known processing my data for the purposes described above (DPDP Act, 2023).',
                      style: AppTheme.body(
                          size: 14, color: AppTheme.ink100, height: 1.4),
                    ),
                  ),
                ],
              ),
            ).entrance(++i),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Read our ',
                    style: AppTheme.body(
                        size: 13, color: AppTheme.ink400)),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen())),
                  child: Text('Privacy Policy',
                      style: AppTheme.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppTheme.clay)),
                ),
                Text(' and ',
                    style: AppTheme.body(
                        size: 13, color: AppTheme.ink400)),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermsScreen())),
                  child: Text('Terms of Use',
                      style: AppTheme.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppTheme.clay)),
                ),
              ],
            ).entrance(++i),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: AppTheme.body(size: 13, color: AppTheme.rose)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _canProceed ? _claim : null,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.ink950))
                  : const Text('Claim my wall'),
            ).entrance(++i),
          ],
        ),
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _ConsentPoint({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.clay.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.clay, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppTheme.paper)),
                  const SizedBox(height: 2),
                  Text(text,
                      style: AppTheme.body(
                          size: 13,
                          color: AppTheme.ink300,
                          height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}
