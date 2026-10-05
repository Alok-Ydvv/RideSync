import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../../core/utils/validators.dart';

/// 6-digit OTP verify. On success AuthGate auto-routes (profile or home).
class OtpScreen extends ConsumerStatefulWidget {
  final String phoneDigits;
  const OtpScreen({super.key, required this.phoneDigits});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (validateOtp(_otp.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validateOtp(_otp.text)!)),
      );
      return;
    }
    ref.read(authLoadingProvider.notifier).state = true;
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyPhoneOtp(widget.phoneDigits, _otp.text);
      if (!mounted) return;
      // Pop back to AuthGate; it will route to ProfileSetup/Home.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Verify failed: $e')));
      }
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authLoadingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Code sent to +91 ${widget.phoneDigits}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '6-digit OTP',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : _verify,
              child: Text(loading ? 'Verifying…' : 'Verify & continue'),
            ),
          ],
        ),
      ),
    );
  }
}
