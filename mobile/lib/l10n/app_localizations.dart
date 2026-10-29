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

  /// No description provided for @errorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithDetail(String error);

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hey, {name}'**
  String greeting(String name);

  /// No description provided for @greetingNoName.
  ///
  /// In en, this message translates to:
  /// **'Hey there'**
  String get greetingNoName;

  /// No description provided for @whatsNext.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what\'s next.'**
  String get whatsNext;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @myBookings.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get myBookings;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'NEXT UP'**
  String get nextUp;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'In {days} days'**
  String inDays(int days);

  /// No description provided for @loadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingEllipsis;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @jobInvitations.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A barbershop wants to hire you — 1 job invitation waiting.} other{A barbershop wants to hire you — {count} job invitations waiting.}}'**
  String jobInvitations(int count);

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments booked'**
  String get noAppointments;

  /// No description provided for @noAppointmentsHint.
  ///
  /// In en, this message translates to:
  /// **'Find a shop and get in the chair.'**
  String get noAppointmentsHint;

  /// No description provided for @browseBarbershops.
  ///
  /// In en, this message translates to:
  /// **'Browse barbershops'**
  String get browseBarbershops;

  /// No description provided for @closureWithinADay.
  ///
  /// In en, this message translates to:
  /// **'This booking will be cancelled within a day unless the shop renews its subscription.'**
  String get closureWithinADay;

  /// No description provided for @closureBy.
  ///
  /// In en, this message translates to:
  /// **'This shop hasn\'t renewed its subscription. If it doesn\'t by {date}, this booking will be cancelled.'**
  String closureBy(DateTime date);

  /// No description provided for @noBookingsYet.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet.'**
  String get noBookingsYet;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @leaveAReview.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get leaveAReview;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get bookingConfirmed;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookingCancelled;

  /// No description provided for @bookingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingCompleted;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get bookAppointment;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @pickATime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time to continue'**
  String get pickATime;

  /// No description provided for @withBarber.
  ///
  /// In en, this message translates to:
  /// **'with {name}'**
  String withBarber(String name);

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @findingFreeTimes.
  ///
  /// In en, this message translates to:
  /// **'Finding free times…'**
  String get findingFreeTimes;

  /// No description provided for @couldntLoadTimes.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load times'**
  String get couldntLoadTimes;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnection;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @noFreeTimesOn.
  ///
  /// In en, this message translates to:
  /// **'No free times on {day}'**
  String noFreeTimesOn(String day);

  /// No description provided for @shopClosedOrFull.
  ///
  /// In en, this message translates to:
  /// **'The shop is closed or fully booked that day.'**
  String get shopClosedOrFull;

  /// No description provided for @tryDay.
  ///
  /// In en, this message translates to:
  /// **'Try {day}'**
  String tryDay(String day);

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @barber.
  ///
  /// In en, this message translates to:
  /// **'Barber'**
  String get barber;

  /// No description provided for @freeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} free'**
  String freeCount(int count);

  /// No description provided for @anyBarber.
  ///
  /// In en, this message translates to:
  /// **'Any barber'**
  String get anyBarber;

  /// No description provided for @findAShop.
  ///
  /// In en, this message translates to:
  /// **'Find a shop'**
  String get findAShop;

  /// No description provided for @searchBarbershops.
  ///
  /// In en, this message translates to:
  /// **'Search barbershops'**
  String get searchBarbershops;

  /// No description provided for @noBarbershopsYet.
  ///
  /// In en, this message translates to:
  /// **'No barbershops yet'**
  String get noBarbershopsYet;

  /// No description provided for @noBarbershopsHint.
  ///
  /// In en, this message translates to:
  /// **'Check back soon — new shops show up here.'**
  String get noBarbershopsHint;

  /// No description provided for @noMatchesFor.
  ///
  /// In en, this message translates to:
  /// **'No matches for \"{query}\"'**
  String noMatchesFor(String query);

  /// No description provided for @tryDifferentName.
  ///
  /// In en, this message translates to:
  /// **'Try a different name.'**
  String get tryDifferentName;

  /// No description provided for @skipRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this rating?'**
  String get skipRatingTitle;

  /// No description provided for @skipRatingBody.
  ///
  /// In en, this message translates to:
  /// **'Ratings can earn you rewards later on — if you skip this one, you won\'t get anything for it. Skip anyway?'**
  String get skipRatingBody;

  /// No description provided for @skipAnyway.
  ///
  /// In en, this message translates to:
  /// **'Skip anyway'**
  String get skipAnyway;

  /// No description provided for @omit.
  ///
  /// In en, this message translates to:
  /// **'Omit'**
  String get omit;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get submitReview;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @rateTheShop.
  ///
  /// In en, this message translates to:
  /// **'Rate the shop'**
  String get rateTheShop;

  /// No description provided for @rateTheBarber.
  ///
  /// In en, this message translates to:
  /// **'Rate the barber'**
  String get rateTheBarber;

  /// No description provided for @rateTheHaircut.
  ///
  /// In en, this message translates to:
  /// **'Rate the haircut'**
  String get rateTheHaircut;

  /// No description provided for @haircutTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Haircut type'**
  String get haircutTypeLabel;

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @hcBuzzCut.
  ///
  /// In en, this message translates to:
  /// **'Buzz Cut'**
  String get hcBuzzCut;

  /// No description provided for @hcCrewCut.
  ///
  /// In en, this message translates to:
  /// **'Crew Cut'**
  String get hcCrewCut;

  /// No description provided for @hcFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get hcFade;

  /// No description provided for @hcUndercut.
  ///
  /// In en, this message translates to:
  /// **'Undercut'**
  String get hcUndercut;

  /// No description provided for @hcPompadour.
  ///
  /// In en, this message translates to:
  /// **'Pompadour'**
  String get hcPompadour;

  /// No description provided for @hcQuiff.
  ///
  /// In en, this message translates to:
  /// **'Quiff'**
  String get hcQuiff;

  /// No description provided for @hcSlickBack.
  ///
  /// In en, this message translates to:
  /// **'Slick Back'**
  String get hcSlickBack;

  /// No description provided for @hcTexturedCrop.
  ///
  /// In en, this message translates to:
  /// **'Textured Crop'**
  String get hcTexturedCrop;

  /// No description provided for @hcMullet.
  ///
  /// In en, this message translates to:
  /// **'Mullet'**
  String get hcMullet;

  /// No description provided for @hcAfro.
  ///
  /// In en, this message translates to:
  /// **'Afro'**
  String get hcAfro;

  /// No description provided for @hcBaldShaved.
  ///
  /// In en, this message translates to:
  /// **'Bald/Shaved'**
  String get hcBaldShaved;

  /// No description provided for @hcBeardTrim.
  ///
  /// In en, this message translates to:
  /// **'Beard Trim'**
  String get hcBeardTrim;

  /// No description provided for @hcOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get hcOther;

  /// No description provided for @shopHiddenOwner.
  ///
  /// In en, this message translates to:
  /// **'Your shop page is hidden from customers until your subscription is active.'**
  String get shopHiddenOwner;

  /// No description provided for @shopUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This shop isn\'t available right now.'**
  String get shopUnavailable;

  /// No description provided for @editShopPage.
  ///
  /// In en, this message translates to:
  /// **'Edit shop page'**
  String get editShopPage;

  /// No description provided for @newOnTheApp.
  ///
  /// In en, this message translates to:
  /// **'New on the app'**
  String get newOnTheApp;

  /// No description provided for @moreLocations.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreLocations(int count);

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// No description provided for @editPage.
  ///
  /// In en, this message translates to:
  /// **'Edit page'**
  String get editPage;

  /// No description provided for @messageTheShop.
  ///
  /// In en, this message translates to:
  /// **'Message the shop'**
  String get messageTheShop;

  /// No description provided for @barbers.
  ///
  /// In en, this message translates to:
  /// **'Barbers'**
  String get barbers;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @locations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locations;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @closedToday.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get closedToday;

  /// No description provided for @openNowUntil.
  ///
  /// In en, this message translates to:
  /// **'Open now · until {time}'**
  String openNowUntil(String time);

  /// No description provided for @opensAt.
  ///
  /// In en, this message translates to:
  /// **'Opens {time}'**
  String opensAt(String time);

  /// No description provided for @closedNow.
  ///
  /// In en, this message translates to:
  /// **'Closed now'**
  String get closedNow;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @noServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services listed yet.'**
  String get noServicesYet;

  /// No description provided for @noBarbersYet.
  ///
  /// In en, this message translates to:
  /// **'No barbers listed yet.'**
  String get noBarbersYet;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get noReviewsYet;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get noPostsYet;
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
