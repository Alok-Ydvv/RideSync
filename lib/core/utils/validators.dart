/// Phase 1 input validators (EN/HI-ready messages kept short for glanceability).
String? validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Phone required';
  final d = v.replaceAll(RegExp(r'\D'), '');
  // India: 10 digits, optional +91/91 prefix.
  final normalized = d.startsWith('91') && d.length == 12 ? d.substring(2) : d;
  if (normalized.length != 10) return 'Enter 10-digit mobile number';
  return null;
}

String? validateOtp(String? v) {
  if (v == null || v.trim().isEmpty) return 'OTP required';
  if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'Enter 6-digit OTP';
  return null;
}

String? validateName(String? v) {
  if (v == null || v.trim().isEmpty) return 'Name required';
  if (v.trim().length < 2) return 'Enter full name';
  return null;
}

String? validateEmail(String? v) {
  if (v == null || v.isEmpty) return null; // optional in phone-first flow
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter valid email';
  return null;
}
