// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signInTitle => 'Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get resendConfirmationFailed =>
      'Couldn\'t resend — try again shortly.';

  @override
  String get confirmationEmailSent => 'Confirmation email sent.';

  @override
  String get resendConfirmationEmail => 'Resend confirmation email';

  @override
  String get noAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get orDivider => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get mustBe14 => 'You must be at least 14 to create an account.';

  @override
  String get dateOfBirthRequired => 'Date of birth is required.';

  @override
  String get confirmAdultOwner =>
      'Confirm you\'re 18 or over and authorised to register this business.';

  @override
  String get mustAgreeToTerms =>
      'You must agree to the Terms of Service and Privacy Policy.';

  @override
  String get finishAccountSetupTitle => 'Finish setting up your account';

  @override
  String get createBusinessAccountTitle => 'Create business account';

  @override
  String get createAccountTitle => 'Create account';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get roleBusiness => 'Business';

  @override
  String get businessSignUpStepHint =>
      'Step 1 of 2: your login. After confirming your email you\'ll set up your business — locations, opening hours, services and staff.';

  @override
  String get businessNameLabel => 'Business name';

  @override
  String get dateOfBirthLabel => 'Date of birth';

  @override
  String get selectDate => 'Select date';

  @override
  String get minorAccountNotice =>
      'Under 18 — messaging, posting, and business/worker features aren\'t available on your account.';

  @override
  String get businessHandleLabel => 'Business handle';

  @override
  String get businessHandleHelper => 'Must be unique — your @name on posts';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHelper => 'Must be unique — shown on rankings and posts';

  @override
  String get atLeast3Characters => 'At least 3 characters';

  @override
  String get atLeast6Characters => 'At least 6 characters';

  @override
  String get adultOwnerCheckbox =>
      'I\'m 18 or over and authorised to register this business';

  @override
  String get agreePrefix => 'I agree to the ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get agreeAnd => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get finishButton => 'Finish';

  @override
  String get signUpButton => 'Sign up';

  @override
  String get useDifferentAccount => 'Use a different account';

  @override
  String get haveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetLinkSent =>
      'Check your email for a link to reset your password.';

  @override
  String get resetPasswordIntro =>
      'Enter the email you signed up with and we\'ll send you a reset link.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get setNewPasswordTitle => 'Set a new password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get updatePassword => 'Update password';

  @override
  String get useTheAppTitle => 'Use the app';

  @override
  String get websiteIsForShops => 'This website is for barbershops.';

  @override
  String get useTheAppBody =>
      'Booking, your rewards and the feed are in the Fadra Cut app — sign in there on your phone with this same account.';

  @override
  String get signOut => 'Sign out';
}
