import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';

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
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim your Wall')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Before we begin',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const _ConsentPoint(
            icon: Icons.lock_outline,
            text: 'We collect your phone number and the structured feedback '
                'you give and receive. Nothing else.',
          ),
          const _ConsentPoint(
            icon: Icons.visibility_off_outlined,
            text: 'You control your Wall. Feedback others write stays private '
                'until YOU choose to make it public.',
          ),
          const _ConsentPoint(
            icon: Icons.contacts_outlined,
            text: 'Contacts are hashed on your device — we never store your '
                'raw address book.',
          ),
          const _ConsentPoint(
            icon: Icons.delete_outline,
            text: 'You can export or permanently delete all your data at any '
                'time from Settings.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Your display name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _age,
            onChanged: (v) => setState(() => _age = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I confirm I am 18 years or older.'),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
                'I consent to The Wall processing my data for the purposes '
                'described above (DPDP Act, 2023).'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.rose)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _canProceed ? _claim : null,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.slate900))
                : const Text('Claim my Wall'),
          ),
        ],
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ConsentPoint({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.teal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppTheme.slate300, height: 1.4)),
            ),
          ],
        ),
      );
}
