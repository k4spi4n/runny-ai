import 'package:supabase_flutter/supabase_flutter.dart';

enum RegistrationStatus {
  signedIn,
  confirmationRequired,
  emailAlreadyRegistered,
  invalidEmail,
  disposableEmail,
}

class RegistrationResult {
  final RegistrationStatus status;

  const RegistrationResult(this.status);
}

abstract interface class RegistrationService {
  Future<RegistrationResult> signUp({
    required String email,
    required String password,
  });
}

/// Keeps signup data access out of the page and exposes only the primary
/// password required by Supabase Auth.
class SupabaseRegistrationService implements RegistrationService {
  final SupabaseClient _client;

  SupabaseRegistrationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  @override
  Future<RegistrationResult> signUp({
    required String email,
    required String password,
  }) async {
    final check = await _client.rpc(
      'check_signup_email',
      params: {'p_email': email},
    );
    if (check is Map && check['allowed'] != true) {
      return RegistrationResult(
        check['reason'] == 'disposable'
            ? RegistrationStatus.disposableEmail
            : RegistrationStatus.invalidEmail,
      );
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.session != null) {
      return const RegistrationResult(RegistrationStatus.signedIn);
    }
    if (response.user != null &&
        (response.user!.identities == null ||
            response.user!.identities!.isEmpty)) {
      return const RegistrationResult(
        RegistrationStatus.emailAlreadyRegistered,
      );
    }
    return const RegistrationResult(RegistrationStatus.confirmationRequired);
  }
}
