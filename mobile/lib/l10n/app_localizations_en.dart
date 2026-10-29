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

  @override
  String get settingsTitle => 'Settings';

  @override
  String get yourShopGroup => 'Your shop';

  @override
  String get shopPage => 'Shop page';

  @override
  String get shopPageSubtitle => 'Logo, cover photo and brand colour';

  @override
  String get businessDetails => 'Business details';

  @override
  String get businessDetailsSubtitle => 'Locations and opening hours';

  @override
  String get services => 'Services';

  @override
  String get servicesSubtitle => 'What you offer, prices and durations';

  @override
  String get subscriptionBilling => 'Subscription & billing';

  @override
  String get subscriptionBillingSubtitle =>
      'Your plan, free trial, cancel, invoices';

  @override
  String get referredBy => 'Referred by';

  @override
  String get noReferralCodeUsed => 'No referral code was used';

  @override
  String get yourProfileGroup => 'Your profile';

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get workerProfile => 'Worker profile';

  @override
  String get workerProfileSubtitle =>
      'Legal name, bio and availability to work at a shop';

  @override
  String get yourReferralCode => 'Your referral code';

  @override
  String get referralCodeCopied => 'Referral code copied';

  @override
  String get accountGroup => 'Account';

  @override
  String get language => 'Language';

  @override
  String get phoneLanguage => 'Phone language';

  @override
  String get adminEntry => 'Admin';

  @override
  String get adminEntrySubtitle => 'Dashboard, customers, businesses, payouts';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle =>
      'Permanently deletes your account and all its data';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'This permanently deletes your account and everything tied to it — profile, bookings, reviews, posts, messages. This can\'t be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get unpaidRewardsTitle => 'You have rewards not paid out yet';

  @override
  String unpaidRewardsBody(String amounts) {
    return 'You have $amounts that hasn\'t been paid to you. Cash it out first, or delete your account and give it up — it can\'t be paid after your account is gone.';
  }

  @override
  String get giveItUp => 'Give it up';

  @override
  String get cashOut => 'Cash out';

  @override
  String get listAnd => ' and ';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get save => 'Save';

  @override
  String get policyUpdateTitle => 'We\'ve updated our Terms and Privacy Policy';

  @override
  String policyUpdateBody(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'In effect from $dateString. Rewards not yet paid out are given up if you delete your account (you\'re offered a cash-out first), and records of rewards already paid to you are kept for 6 years for tax purposes. By continuing to use the app you accept the updated versions.';
  }

  @override
  String get termsShort => 'Terms';

  @override
  String get ok => 'OK';

  @override
  String get forBusiness => 'for Business';

  @override
  String get webPanelBookings => 'Bookings and staff schedules at a glance';

  @override
  String get webPanelFinance =>
      'Costs, break-even and forecasts on a big screen';

  @override
  String get webPanelShop => 'Your shop page, posts and messages';

  @override
  String get webPanelHeadline => 'Run your shop\nfrom any screen.';

  @override
  String get webPanelSubhead => 'Everything in the app, with room to see it.';

  @override
  String get webPanelFooter => 'Customers book on the Fadra Cut app.';

  @override
  String get navHome => 'Home';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navStaff => 'Staff';

  @override
  String get navFinance => 'Finance';

  @override
  String get navFeed => 'Feed';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSubscription => 'Subscription';

  @override
  String get navBrowse => 'Browse';

  @override
  String get navDesigns => 'Designs';

  @override
  String get navRewards => 'Rewards';

  @override
  String get navRankings => 'Rankings';

  @override
  String get barbershopSubtitle => 'Barbershop';
}
