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

  /// No description provided for @reviewPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your cut?'**
  String get reviewPromptTitle;

  /// No description provided for @reviewPromptReward.
  ///
  /// In en, this message translates to:
  /// **'Leave a review to earn a reward.'**
  String get reviewPromptReward;

  /// No description provided for @reviewPromptPlain.
  ///
  /// In en, this message translates to:
  /// **'Leave a review to help others find a good barber. It only takes a minute.'**
  String get reviewPromptPlain;

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

  /// No description provided for @cancelSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel your subscription?'**
  String get cancelSubTitle;

  /// No description provided for @cancelSubBodyTrial.
  ///
  /// In en, this message translates to:
  /// **'Your free trial still runs until {date} and won\'t be charged again. After that your shop is hidden from customers until you subscribe again.'**
  String cancelSubBodyTrial(String date);

  /// No description provided for @cancelSubBodyPaid.
  ///
  /// In en, this message translates to:
  /// **'You keep full access until the end of the month you\'ve paid for and won\'t be charged again. After that your shop is hidden from customers until you subscribe again.'**
  String get cancelSubBodyPaid;

  /// No description provided for @cancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get cancelSubscription;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @subscriptionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled'**
  String get subscriptionCancelled;

  /// No description provided for @planWithPrice.
  ///
  /// In en, this message translates to:
  /// **'your subscription ({price} / month)'**
  String planWithPrice(String price);

  /// No description provided for @planNoPrice.
  ///
  /// In en, this message translates to:
  /// **'your subscription'**
  String get planNoPrice;

  /// No description provided for @resubTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe again?'**
  String get resubTitle;

  /// No description provided for @resubBodyTrial.
  ///
  /// In en, this message translates to:
  /// **'Your free trial continues until {date}. After that, {plan} is charged to the card you already added.'**
  String resubBodyTrial(String date, String plan);

  /// No description provided for @resubBodyPaid.
  ///
  /// In en, this message translates to:
  /// **'We\'ll keep charging {plan} to the card you already added. Nothing extra is charged today.'**
  String resubBodyPaid(String plan);

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @subscribedAgain.
  ///
  /// In en, this message translates to:
  /// **'You\'re subscribed again'**
  String get subscribedAgain;

  /// No description provided for @cancelFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Finance Premium?'**
  String get cancelFinanceTitle;

  /// No description provided for @cancelFinanceBody.
  ///
  /// In en, this message translates to:
  /// **'You keep Premium insights until the end of the month you\'ve paid for and won\'t be charged again. The free finance summary stays.'**
  String get cancelFinanceBody;

  /// No description provided for @cancelPremium.
  ///
  /// In en, this message translates to:
  /// **'Cancel Premium'**
  String get cancelPremium;

  /// No description provided for @financeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Finance Premium cancelled'**
  String get financeCancelled;

  /// No description provided for @resubFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to Finance Premium again?'**
  String get resubFinanceTitle;

  /// No description provided for @resubFinanceBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll keep charging {what} to the card you already added. Nothing extra is charged today.'**
  String resubFinanceBody(String what);

  /// No description provided for @itPronoun.
  ///
  /// In en, this message translates to:
  /// **'it'**
  String get itPronoun;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String perMonth(String price);

  /// No description provided for @financeSubscribedAgain.
  ///
  /// In en, this message translates to:
  /// **'You\'re subscribed to Finance Premium again'**
  String get financeSubscribedAgain;

  /// No description provided for @subscribeAgain.
  ///
  /// In en, this message translates to:
  /// **'Subscribe again'**
  String get subscribeAgain;

  /// No description provided for @freeAccess.
  ///
  /// In en, this message translates to:
  /// **'Your shop has free access — there\'s nothing to pay.'**
  String get freeAccess;

  /// No description provided for @shopSubscription.
  ///
  /// In en, this message translates to:
  /// **'Shop subscription'**
  String get shopSubscription;

  /// No description provided for @badgeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get badgeCancelled;

  /// No description provided for @badgeFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get badgeFreeTrial;

  /// No description provided for @badgeActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get badgeActive;

  /// No description provided for @endsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String endsOn(String date);

  /// No description provided for @shopCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Your shop stays visible to customers until then and you won\'t be charged again. After that it\'s hidden until you subscribe again, and its data is kept for 60 days.'**
  String get shopCancelledMessage;

  /// No description provided for @freeTrialUntil.
  ///
  /// In en, this message translates to:
  /// **'Free trial until {date}'**
  String freeTrialUntil(String date);

  /// No description provided for @trialMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing is charged before then. After that it renews every month — cancel any time before the trial ends and you pay nothing.'**
  String get trialMessage;

  /// No description provided for @renewsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Renews every month'**
  String get renewsMonthly;

  /// No description provided for @shopActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Cancel any time — you keep access until the end of the month you\'ve paid for.'**
  String get shopActiveMessage;

  /// No description provided for @shopLoyaltyNote.
  ///
  /// In en, this message translates to:
  /// **'Every 2 months you stay, it costs {symbol}5 less, never below {symbol}100 and at most {symbol}100 off in all.'**
  String shopLoyaltyNote(String symbol);

  /// No description provided for @financeCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium insights stay on until then and you won\'t be charged again. The free finance summary stays after that.'**
  String get financeCancelledMessage;

  /// No description provided for @financeActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Cancel any time — you keep Premium insights until the end of the month you\'ve paid for. Every 2 months you stay, it costs {symbol}1 less, up to {symbol}5 off.'**
  String financeActiveMessage(String symbol);

  /// No description provided for @paymentMethodInvoices.
  ///
  /// In en, this message translates to:
  /// **'Payment method & invoices'**
  String get paymentMethodInvoices;

  /// No description provided for @subCancelledBanner.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled — you keep full access until {date} and won\'t be charged.'**
  String subCancelledBanner(String date);

  /// No description provided for @trialBanner.
  ///
  /// In en, this message translates to:
  /// **'Free trial until {date}. Cancel any time before then and you won\'t be charged.'**
  String trialBanner(String date);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @visibleForDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Customers can still find your shop for 1 day.} other{Customers can still find your shop for {count} days.}}'**
  String visibleForDays(int count);

  /// No description provided for @shopHidden.
  ///
  /// In en, this message translates to:
  /// **'Your shop is hidden from customers.'**
  String get shopHidden;

  /// No description provided for @deletionNotice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left before your shop and all its data are permanently deleted.} other{{count} days left before your shop and all its data are permanently deleted.}}'**
  String deletionNotice(int count);

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @subscriptionEnded.
  ///
  /// In en, this message translates to:
  /// **'Subscription ended'**
  String get subscriptionEnded;

  /// No description provided for @updatePayment.
  ///
  /// In en, this message translates to:
  /// **'Update payment'**
  String get updatePayment;

  /// No description provided for @hiddenUntilSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Your shop is hidden from customers until you subscribe.'**
  String get hiddenUntilSubscribe;

  /// No description provided for @payOnWebsite.
  ///
  /// In en, this message translates to:
  /// **'Payments are handled on the Fadra Cut business website.'**
  String get payOnWebsite;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @couldntLoadFigures.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your figures: {error}'**
  String couldntLoadFigures(String error);

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @loss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get loss;

  /// No description provided for @bookingsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Bookings ({count} completed)'**
  String bookingsCompleted(int count);

  /// No description provided for @otherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get otherIncome;

  /// No description provided for @costs.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get costs;

  /// No description provided for @addCostsHint.
  ///
  /// In en, this message translates to:
  /// **'Add your costs below to see where you stand.'**
  String get addCostsHint;

  /// No description provided for @costsCovered.
  ///
  /// In en, this message translates to:
  /// **'Costs covered — everything from here is profit.'**
  String get costsCovered;

  /// No description provided for @breakEvenProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the way to breaking even'**
  String breakEvenProgress(int percent);

  /// No description provided for @bookingsToBreakEven.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more booking at your average {average} would cover this month\'s costs.} other{{count} more bookings at your average {average} would cover this month\'s costs.}}'**
  String bookingsToBreakEven(int count, Object average);

  /// No description provided for @addACost.
  ///
  /// In en, this message translates to:
  /// **'Add a cost'**
  String get addACost;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @oneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off'**
  String get oneOff;

  /// No description provided for @monthlyCostHint.
  ///
  /// In en, this message translates to:
  /// **'Rent, wages, software… counted from {month} on.'**
  String monthlyCostHint(String month);

  /// No description provided for @oneOffCostHint.
  ///
  /// In en, this message translates to:
  /// **'Counted in {month} only.'**
  String oneOffCostHint(String month);

  /// No description provided for @whatIsIt.
  ///
  /// In en, this message translates to:
  /// **'What is it?'**
  String get whatIsIt;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @enterAnAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get enterAnAmount;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @costsIn.
  ///
  /// In en, this message translates to:
  /// **'Costs in {month}'**
  String costsIn(String month);

  /// No description provided for @noCostsYet.
  ///
  /// In en, this message translates to:
  /// **'No costs yet. Add rent, wages and anything else you pay to run the shop.'**
  String get noCostsYet;

  /// No description provided for @everyMonthAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Every month · added automatically'**
  String get everyMonthAutomatic;

  /// No description provided for @stopAfter.
  ///
  /// In en, this message translates to:
  /// **'Stop after {month}'**
  String stopAfter(String month);

  /// No description provided for @deleteFromEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Delete from every month'**
  String get deleteFromEveryMonth;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @otherIncomeFor.
  ///
  /// In en, this message translates to:
  /// **'Other income, {month}'**
  String otherIncomeFor(String month);

  /// No description provided for @otherIncomeHint.
  ///
  /// In en, this message translates to:
  /// **'Walk-ins, cash, product sales…'**
  String get otherIncomeHint;

  /// No description provided for @otherIncomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walk-ins and cash not booked through the app'**
  String get otherIncomeSubtitle;

  /// No description provided for @premiumFeatureForecast.
  ///
  /// In en, this message translates to:
  /// **'Month-end forecast and the day you\'ll break even'**
  String get premiumFeatureForecast;

  /// No description provided for @premiumFeatureOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers worked out for your shop, with what they\'ll earn you'**
  String get premiumFeatureOffers;

  /// No description provided for @premiumFeatureHistory.
  ///
  /// In en, this message translates to:
  /// **'12 months of profit history'**
  String get premiumFeatureHistory;

  /// No description provided for @premiumFeatureBusy.
  ///
  /// In en, this message translates to:
  /// **'When your chairs are busy — and when they sit empty'**
  String get premiumFeatureBusy;

  /// No description provided for @premiumFeatureBarbers.
  ///
  /// In en, this message translates to:
  /// **'Each barber\'s bookings, revenue and how full they are'**
  String get premiumFeatureBarbers;

  /// No description provided for @premiumFeatureRegulars.
  ///
  /// In en, this message translates to:
  /// **'Returning customers, and regulars you\'re losing'**
  String get premiumFeatureRegulars;

  /// No description provided for @premiumFeatureWhatIf.
  ///
  /// In en, this message translates to:
  /// **'What-if: try a price change before you make it'**
  String get premiumFeatureWhatIf;

  /// No description provided for @premiumTagline.
  ///
  /// In en, this message translates to:
  /// **'Your numbers, turned into decisions.'**
  String get premiumTagline;

  /// No description provided for @tryFree14Days.
  ///
  /// In en, this message translates to:
  /// **'Try it free for 14 days'**
  String get tryFree14Days;

  /// No description provided for @getPremium.
  ///
  /// In en, this message translates to:
  /// **'Get Premium — {price}/month'**
  String getPremium(String price);

  /// No description provided for @cancelFromSettings.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime from Settings › Subscription & billing.'**
  String get cancelFromSettings;

  /// No description provided for @noCardForTrial.
  ///
  /// In en, this message translates to:
  /// **'No card needed for the trial.'**
  String get noCardForTrial;

  /// No description provided for @premiumInsights.
  ///
  /// In en, this message translates to:
  /// **'Premium insights'**
  String get premiumInsights;

  /// No description provided for @whatToDoNext.
  ///
  /// In en, this message translates to:
  /// **'What to do next'**
  String get whatToDoNext;

  /// No description provided for @whatToDoNextSub.
  ///
  /// In en, this message translates to:
  /// **'Moves worked out from your own bookings, best first.'**
  String get whatToDoNextSub;

  /// No description provided for @suggestionsAppear.
  ///
  /// In en, this message translates to:
  /// **'Suggestions appear once you have about 10 completed bookings in the last 90 days.'**
  String get suggestionsAppear;

  /// No description provided for @profit12Months.
  ///
  /// In en, this message translates to:
  /// **'Profit, last 12 months'**
  String get profit12Months;

  /// No description provided for @tapABar.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar for the month\'s figures.'**
  String get tapABar;

  /// No description provided for @chairsBusy.
  ///
  /// In en, this message translates to:
  /// **'When your chairs are busy'**
  String get chairsBusy;

  /// No description provided for @chairsBusySub.
  ///
  /// In en, this message translates to:
  /// **'Share of chair time booked, last 8 weeks · overall {percent}'**
  String chairsBusySub(String percent);

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @customersHeading.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersHeading;

  /// No description provided for @servicesSub.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days, vs the 90 before'**
  String get servicesSub;

  /// No description provided for @whatIf.
  ///
  /// In en, this message translates to:
  /// **'What if…'**
  String get whatIf;

  /// No description provided for @whatIfSub.
  ///
  /// In en, this message translates to:
  /// **'Try a change on {month}\'s figures before making it.'**
  String whatIfSub(String month);

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisMonthSub.
  ///
  /// In en, this message translates to:
  /// **'Where you\'re heading at this pace'**
  String get thisMonthSub;

  /// No description provided for @forecastAppears.
  ///
  /// In en, this message translates to:
  /// **'A forecast appears once the month is under way.'**
  String get forecastAppears;

  /// No description provided for @freeTrialDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Free trial · 1 day left} other{Free trial · {count} days left}}'**
  String freeTrialDaysLeft(int count);

  /// No description provided for @keepPremiumFor.
  ///
  /// In en, this message translates to:
  /// **'Keep Premium for {price}/month'**
  String keepPremiumFor(String price);

  /// No description provided for @alreadyCoveredCosts.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already covered this month\'s costs.'**
  String get alreadyCoveredCosts;

  /// No description provided for @breakEvenOn.
  ///
  /// In en, this message translates to:
  /// **'At this pace you\'ll break even on {date}.'**
  String breakEvenOn(DateTime date);

  /// No description provided for @wontCoverCosts.
  ///
  /// In en, this message translates to:
  /// **'At this pace you won\'t cover this month\'s costs — see the suggestions below.'**
  String get wontCoverCosts;

  /// No description provided for @monthEndForecast.
  ///
  /// In en, this message translates to:
  /// **'Month-end forecast'**
  String get monthEndForecast;

  /// No description provided for @projectedProfitOn.
  ///
  /// In en, this message translates to:
  /// **'Projected profit on {revenue} revenue'**
  String projectedProfitOn(String revenue);

  /// No description provided for @projectedLossOn.
  ///
  /// In en, this message translates to:
  /// **'Projected loss on {revenue} revenue'**
  String projectedLossOn(String revenue);

  /// No description provided for @alreadyBookedRest.
  ///
  /// In en, this message translates to:
  /// **'{amount} already booked for the rest of the month.'**
  String alreadyBookedRest(String amount);

  /// No description provided for @basedOnPace.
  ///
  /// In en, this message translates to:
  /// **'Based on your pace so far this month and bookings already in the diary.'**
  String get basedOnPace;

  /// No description provided for @gainPerMonthShort.
  ///
  /// In en, this message translates to:
  /// **'+{amount}/mo'**
  String gainPerMonthShort(String amount);

  /// No description provided for @estimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate: {text}'**
  String estimate(String text);

  /// No description provided for @revenueLine.
  ///
  /// In en, this message translates to:
  /// **'Revenue {amount}'**
  String revenueLine(String amount);

  /// No description provided for @costsLine.
  ///
  /// In en, this message translates to:
  /// **'Costs {amount}'**
  String costsLine(String amount);

  /// No description provided for @profitLine.
  ///
  /// In en, this message translates to:
  /// **'Profit {amount}'**
  String profitLine(String amount);

  /// No description provided for @lossLine.
  ///
  /// In en, this message translates to:
  /// **'Loss {amount}'**
  String lossLine(String amount);

  /// No description provided for @setHoursToSee.
  ///
  /// In en, this message translates to:
  /// **'Set your opening hours and staff to see this.'**
  String get setHoursToSee;

  /// No description provided for @heatClosed.
  ///
  /// In en, this message translates to:
  /// **'{day} {hour}:00 · closed'**
  String heatClosed(String day, int hour);

  /// No description provided for @heatBooked.
  ///
  /// In en, this message translates to:
  /// **'{day} {hour}:00 · {percent} booked'**
  String heatBooked(String day, int hour, String percent);

  /// No description provided for @heatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty '**
  String get heatEmpty;

  /// No description provided for @heatFull.
  ///
  /// In en, this message translates to:
  /// **' Full'**
  String get heatFull;

  /// No description provided for @noStaffYet.
  ///
  /// In en, this message translates to:
  /// **'No staff yet.'**
  String get noStaffYet;

  /// No description provided for @barberStats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking · {percent} of their hours booked} other{{count} bookings · {percent} of their hours booked}}'**
  String barberStats(int count, Object percent);

  /// No description provided for @statCustomers.
  ///
  /// In en, this message translates to:
  /// **'customers'**
  String get statCustomers;

  /// No description provided for @statNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get statNew;

  /// No description provided for @statReturning.
  ///
  /// In en, this message translates to:
  /// **'returning'**
  String get statReturning;

  /// No description provided for @statCameBack.
  ///
  /// In en, this message translates to:
  /// **'came back*'**
  String get statCameBack;

  /// No description provided for @cameBackFootnote.
  ///
  /// In en, this message translates to:
  /// **'* Of customers who visited 6–12 weeks ago, the share who have been back since.'**
  String get cameBackFootnote;

  /// No description provided for @regularsLosing.
  ///
  /// In en, this message translates to:
  /// **'Regulars you\'re losing'**
  String get regularsLosing;

  /// No description provided for @regularsLosingSub.
  ///
  /// In en, this message translates to:
  /// **'Usually back every few weeks — now well overdue. Worth a message.'**
  String get regularsLosingSub;

  /// No description provided for @visitsUsually.
  ///
  /// In en, this message translates to:
  /// **'{visits} visits · usually every {days} days'**
  String visitsUsually(int visits, int days);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @noCompletedBookings90.
  ///
  /// In en, this message translates to:
  /// **'No completed bookings in the last 90 days.'**
  String get noCompletedBookings90;

  /// No description provided for @serviceStats.
  ///
  /// In en, this message translates to:
  /// **'{count} bookings · {percent} of all · {arrow} from {previous}'**
  String serviceStats(int count, String percent, String arrow, int previous);

  /// No description provided for @pricesChange.
  ///
  /// In en, this message translates to:
  /// **'Prices {change}'**
  String pricesChange(String change);

  /// No description provided for @bookingsChange.
  ///
  /// In en, this message translates to:
  /// **'Number of bookings {change}'**
  String bookingsChange(String change);

  /// No description provided for @monthActual.
  ///
  /// In en, this message translates to:
  /// **'{month} actual: {amount}'**
  String monthActual(String month, String amount);

  /// No description provided for @wouldBe.
  ///
  /// In en, this message translates to:
  /// **'Would be {amount}'**
  String wouldBe(String amount);

  /// No description provided for @amountAMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} a month'**
  String amountAMonth(String amount);

  /// No description provided for @addStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Add staff member'**
  String get addStaffMember;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @addStaffHint.
  ///
  /// In en, this message translates to:
  /// **'For staff without an app account. Someone with an account? Use \"Invite by name\" instead so their profile, schedule, and history stay linked to them.'**
  String get addStaffHint;

  /// No description provided for @inviteByName.
  ///
  /// In en, this message translates to:
  /// **'Invite by name'**
  String get inviteByName;

  /// No description provided for @legalFirstName.
  ///
  /// In en, this message translates to:
  /// **'Legal first name'**
  String get legalFirstName;

  /// No description provided for @legalLastName.
  ///
  /// In en, this message translates to:
  /// **'Legal last name'**
  String get legalLastName;

  /// No description provided for @legalSecondLastName.
  ///
  /// In en, this message translates to:
  /// **'Legal second last name (optional, disambiguates same-name matches)'**
  String get legalSecondLastName;

  /// No description provided for @noWorkerWithName.
  ///
  /// In en, this message translates to:
  /// **'No worker looking for work with that name.'**
  String get noWorkerWithName;

  /// No description provided for @multipleWorkersMatch.
  ///
  /// In en, this message translates to:
  /// **'Multiple workers match that name — add a second last name to narrow it down.'**
  String get multipleWorkersMatch;

  /// No description provided for @sendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get sendInvite;

  /// No description provided for @myWorkforce.
  ///
  /// In en, this message translates to:
  /// **'My Workforce'**
  String get myWorkforce;

  /// No description provided for @availableWorkers.
  ///
  /// In en, this message translates to:
  /// **'Available Workers'**
  String get availableWorkers;

  /// No description provided for @noStaffAddFirst.
  ///
  /// In en, this message translates to:
  /// **'No staff yet — add your first team member.'**
  String get noStaffAddFirst;

  /// No description provided for @sentInvitations.
  ///
  /// In en, this message translates to:
  /// **'Sent invitations'**
  String get sentInvitations;

  /// No description provided for @noInvitationsSent.
  ///
  /// In en, this message translates to:
  /// **'No invitations sent yet.'**
  String get noInvitationsSent;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @removeFromStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your staff?'**
  String removeFromStaffTitle(String name);

  /// No description provided for @removeFromStaffBody.
  ///
  /// In en, this message translates to:
  /// **'Customers won\'t be able to book with them. Their past bookings and history are kept.'**
  String get removeFromStaffBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @noAppAccount.
  ///
  /// In en, this message translates to:
  /// **'No app account'**
  String get noAppAccount;

  /// No description provided for @removeFromStaff.
  ///
  /// In en, this message translates to:
  /// **'Remove from staff'**
  String get removeFromStaff;

  /// No description provided for @hasAskedToLeave.
  ///
  /// In en, this message translates to:
  /// **'Has asked to leave.'**
  String get hasAskedToLeave;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @acknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get acknowledge;

  /// No description provided for @searchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get searchByName;

  /// No description provided for @filterRating.
  ///
  /// In en, this message translates to:
  /// **'4+ ★ rating'**
  String get filterRating;

  /// No description provided for @filterShops.
  ///
  /// In en, this message translates to:
  /// **'2+ shops'**
  String get filterShops;

  /// No description provided for @filterExperience.
  ///
  /// In en, this message translates to:
  /// **'3+ yrs experience'**
  String get filterExperience;

  /// No description provided for @noOneMatches.
  ///
  /// In en, this message translates to:
  /// **'No one matches right now.'**
  String get noOneMatches;

  /// No description provided for @shopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 shop} other{{count} shops}}'**
  String shopsCount(int count);

  /// No description provided for @yearsExpShort.
  ///
  /// In en, this message translates to:
  /// **'{count} yrs exp'**
  String yearsExpShort(int count);

  /// No description provided for @yearsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} yrs'**
  String yearsShort(int count);

  /// No description provided for @invitationSentTo.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {name}.'**
  String invitationSentTo(String name);

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolio;

  /// No description provided for @noPinnedWork.
  ///
  /// In en, this message translates to:
  /// **'No pinned work yet.'**
  String get noPinnedWork;

  /// No description provided for @alreadyOnStaff.
  ///
  /// In en, this message translates to:
  /// **'Already on your staff'**
  String get alreadyOnStaff;

  /// No description provided for @invitationAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent — awaiting response'**
  String get invitationAwaiting;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @fixHighlightedDays.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted days before saving.'**
  String get fixHighlightedDays;

  /// No description provided for @workerSchedule.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s schedule'**
  String workerSchedule(String name);

  /// No description provided for @daysOffUseShopHours.
  ///
  /// In en, this message translates to:
  /// **'Days left off use the shop\'s own opening hours instead.'**
  String get daysOffUseShopHours;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @enterANumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get enterANumber;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get durationMinutes;

  /// No description provided for @enterAWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get enterAWholeNumber;

  /// No description provided for @subscriptionChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your monthly subscription changes'**
  String get subscriptionChangesTitle;

  /// No description provided for @subscriptionChangesBody.
  ///
  /// In en, this message translates to:
  /// **'From your next payment it goes from {from} to {to} a month. Nothing changes for the month you\'ve already paid.'**
  String subscriptionChangesBody(String from, String to);

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @yourBasicCut.
  ///
  /// In en, this message translates to:
  /// **'Your basic cut'**
  String get yourBasicCut;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get addService;

  /// No description provided for @basicCutHelper.
  ///
  /// In en, this message translates to:
  /// **'Your standard haircut, with its price and duration.'**
  String get basicCutHelper;

  /// No description provided for @editBasicCut.
  ///
  /// In en, this message translates to:
  /// **'Edit your basic cut'**
  String get editBasicCut;

  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get editService;

  /// No description provided for @shopNeedsBasicCut.
  ///
  /// In en, this message translates to:
  /// **'Your shop needs a basic cut'**
  String get shopNeedsBasicCut;

  /// No description provided for @shopNeedsBasicCutBody.
  ///
  /// In en, this message translates to:
  /// **'To change it, edit it, or add another service and make that your basic cut. Then you can remove this one.'**
  String get shopNeedsBasicCutBody;

  /// No description provided for @removeServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeServiceTitle(String name);

  /// No description provided for @removeServiceBody.
  ///
  /// In en, this message translates to:
  /// **'Customers won\'t be able to book it any more. Bookings already made for it are kept.'**
  String get removeServiceBody;

  /// No description provided for @addYourBasicCut.
  ///
  /// In en, this message translates to:
  /// **'Add your basic cut'**
  String get addYourBasicCut;

  /// No description provided for @startWithBasicCut.
  ///
  /// In en, this message translates to:
  /// **'Start with your basic cut — your standard haircut.'**
  String get startWithBasicCut;

  /// No description provided for @basicCut.
  ///
  /// In en, this message translates to:
  /// **'Basic cut'**
  String get basicCut;

  /// No description provided for @serviceOptions.
  ///
  /// In en, this message translates to:
  /// **'Service options'**
  String get serviceOptions;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @makeBasicCut.
  ///
  /// In en, this message translates to:
  /// **'Make basic cut'**
  String get makeBasicCut;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markAsDone;

  /// No description provided for @noShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get noShow;

  /// No description provided for @markDoneReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Did this booking happen?'**
  String get markDoneReminderTitle;

  /// No description provided for @markDoneReminderBody.
  ///
  /// In en, this message translates to:
  /// **'{customer}\'s booking at {time} has ended. Mark it done or a no-show; otherwise it\'s marked done automatically 2 hours after it ends.'**
  String markDoneReminderBody(String customer, String time);

  /// No description provided for @aCustomer.
  ///
  /// In en, this message translates to:
  /// **'A customer'**
  String get aCustomer;

  /// No description provided for @autoCompletedCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking was marked done automatically} other{{count} bookings were marked done automatically}}'**
  String autoCompletedCheckTitle(int count);

  /// No description provided for @autoCompletedCheckBody.
  ///
  /// In en, this message translates to:
  /// **'Did they happen? A no-show isn\'t counted in Finance. You can change this for 7 days.'**
  String get autoCompletedCheckBody;

  /// No description provided for @itHappened.
  ///
  /// In en, this message translates to:
  /// **'It happened'**
  String get itHappened;

  /// No description provided for @fadraForBusiness.
  ///
  /// In en, this message translates to:
  /// **'Fadra Cut for Business'**
  String get fadraForBusiness;

  /// No description provided for @noBusinessFound.
  ///
  /// In en, this message translates to:
  /// **'No business found.'**
  String get noBusinessFound;

  /// No description provided for @serviceCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{service} other{services}}'**
  String serviceCountLabel(int count);

  /// No description provided for @staffCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{staff member} other{staff}}'**
  String staffCountLabel(int count);

  /// No description provided for @openNowBadge.
  ///
  /// In en, this message translates to:
  /// **'OPEN NOW'**
  String get openNowBadge;

  /// No description provided for @closedNowBadge.
  ///
  /// In en, this message translates to:
  /// **'CLOSED NOW'**
  String get closedNowBadge;

  /// No description provided for @inMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {count} min'**
  String inMinutes(int count);

  /// No description provided for @inHours.
  ///
  /// In en, this message translates to:
  /// **'in {count} h'**
  String inHours(int count);

  /// No description provided for @formerStaff.
  ///
  /// In en, this message translates to:
  /// **'Former staff'**
  String get formerStaff;

  /// No description provided for @bookingsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{booking today} other{bookings today}}'**
  String bookingsTodayLabel(int count);

  /// No description provided for @nextBooking.
  ///
  /// In en, this message translates to:
  /// **'Next booking'**
  String get nextBooking;

  /// No description provided for @nothingBookedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing booked yet'**
  String get nothingBookedYet;

  /// No description provided for @financeTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Costs, break-even and how to get there'**
  String get financeTileSubtitle;

  /// No description provided for @step2of3.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3'**
  String get step2of3;

  /// No description provided for @step3of3.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 3'**
  String get step3of3;

  /// No description provided for @step1of3.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 3'**
  String get step1of3;

  /// No description provided for @setupServicesHint.
  ///
  /// In en, this message translates to:
  /// **'Add your basic cut — your standard haircut — with its price and duration. Once setup is complete you can add the rest of your services.'**
  String get setupServicesHint;

  /// No description provided for @setupStaffHint.
  ///
  /// In en, this message translates to:
  /// **'Add everyone customers can book with — including yourself if you cut hair. Tap + for staff without an app account.'**
  String get setupStaffHint;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @checkDayHours.
  ///
  /// In en, this message translates to:
  /// **'Check {day}\'s opening hours.'**
  String checkDayHours(String day);

  /// No description provided for @setUpYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Set up your business'**
  String get setUpYourBusiness;

  /// No description provided for @setupDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Your business details. Next you\'ll add your services and staff — customers can find and book you once both are in.'**
  String get setupDetailsHint;

  /// No description provided for @businessPhone.
  ///
  /// In en, this message translates to:
  /// **'Business phone'**
  String get businessPhone;

  /// No description provided for @businessPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'For our records only — never shown to customers'**
  String get businessPhoneHelper;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get enterValidPhone;

  /// No description provided for @referralCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeOptional;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

  /// No description provided for @fixHighlightedHours.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted opening hours before saving.'**
  String get fixHighlightedHours;

  /// No description provided for @businessDetailsSaved.
  ///
  /// In en, this message translates to:
  /// **'Business details saved.'**
  String get businessDetailsSaved;

  /// No description provided for @shopHeaderPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'This is how your page\'s header looks to customers.'**
  String get shopHeaderPreviewHint;

  /// No description provided for @logo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get logo;

  /// No description provided for @coverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get coverPhoto;

  /// No description provided for @coverSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Best cover size: 1600 × 640. No logo? Your initials are shown. No cover? Your brand colour is used.'**
  String get coverSizeHint;

  /// No description provided for @brandColour.
  ///
  /// In en, this message translates to:
  /// **'Brand colour'**
  String get brandColour;

  /// No description provided for @brandColourHint.
  ///
  /// In en, this message translates to:
  /// **'Used for your header, buttons and highlights.'**
  String get brandColourHint;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @breakLabel.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakLabel;

  /// No description provided for @removeBreak.
  ///
  /// In en, this message translates to:
  /// **'Remove break'**
  String get removeBreak;

  /// No description provided for @addBreak.
  ///
  /// In en, this message translates to:
  /// **'Add break'**
  String get addBreak;

  /// No description provided for @hoursRangeError.
  ///
  /// In en, this message translates to:
  /// **'Closing must be after opening, with any break inside those hours.'**
  String get hoursRangeError;

  /// No description provided for @addAnotherLocation.
  ///
  /// In en, this message translates to:
  /// **'Add another location'**
  String get addAnotherLocation;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryUnitedKingdom.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get countryUnitedKingdom;

  /// No description provided for @countrySpain.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get countrySpain;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddress;

  /// No description provided for @postcode.
  ///
  /// In en, this message translates to:
  /// **'Postcode'**
  String get postcode;

  /// No description provided for @enterValidPostcode.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid postcode'**
  String get enterValidPostcode;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @bankAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank account for withdrawals'**
  String get bankAccountTitle;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get accountHolderName;

  /// No description provided for @enterAccountName.
  ///
  /// In en, this message translates to:
  /// **'Enter the name on the account'**
  String get enterAccountName;

  /// No description provided for @iban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// No description provided for @ibanHelper.
  ///
  /// In en, this message translates to:
  /// **'In your banking app. UK accounts have one too (starts GB).'**
  String get ibanHelper;

  /// No description provided for @enterYourIban.
  ///
  /// In en, this message translates to:
  /// **'Enter your IBAN'**
  String get enterYourIban;

  /// No description provided for @bankAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'Bank account saved.'**
  String get bankAccountSaved;

  /// No description provided for @withdrawCurrency.
  ///
  /// In en, this message translates to:
  /// **'Withdraw {currency}'**
  String withdrawCurrency(String currency);

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmount;

  /// No description provided for @moreThanBalance.
  ///
  /// In en, this message translates to:
  /// **'More than your available balance'**
  String get moreThanBalance;

  /// No description provided for @payoutTo.
  ///
  /// In en, this message translates to:
  /// **'To {holder}, {iban}'**
  String payoutTo(String holder, String iban);

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @withdrawalRequested.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal requested.'**
  String get withdrawalRequested;

  /// No description provided for @rewardHistory.
  ///
  /// In en, this message translates to:
  /// **'Reward history'**
  String get rewardHistory;

  /// No description provided for @balanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance: {amount}'**
  String balanceLabel(String amount);

  /// No description provided for @amountAvailable.
  ///
  /// In en, this message translates to:
  /// **'{amount} available'**
  String amountAvailable(String amount);

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @noBankAccountYet.
  ///
  /// In en, this message translates to:
  /// **'No bank account yet'**
  String get noBankAccountYet;

  /// No description provided for @withdrawalsSentHere.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals are sent here by bank transfer'**
  String get withdrawalsSentHere;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @withdrawals.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals'**
  String get withdrawals;

  /// No description provided for @referrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referrals;

  /// No description provided for @referralSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 business referred — {earned} earned (5% of their subscription payments)} other{{count} businesses referred — {earned} earned (5% of their subscription payments)}}'**
  String referralSummary(int count, Object earned);

  /// No description provided for @noRewardsYet.
  ///
  /// In en, this message translates to:
  /// **'No rewards yet.'**
  String get noRewardsYet;

  /// No description provided for @payoutPending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get payoutPending;

  /// No description provided for @payoutApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved — payment on its way'**
  String get payoutApproved;

  /// No description provided for @payoutRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get payoutRejected;

  /// No description provided for @payoutPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get payoutPaid;

  /// No description provided for @invitationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get invitationPending;

  /// No description provided for @invitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get invitationAccepted;

  /// No description provided for @invitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get invitationDeclined;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @askedShopToConfirmLeaving.
  ///
  /// In en, this message translates to:
  /// **'Asked {shop} to confirm you\'re leaving.'**
  String askedShopToConfirmLeaving(String shop);

  /// No description provided for @theShop.
  ///
  /// In en, this message translates to:
  /// **'the shop'**
  String get theShop;

  /// No description provided for @workerMarketplaceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The worker marketplace isn\'t available on this account.'**
  String get workerMarketplaceUnavailable;

  /// No description provided for @availableAsWorker.
  ///
  /// In en, this message translates to:
  /// **'Available as worker'**
  String get availableAsWorker;

  /// No description provided for @availableAsWorkerSub.
  ///
  /// In en, this message translates to:
  /// **'Let barbershops find and invite you as staff'**
  String get availableAsWorkerSub;

  /// No description provided for @useRealNameHint.
  ///
  /// In en, this message translates to:
  /// **'Use your real name — this is what businesses and customers will see you as once you accept a job.'**
  String get useRealNameHint;

  /// No description provided for @legalSecondLastNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Legal second last name (optional)'**
  String get legalSecondLastNameOptional;

  /// No description provided for @yearsExperienceOptional.
  ///
  /// In en, this message translates to:
  /// **'Years of experience (optional)'**
  String get yearsExperienceOptional;

  /// No description provided for @experienceBio.
  ///
  /// In en, this message translates to:
  /// **'Experience / bio'**
  String get experienceBio;

  /// No description provided for @lookingForWork.
  ///
  /// In en, this message translates to:
  /// **'Looking for work'**
  String get lookingForWork;

  /// No description provided for @addLegalNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your legal first and last name first'**
  String get addLegalNameFirst;

  /// No description provided for @currentJob.
  ///
  /// In en, this message translates to:
  /// **'Current job'**
  String get currentJob;

  /// No description provided for @notCurrentlyWorking.
  ///
  /// In en, this message translates to:
  /// **'Not currently working at a business.'**
  String get notCurrentlyWorking;

  /// No description provided for @aBusiness.
  ///
  /// In en, this message translates to:
  /// **'A business'**
  String get aBusiness;

  /// No description provided for @leaveRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Leave request sent — awaiting confirmation'**
  String get leaveRequestSent;

  /// No description provided for @requestToLeave.
  ///
  /// In en, this message translates to:
  /// **'Request to leave'**
  String get requestToLeave;

  /// No description provided for @invitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get invitations;

  /// No description provided for @noPendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations.'**
  String get noPendingInvitations;

  /// No description provided for @wantsToAddYou.
  ///
  /// In en, this message translates to:
  /// **'wants to add you as staff'**
  String get wantsToAddYou;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @windowWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get windowWeek;

  /// No description provided for @windowMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get windowMonth;

  /// No description provided for @windowYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get windowYear;

  /// No description provided for @windowAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get windowAllTime;

  /// No description provided for @rankShopsVisited.
  ///
  /// In en, this message translates to:
  /// **'Most shops visited'**
  String get rankShopsVisited;

  /// No description provided for @rankMostHaircuts.
  ///
  /// In en, this message translates to:
  /// **'Most haircuts'**
  String get rankMostHaircuts;

  /// No description provided for @rankTopReferrers.
  ///
  /// In en, this message translates to:
  /// **'Top referrers'**
  String get rankTopReferrers;

  /// No description provided for @rankPopularHaircuts.
  ///
  /// In en, this message translates to:
  /// **'Popular haircuts'**
  String get rankPopularHaircuts;

  /// No description provided for @rankTopBarbers.
  ///
  /// In en, this message translates to:
  /// **'Top-rated barbers'**
  String get rankTopBarbers;

  /// No description provided for @unitShops.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{shop} other{shops}}'**
  String unitShops(int count);

  /// No description provided for @unitHaircuts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{haircut} other{haircuts}}'**
  String unitHaircuts(int count);

  /// No description provided for @unitBusinessesReferred.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{business referred} other{businesses referred}}'**
  String unitBusinessesReferred(int count);

  /// No description provided for @unitCuts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{cut} other{cuts}}'**
  String unitCuts(int count);

  /// No description provided for @noReferralsYet.
  ///
  /// In en, this message translates to:
  /// **'No referrals yet'**
  String get noReferralsYet;

  /// No description provided for @noReferralsHint.
  ///
  /// In en, this message translates to:
  /// **'Share your referral code with a shop and you could top this board.'**
  String get noReferralsHint;

  /// No description provided for @noRatedBarbers.
  ///
  /// In en, this message translates to:
  /// **'No rated barbers yet'**
  String get noRatedBarbers;

  /// No description provided for @noRatedBarbersHint.
  ///
  /// In en, this message translates to:
  /// **'Barbers appear here once customers start reviewing their cuts.'**
  String get noRatedBarbersHint;

  /// No description provided for @noHaircutsInWindow.
  ///
  /// In en, this message translates to:
  /// **'{window, select, week{No haircuts this week} month{No haircuts this month} year{No haircuts this year} other{No haircuts yet}}'**
  String noHaircutsInWindow(String window);

  /// No description provided for @popularStylesHint.
  ///
  /// In en, this message translates to:
  /// **'Popular styles show up as soon as cuts are booked and done.'**
  String get popularStylesHint;

  /// No description provided for @boardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The board is empty'**
  String get boardEmpty;

  /// No description provided for @boardEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'{window, select, week{Nobody has a cut this week yet. Book one and take the top spot.} month{Nobody has a cut this month yet. Book one and take the top spot.} year{Nobody has a cut this year yet. Book one and take the top spot.} other{Nobody has a cut yet. Book one and take the top spot.}}'**
  String boardEmptyHint(String window);

  /// No description provided for @tallyingBoard.
  ///
  /// In en, this message translates to:
  /// **'Tallying the board…'**
  String get tallyingBoard;

  /// No description provided for @couldntLoadRankings.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load rankings'**
  String get couldntLoadRankings;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @nameYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String nameYou(String name);

  /// No description provided for @videoTooLong.
  ///
  /// In en, this message translates to:
  /// **'Videos must be 1 minute or shorter (this one is {seconds}s).'**
  String videoTooLong(int seconds);

  /// No description provided for @postingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Posting isn\'t available on this account.'**
  String get postingUnavailable;

  /// No description provided for @whatsGoingOn.
  ///
  /// In en, this message translates to:
  /// **'What\'s going on?'**
  String get whatsGoingOn;

  /// No description provided for @addAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addAPhoto;

  /// No description provided for @addAVideo.
  ///
  /// In en, this message translates to:
  /// **'Add a video'**
  String get addAVideo;

  /// No description provided for @changeVideo.
  ///
  /// In en, this message translates to:
  /// **'Change video'**
  String get changeVideo;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @freshCuts.
  ///
  /// In en, this message translates to:
  /// **'Fresh Cuts'**
  String get freshCuts;

  /// No description provided for @leaderboards.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get leaderboards;

  /// No description provided for @fetchingFreshCuts.
  ///
  /// In en, this message translates to:
  /// **'Fetching fresh cuts…'**
  String get fetchingFreshCuts;

  /// No description provided for @couldntLoadFeed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the feed'**
  String get couldntLoadFeed;

  /// No description provided for @wallIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The wall is empty'**
  String get wallIsEmpty;

  /// No description provided for @beFirstToShow.
  ///
  /// In en, this message translates to:
  /// **'Be the first to show off a cut.'**
  String get beFirstToShow;

  /// No description provided for @shareAPost.
  ///
  /// In en, this message translates to:
  /// **'Share a post'**
  String get shareAPost;

  /// No description provided for @couldntLoadMorePosts.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more posts. Try again'**
  String get couldntLoadMorePosts;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get allCaughtUp;

  /// No description provided for @everyPostSoFar.
  ///
  /// In en, this message translates to:
  /// **'That\'s every post so far.'**
  String get everyPostSoFar;

  /// No description provided for @couldNotUpdateLike.
  ///
  /// In en, this message translates to:
  /// **'Could not update like.'**
  String get couldNotUpdateLike;

  /// No description provided for @couldNotUpdatePortfolio.
  ///
  /// In en, this message translates to:
  /// **'Could not update portfolio.'**
  String get couldNotUpdatePortfolio;

  /// No description provided for @deletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get deletePostTitle;

  /// No description provided for @deletePostBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the feed for everyone. This can\'t be undone.'**
  String get deletePostBody;

  /// No description provided for @inPortfolio.
  ///
  /// In en, this message translates to:
  /// **'In portfolio'**
  String get inPortfolio;

  /// No description provided for @postOptions.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get postOptions;

  /// No description provided for @removeFromPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Remove from portfolio'**
  String get removeFromPortfolio;

  /// No description provided for @addToPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Add to portfolio'**
  String get addToPortfolio;

  /// No description provided for @unlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get unlike;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @likeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 like} other{{count} likes}}'**
  String likeCount(int count);

  /// No description provided for @viewComments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{View 1 comment} other{View all {count} comments}}'**
  String viewComments(int count);

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @timeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String timeMinutes(int count);

  /// No description provided for @timeHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String timeHours(int count);

  /// No description provided for @timeDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String timeDays(int count);

  /// No description provided for @loadingComments.
  ///
  /// In en, this message translates to:
  /// **'Loading comments…'**
  String get loadingComments;

  /// No description provided for @couldntLoadComments.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load comments'**
  String get couldntLoadComments;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noCommentsYet;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation.'**
  String get startConversation;

  /// No description provided for @commentsShowHere.
  ///
  /// In en, this message translates to:
  /// **'Comments will show up here.'**
  String get commentsShowHere;

  /// No description provided for @writeAComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment'**
  String get writeAComment;

  /// No description provided for @deleteCommentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get deleteCommentTitle;

  /// No description provided for @cantBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get cantBeUndone;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @writeAReply.
  ///
  /// In en, this message translates to:
  /// **'Write a reply…'**
  String get writeAReply;

  /// No description provided for @addAComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get addAComment;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @findPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get findPeople;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found.'**
  String get profileNotFound;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @postsUpper.
  ///
  /// In en, this message translates to:
  /// **'POSTS'**
  String get postsUpper;

  /// No description provided for @badgeBarber.
  ///
  /// In en, this message translates to:
  /// **'Barber'**
  String get badgeBarber;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @postSemantics.
  ///
  /// In en, this message translates to:
  /// **'Post, {likes} likes, {comments} comments'**
  String postSemantics(int likes, int comments);

  /// No description provided for @noPostsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYetTitle;

  /// No description provided for @showOffLatestCut.
  ///
  /// In en, this message translates to:
  /// **'Show off your latest cut. Your posts appear here and in the feed.'**
  String get showOffLatestCut;

  /// No description provided for @shareFirstPost.
  ///
  /// In en, this message translates to:
  /// **'Share your first post'**
  String get shareFirstPost;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get noUsersFound;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet — say hello.'**
  String get noMessagesYet;

  /// No description provided for @messageTo.
  ///
  /// In en, this message translates to:
  /// **'Message {name}'**
  String messageTo(String name);

  /// No description provided for @kindBarber.
  ///
  /// In en, this message translates to:
  /// **'Barber · '**
  String get kindBarber;

  /// No description provided for @kindShop.
  ///
  /// In en, this message translates to:
  /// **'Shop · '**
  String get kindShop;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @readMarker.
  ///
  /// In en, this message translates to:
  /// **' · Read'**
  String get readMarker;

  /// No description provided for @workerAskedToLeave.
  ///
  /// In en, this message translates to:
  /// **'This worker has asked to leave. They stay on staff until you confirm.'**
  String get workerAskedToLeave;

  /// No description provided for @confirmLeaving.
  ///
  /// In en, this message translates to:
  /// **'Confirm they\'re leaving'**
  String get confirmLeaving;

  /// No description provided for @allCaughtUpShort.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get allCaughtUpShort;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @inboxPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get inboxPersonal;

  /// No description provided for @inboxBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get inboxBusiness;

  /// No description provided for @loadingConversations.
  ///
  /// In en, this message translates to:
  /// **'Loading conversations…'**
  String get loadingConversations;

  /// No description provided for @couldntLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load messages'**
  String get couldntLoadMessages;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @noConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Find a barber or a friend and say hello from their profile.'**
  String get noConversationsHint;

  /// No description provided for @noWorkMessages.
  ///
  /// In en, this message translates to:
  /// **'No work messages'**
  String get noWorkMessages;

  /// No description provided for @noWorkMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'When a shop and a barber talk about work, it shows up here.'**
  String get noWorkMessagesHint;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello 👋'**
  String get sayHello;

  /// No description provided for @messagesUnreadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Messages, {count} unread'**
  String messagesUnreadTooltip(int count);

  /// No description provided for @messagesWithCount.
  ///
  /// In en, this message translates to:
  /// **'Messages ({count})'**
  String messagesWithCount(int count);

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — try again.'**
  String get somethingWentWrong;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists — sign in, or use \"Continue with Google\" if that\'s how you signed up.'**
  String get emailAlreadyRegistered;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get usernameTaken;

  /// No description provided for @referralCodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'That referral code doesn\'t exist.'**
  String get referralCodeNotFound;

  /// No description provided for @alreadyInvited.
  ///
  /// In en, this message translates to:
  /// **'You already have a pending invitation out to this worker.'**
  String get alreadyInvited;

  /// No description provided for @alreadyOnYourStaff.
  ///
  /// In en, this message translates to:
  /// **'They\'re already on your staff.'**
  String get alreadyOnYourStaff;

  /// No description provided for @staffHasUpcomingBookings.
  ///
  /// In en, this message translates to:
  /// **'This barber has upcoming bookings — cancel or complete them first.'**
  String get staffHasUpcomingBookings;

  /// No description provided for @alreadyStaffElsewhere.
  ///
  /// In en, this message translates to:
  /// **'You\'re already working at another shop — leave that role before accepting a new one.'**
  String get alreadyStaffElsewhere;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email first — check your inbox for the link.'**
  String get authEmailNotConfirmed;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is too weak — use at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authSamePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password different from your current one.'**
  String get authSamePassword;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — wait a minute and try again.'**
  String get authRateLimited;

  /// No description provided for @authLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'That link has expired — ask for a new one.'**
  String get authLinkExpired;

  /// No description provided for @offlineShowingSaved.
  ///
  /// In en, this message translates to:
  /// **'No connection — showing what was last saved.'**
  String get offlineShowingSaved;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @savedWillSend.
  ///
  /// In en, this message translates to:
  /// **'Saved — it will be sent when you\'re back online.'**
  String get savedWillSend;

  /// No description provided for @bookingNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'You need a connection to book'**
  String get bookingNeedsConnection;

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable — tap to try again'**
  String get videoUnavailable;

  /// No description provided for @upcomingTab.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingTab;

  /// No description provided for @pastTab.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get pastTab;

  /// No description provided for @noUpcomingBookings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings.'**
  String get noUpcomingBookings;

  /// No description provided for @noPastBookings.
  ///
  /// In en, this message translates to:
  /// **'No past bookings yet.'**
  String get noPastBookings;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutesShort(int count);

  /// No description provided for @noUpcomingBookingsShopHint.
  ///
  /// In en, this message translates to:
  /// **'Bookings show up here as soon as customers make them. A complete shop page helps them choose you.'**
  String get noUpcomingBookingsShopHint;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBooking;

  /// No description provided for @cancelBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get cancelBookingTitle;

  /// No description provided for @cancelBookingBody.
  ///
  /// In en, this message translates to:
  /// **'Your {time} appointment at {shop} on {date} will be cancelled, and the time will be free for someone else to book.'**
  String cancelBookingBody(String time, String shop, String date);

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get yesCancel;

  /// No description provided for @bookingCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled.'**
  String get bookingCancelledToast;

  /// No description provided for @aboutGroup.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutGroup;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// No description provided for @emailAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'No email app found. The address is copied.'**
  String get emailAddressCopied;

  /// No description provided for @searchByNameOrCity.
  ///
  /// In en, this message translates to:
  /// **'Search by name or city'**
  String get searchByNameOrCity;

  /// No description provided for @tryNameCityOrNearMe.
  ///
  /// In en, this message translates to:
  /// **'Try another name or city, or use Near me.'**
  String get tryNameCityOrNearMe;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearMe;

  /// No description provided for @newShop.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newShop;

  /// No description provided for @fromPrice.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String fromPrice(String price);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String distanceKm(String distance);

  /// No description provided for @distanceMiles.
  ///
  /// In en, this message translates to:
  /// **'{distance} mi'**
  String distanceMiles(String distance);

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off on this phone.'**
  String get locationServiceOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Without your location, search by city instead.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location is off for Fadra Cut. You can turn it on in Settings.'**
  String get locationDeniedForever;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your location. Try again in a moment.'**
  String get locationFailed;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated.'**
  String get photoUpdated;

  /// No description provided for @photoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed.'**
  String get photoRemoved;

  /// No description provided for @displayNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get displayNameOptional;

  /// No description provided for @shownAboveUsername.
  ///
  /// In en, this message translates to:
  /// **'Shown above @{username}'**
  String shownAboveUsername(String username);

  /// No description provided for @bioOptional.
  ///
  /// In en, this message translates to:
  /// **'Bio (optional)'**
  String get bioOptional;

  /// No description provided for @lookingForWorkSub.
  ///
  /// In en, this message translates to:
  /// **'Shops can find you and invite you to join their staff. Switch off to hide your profile.'**
  String get lookingForWorkSub;

  /// No description provided for @declineInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline {shop}\'s invitation?'**
  String declineInvitationTitle(String shop);

  /// No description provided for @declineInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'They\'d need to invite you again if you change your mind.'**
  String get declineInvitationBody;
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
