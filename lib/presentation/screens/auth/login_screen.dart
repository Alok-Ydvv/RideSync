import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../../core/utils/validators.dart';
import 'otp_screen.dart';

/// Phase 1 login: phone OTP (primary) + email/password + Google/Apple.
/// 60s OTP resend throttle keeps SMS spend near zero in dev.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _startThrottle() {
    setState(() => _resendIn = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (validatePhone(_phone.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validatePhone(_phone.text)!)),
      );
      return;
    }
    ref.read(authLoadingProvider.notifier).state = true;
    try {
      await ref.read(authRepositoryProvider).sendPhoneOtp(_phone.text);
      _startThrottle();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(phoneDigits: _phone.text)),
      );
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final isProviderMissing = raw.contains('provider') ||
            raw.contains('Unsupported') ||
            raw.contains(' not configured') ||
            raw.contains(' 400');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(isProviderMissing
                ? 'Phone OTP needs an SMS provider configured in Supabase Auth (MSG91/Gupshup DLT). The free email login above works instantly.'
                : 'OTP failed: $raw'),
          ),
        );
      }
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _emailAuth(bool signup) async {
    if ((_formKey.currentState?.validate() ?? false) == false) return;
    ref.read(authLoadingProvider.notifier).state = true;
    try {
      if (signup) {
        final res = await ref
            .read(authRepositoryProvider)
            .signUpEmail(_email.text, _pass.text);
        // Confirm-email ON → no session yet: tell the user to check inbox
        // instead of silently staying on Login.
        if (res.session == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Account created — check your email to confirm, then sign in. (Dev tip: turn OFF “Confirm email” in Supabase Auth settings.)')),
          );
        }
      } else {
        await ref
            .read(authRepositoryProvider)
            .signInEmail(_email.text, _pass.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Email auth failed: $e')));
      }
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _oauth(OAuthProvider p, String label) async {
    try {
      final launched = await ref.read(authRepositoryProvider).signInOAuth(p);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label not configured yet (dashboard → Auth → Providers).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authLoadingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('RideSync — Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0xFF16A34A),
                      child: Icon(Icons.two_wheeler, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 10),
                    Text('RideSync',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text('Ride safe. Ride together.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Email + password',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    hintText: 'you@example.com', border: OutlineInputBorder()),
                validator: validateEmail,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                    hintText: 'Password (6+ chars)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => _emailAuth(false),
                      child: const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => _emailAuth(true),
                      child: const Text('Sign up'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text('Phone login (OTP)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Needs an SMS provider in Supabase (MSG91/Gupshup DLT ≈ ₹0.50/SMS). Email login above is free & instant.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixText: '+91 ',
                  hintText: '10-digit mobile number',
                  border: OutlineInputBorder(),
                ),
                validator: validatePhone,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (loading || _resendIn > 0) ? null : _sendOtp,
                child: Text(loading
                    ? 'Sending…'
                    : _resendIn > 0
                        ? 'Resend in $_resendIn s'
                        : 'Send OTP'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              FilledButton.tonal(
                onPressed: () => _oauth(OAuthProvider.google, 'Google'),
                child: const Text('Continue with Google'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => _oauth(OAuthProvider.apple, 'Apple'),
                child: const Text('Continue with Apple (iOS)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
