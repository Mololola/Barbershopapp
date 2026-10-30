import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/account_api_client.dart';
import '../features/auth/data/profile_repository.dart';
import '../features/business/data/business_repository.dart';
import '../features/worker/data/worker_repository.dart';
import '../l10n/app_localizations.dart';
import 'api_client.dart';

/// What to tell the user about [error], in the app's language. The backend's
/// own messages ([ApiException]) arrive already translated: the API client
/// sends the app's language. Anything unrecognised gets a general message
/// rather than raw technical text.
String describeError(AppLocalizations l10n, Object? error) {
  return switch (error) {
    ApiException(:final message) => message,
    AuthRetryableFetchException() || http.ClientException() => l10n.checkConnection,
    AuthException(:final code) => _authMessage(l10n, code),
    SignUpConflictException(:final emailTaken, :final usernameTaken) => [
        if (emailTaken) l10n.emailAlreadyRegistered,
        if (usernameTaken) l10n.usernameTaken,
      ].join('\n'),
    UsernameTakenException() => l10n.usernameTaken,
    InvalidReferralCodeException() => l10n.referralCodeNotFound,
    AlreadyInvitedException() => l10n.alreadyInvited,
    StaffChangeBlockedException(:final code) =>
      code == 'BB002' ? l10n.alreadyOnYourStaff : l10n.staffHasUpcomingBookings,
    AlreadyStaffElsewhereException() => l10n.alreadyStaffElsewhere,
    _ => l10n.somethingWentWrong,
  };
}

String _authMessage(AppLocalizations l10n, String? code) => switch (code) {
      'invalid_credentials' => l10n.authInvalidCredentials,
      'email_not_confirmed' => l10n.authEmailNotConfirmed,
      'user_already_exists' || 'email_exists' => l10n.emailAlreadyRegistered,
      'weak_password' => l10n.authWeakPassword,
      'same_password' => l10n.authSamePassword,
      'email_address_invalid' || 'validation_failed' => l10n.invalidEmail,
      'over_email_send_rate_limit' || 'over_request_rate_limit' => l10n.authRateLimited,
      'otp_expired' => l10n.authLinkExpired,
      _ => l10n.somethingWentWrong,
    };
