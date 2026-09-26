import '../../../core/api_client.dart';

class SignUpConflictException implements Exception {
  const SignUpConflictException({required this.emailTaken, required this.usernameTaken});

  final bool emailTaken;
  final bool usernameTaken;

  @override
  String toString() => [
        if (emailTaken)
          'An account with this email already exists — sign in, or use "Continue with Google" if '
              'that\'s how you signed up.',
        if (usernameTaken) 'That username is already taken.',
      ].join('\n');
}

class AccountApiClient {
  AccountApiClient(this._api);

  final ApiClient _api;

  /// Throws [ApiException] with a 409 if the backend blocks deletion (an
  /// active subscription or upcoming bookings for a business account) — see
  /// backend/app/api/account.py.
  Future<void> deleteAccount() async {
    await _api.delete('/account');
  }

  /// Throws [SignUpConflictException] if the email or username is already
  /// in use — checked server-side because the `profiles` read policy hides
  /// every row from a signed-out caller, and pending (unconfirmed) signups
  /// only exist in auth.users, which the app can't query at all.
  Future<void> ensureSignUpAvailable({required String email, required String username}) async {
    final result = await _api.post('/account/signup-availability', body: {'email': email, 'username': username})
        as Map<String, dynamic>;
    final emailTaken = result['email_available'] != true;
    final usernameTaken = result['username_available'] != true;
    if (emailTaken || usernameTaken) {
      throw SignUpConflictException(emailTaken: emailTaken, usernameTaken: usernameTaken);
    }
  }
}
