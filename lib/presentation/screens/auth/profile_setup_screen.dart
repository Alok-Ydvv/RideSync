import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/validators.dart';

/// First-login profile setup (spec): full name required, vehicle pref,
/// blood group + license optional, emergency contacts 1-3 required.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ContactDraft {
  final name = TextEditingController();
  final phone = TextEditingController();
  String relationship = 'Family';
  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _license = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _vehicle = 'bike';
  String? _blood;
  final _contacts = <_ContactDraft>[_ContactDraft()];
  bool _saving = false;

  static const bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _license.dispose();
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if ((_formKey.currentState?.validate() ?? false) == false) return;
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 1 emergency contact.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final uid = repo.session?.user.id;
      if (uid == null) throw Exception('No session. Log in again.');
      final sessionPhone = repo.session?.user.phone;

      await repo.upsertProfile(UserModel(
        id: uid,
        phone: sessionPhone,
        email: _email.text.isEmpty ? null : _email.text.trim(),
        fullName: _name.text.trim(),
        defaultVehicleType: _vehicle,
        bloodGroup: _blood,
        licenseNumber: _license.text.isEmpty ? null : _license.text.trim(),
      ));
      await repo.saveEmergencyContacts([
        for (var i = 0; i < _contacts.length; i++)
          EmergencyContactModel(
            userId: uid,
            name: _contacts[i].name.text.trim(),
            phone: _contacts[i].phone.text.trim(),
            relationship: _contacts[i].relationship,
            priority: i + 1,
          ),
      ]);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Full name *', border: OutlineInputBorder()),
                validator: validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder()),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _vehicle,
                decoration: const InputDecoration(
                    labelText: 'Default vehicle', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'bike', child: Text('🏍️ Bike')),
                  DropdownMenuItem(value: 'car', child: Text('🚗 Car')),
                ],
                onChanged: (v) => setState(() => _vehicle = v ?? 'bike'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _blood,
                      decoration: const InputDecoration(
                          labelText: 'Blood group (optional)',
                          border: OutlineInputBorder()),
                      items: [
                        for (final b in bloodGroups)
                          DropdownMenuItem(value: b, child: Text(b)),
                      ],
                      onChanged: (v) => setState(() => _blood = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _license,
                      decoration: const InputDecoration(
                          labelText: 'License (optional)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Emergency contacts (1-3) *',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  if (_contacts.length < 3)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _contacts.add(_ContactDraft())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                ],
              ),
              for (var i = 0; i < _contacts.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Contact ${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (_contacts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() {
                                  _contacts[i].dispose();
                                  _contacts.removeAt(i);
                                }),
                              ),
                          ],
                        ),
                        TextFormField(
                          controller: _contacts[i].name,
                          decoration: const InputDecoration(labelText: 'Name *'),
                          validator: validateName,
                        ),
                        TextFormField(
                          controller: _contacts[i].phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: 'Phone *'),
                          validator: validatePhone,
                        ),
                        DropdownButtonFormField<String>(
                          value: _contacts[i].relationship,
                          decoration: const InputDecoration(
                              labelText: 'Relationship'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Family', child: Text('Family')),
                            DropdownMenuItem(
                                value: 'Friend', child: Text('Friend')),
                            DropdownMenuItem(
                                value: 'Spouse', child: Text('Spouse')),
                            DropdownMenuItem(
                                value: 'Parent', child: Text('Parent')),
                            DropdownMenuItem(
                                value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() =>
                              _contacts[i].relationship = v ?? 'Family'),
                        ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save & continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
