import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @resendConfirmationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resend — try again shortly.'**
  String get resendConfirmationFailed;

  /// No description provided for @confirmationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent.'**
  String get confirmationEmailSent;

  /// No description provided for @resendConfirmationEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get resendConfirmationEmail;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccountSignUp;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @mustBe14.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 14 to create an account.'**
  String get mustBe14;

  /// No description provided for @dateOfBirthRequired.
  ///
  /// In en, this message translates to:
  /// **'Date of birth is required.'**
  String get dateOfBirthRequired;

  /// No description provided for @confirmAdultOwner.
  ///
  /// In en, this message translates to:
  /// **'Confirm you\'re 18 or over and authorised to register this business.'**
  String get confirmAdultOwner;

  /// No description provided for @mustAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the Terms of Service and Privacy Policy.'**
  String get mustAgreeToTerms;

  /// No description provided for @finishAccountSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up your account'**
  String get finishAccountSetupTitle;

  /// No description provided for @createBusinessAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create business account'**
  String get createBusinessAccountTitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountTitle;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @roleBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get roleBusiness;

  /// No description provided for @businessSignUpStepHint.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2: your login. After confirming your email you\'ll set up your business — locations, opening hours, services and staff.'**
  String get businessSignUpStepHint;

  /// No description provided for @businessNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessNameLabel;

  /// No description provided for @dateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirthLabel;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @minorAccountNotice.
  ///
  /// In en, this message translates to:
  /// **'Under 18 — messaging, posting, and business/worker features aren\'t available on your account.'**
  String get minorAccountNotice;

  /// No description provided for @businessHandleLabel.
  ///
  /// In en, this message translates to:
  /// **'Business handle'**
  String get businessHandleLabel;

  /// No description provided for @businessHandleHelper.
  ///
  /// In en, this message translates to:
  /// **'Must be unique — your @name on posts'**
  String get businessHandleHelper;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @usernameHelper.
  ///
  /// In en, this message translates to:
  /// **'Must be unique — shown on rankings and posts'**
  String get usernameHelper;

  /// No description provided for @atLeast3Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get atLeast3Characters;

  /// No description provided for @atLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get atLeast6Characters;

  /// No description provided for @adultOwnerCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I\'m 18 or over and authorised to register this business'**
  String get adultOwnerCheckbox;

  /// No description provided for @agreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get agreePrefix;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @agreeAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get agreeAnd;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @finishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishButton;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpButton;

  /// No description provided for @useDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get useDifferentAccount;

  /// No description provided for @haveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountSignIn;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a link to reset your password.'**
  String get resetLinkSent;

  /// No description provided for @resetPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you signed up with and we\'ll send you a reset link.'**
  String get resetPasswordIntro;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @setNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get setNewPasswordTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @useTheAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Use the app'**
  String get useTheAppTitle;

  /// No description provided for @websiteIsForShops.
  ///
  /// In en, this message translates to:
  /// **'This website is for barbershops.'**
  String get websiteIsForShops;

  /// No description provided for @useTheAppBody.
  ///
  /// In en, this message translates to:
  /// **'Booking, your rewards and the feed are in the Fadra Cut app — sign in there on your phone with this same account.'**
  String get useTheAppBody;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @yourShopGroup.
  ///
  /// In en, this message translates to:
  /// **'Your shop'**
  String get yourShopGroup;

  /// No description provided for @shopPage.
  ///
  /// In en, this message translates to:
  /// **'Shop page'**
  String get shopPage;

  /// No description provided for @shopPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Logo, cover photo and brand colour'**
  String get shopPageSubtitle;

  /// No description provided for @businessDetails.
  ///
  /// In en, this message translates to:
  /// **'Business details'**
  String get businessDetails;

  /// No description provided for @businessDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Locations and opening hours'**
  String get businessDetailsSubtitle;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @servicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What you offer, prices and durations'**
  String get servicesSubtitle;

  /// No description provided for @subscriptionBilling.
  ///
  /// In en, this message translates to:
  /// **'Subscription & billing'**
  String get subscriptionBilling;

  /// No description provided for @subscriptionBillingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan, free trial, cancel, invoices'**
  String get subscriptionBillingSubtitle;

  /// No description provided for @referredBy.
  ///
  /// In en, this message translates to:
  /// **'Referred by'**
  String get referredBy;

  /// No description provided for @noReferralCodeUsed.
  ///
  /// In en, this message translates to:
  /// **'No referral code was used'**
  String get noReferralCodeUsed;

  /// No description provided for @yourProfileGroup.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get yourProfileGroup;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @workerProfile.
  ///
  /// In en, this message translates to:
  /// **'Worker profile'**
  String get workerProfile;

  /// No description provided for @workerProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Legal name, bio and availability to work at a shop'**
  String get workerProfileSubtitle;

  /// No description provided for @yourReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get yourReferralCode;

  /// No description provided for @referralCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get referralCodeCopied;

  /// No description provided for @accountGroup.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountGroup;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @phoneLanguage.
  ///
  /// In en, this message translates to:
  /// **'Phone language'**
  String get phoneLanguage;

  /// No description provided for @adminEntry.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminEntry;

  /// No description provided for @adminEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard, customers, businesses, payouts'**
  String get adminEntrySubtitle;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes your account and all its data'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and everything tied to it — profile, bookings, reviews, posts, messages. This can\'t be undone.'**
  String get deleteAccountBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @unpaidRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'You have rewards not paid out yet'**
  String get unpaidRewardsTitle;

  /// No description provided for @unpaidRewardsBody.
  ///
  /// In en, this message translates to:
  /// **'You have {amounts} that hasn\'t been paid to you. Cash it out first, or delete your account and give it up — it can\'t be paid after your account is gone.'**
  String unpaidRewardsBody(String amounts);

  /// No description provided for @giveItUp.
  ///
  /// In en, this message translates to:
  /// **'Give it up'**
  String get giveItUp;

  /// No description provided for @cashOut.
  ///
  /// In en, this message translates to:
  /// **'Cash out'**
  String get cashOut;

  /// No description provided for @listAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get listAnd;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @policyUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ve updated our Terms and Privacy Policy'**
  String get policyUpdateTitle;

  /// No description provided for @policyUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'In effect from {date}. Rewards not yet paid out are given up if you delete your account (you\'re offered a cash-out first), and records of rewards already paid to you are kept for 6 years for tax purposes. By continuing to use the app you accept the updated versions.'**
  String policyUpdateBody(DateTime date);

  /// No description provided for @termsShort.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get termsShort;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @forBusiness.
  ///
  /// In en, this message translates to:
  /// **'for Business'**
  String get forBusiness;

  /// No description provided for @webPanelBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings and staff schedules at a glance'**
  String get webPanelBookings;

  /// No description provided for @webPanelFinance.
  ///
  /// In en, this message translates to:
  /// **'Costs, break-even and forecasts on a big screen'**
  String get webPanelFinance;

  /// No description provided for @webPanelShop.
  ///
  /// In en, this message translates to:
  /// **'Your shop page, posts and messages'**
  String get webPanelShop;

  /// No description provided for @webPanelHeadline.
  ///
  /// In en, this message translates to:
  /// **'Run your shop\nfrom any screen.'**
  String get webPanelHeadline;

  /// No description provided for @webPanelSubhead.
  ///
  /// In en, this message translates to:
  /// **'Everything in the app, with room to see it.'**
  String get webPanelSubhead;

  /// No description provided for @webPanelFooter.
  ///
  /// In en, this message translates to:
  /// **'Customers book on the Fadra Cut app.'**
  String get webPanelFooter;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get navBookings;

  /// No description provided for @navStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get navStaff;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get navSubscription;

  /// No description provided for @navBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get navBrowse;

  /// No description provided for @navDesigns.
  ///
  /// In en, this message translates to:
  /// **'Designs'**
  String get navDesigns;

  /// No description provided for @navRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get navRewards;

  /// No description provided for @navRankings.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get navRankings;

  /// No description provided for @barbershopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Barbershop'**
  String get barbershopSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
