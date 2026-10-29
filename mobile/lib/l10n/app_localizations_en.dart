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

  @override
  String errorWithDetail(String error) {
    return 'Error: $error';
  }

  @override
  String greeting(String name) {
    return 'Hey, $name';
  }

  @override
  String get greetingNoName => 'Hey there';

  @override
  String get whatsNext => 'Here\'s what\'s next.';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get myBookings => 'My bookings';

  @override
  String get nextUp => 'NEXT UP';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String inDays(int days) {
    return 'In $days days';
  }

  @override
  String get loadingEllipsis => 'Loading…';

  @override
  String get view => 'View';

  @override
  String jobInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A barbershop wants to hire you — $count job invitations waiting.',
      one: 'A barbershop wants to hire you — 1 job invitation waiting.',
    );
    return '$_temp0';
  }

  @override
  String get noAppointments => 'No appointments booked';

  @override
  String get noAppointmentsHint => 'Find a shop and get in the chair.';

  @override
  String get browseBarbershops => 'Browse barbershops';

  @override
  String get closureWithinADay =>
      'This booking will be cancelled within a day unless the shop renews its subscription.';

  @override
  String closureBy(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'This shop hasn\'t renewed its subscription. If it doesn\'t by $dateString, this booking will be cancelled.';
  }

  @override
  String get noBookingsYet => 'No bookings yet.';

  @override
  String get reviewed => 'Reviewed';

  @override
  String get leaveAReview => 'Leave a review';

  @override
  String get bookingConfirmed => 'Confirmed';

  @override
  String get bookingCancelled => 'Cancelled';

  @override
  String get bookingCompleted => 'Completed';

  @override
  String get bookAppointment => 'Book appointment';

  @override
  String get day => 'Day';

  @override
  String get calendar => 'Calendar';

  @override
  String get pickATime => 'Pick a time to continue';

  @override
  String withBarber(String name) {
    return 'with $name';
  }

  @override
  String get book => 'Book';

  @override
  String get findingFreeTimes => 'Finding free times…';

  @override
  String get couldntLoadTimes => 'Couldn\'t load times';

  @override
  String get checkConnection => 'Check your connection and try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String noFreeTimesOn(String day) {
    return 'No free times on $day';
  }

  @override
  String get shopClosedOrFull => 'The shop is closed or fully booked that day.';

  @override
  String tryDay(String day) {
    return 'Try $day';
  }

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get barber => 'Barber';

  @override
  String freeCount(int count) {
    return '$count free';
  }

  @override
  String get anyBarber => 'Any barber';

  @override
  String get findAShop => 'Find a shop';

  @override
  String get searchBarbershops => 'Search barbershops';

  @override
  String get noBarbershopsYet => 'No barbershops yet';

  @override
  String get noBarbershopsHint => 'Check back soon — new shops show up here.';

  @override
  String noMatchesFor(String query) {
    return 'No matches for \"$query\"';
  }

  @override
  String get tryDifferentName => 'Try a different name.';

  @override
  String get skipRatingTitle => 'Skip this rating?';

  @override
  String get skipRatingBody =>
      'Ratings can earn you rewards later on — if you skip this one, you won\'t get anything for it. Skip anyway?';

  @override
  String get skipAnyway => 'Skip anyway';

  @override
  String get omit => 'Omit';

  @override
  String get submitReview => 'Submit review';

  @override
  String get next => 'Next';

  @override
  String get rateTheShop => 'Rate the shop';

  @override
  String get rateTheBarber => 'Rate the barber';

  @override
  String get rateTheHaircut => 'Rate the haircut';

  @override
  String get haircutTypeLabel => 'Haircut type';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get hcBuzzCut => 'Buzz Cut';

  @override
  String get hcCrewCut => 'Crew Cut';

  @override
  String get hcFade => 'Fade';

  @override
  String get hcUndercut => 'Undercut';

  @override
  String get hcPompadour => 'Pompadour';

  @override
  String get hcQuiff => 'Quiff';

  @override
  String get hcSlickBack => 'Slick Back';

  @override
  String get hcTexturedCrop => 'Textured Crop';

  @override
  String get hcMullet => 'Mullet';

  @override
  String get hcAfro => 'Afro';

  @override
  String get hcBaldShaved => 'Bald/Shaved';

  @override
  String get hcBeardTrim => 'Beard Trim';

  @override
  String get hcOther => 'Other';

  @override
  String get shopHiddenOwner =>
      'Your shop page is hidden from customers until your subscription is active.';

  @override
  String get shopUnavailable => 'This shop isn\'t available right now.';

  @override
  String get editShopPage => 'Edit shop page';

  @override
  String get newOnTheApp => 'New on the app';

  @override
  String moreLocations(int count) {
    return '+$count more';
  }

  @override
  String get newPost => 'New post';

  @override
  String get editPage => 'Edit page';

  @override
  String get messageTheShop => 'Message the shop';

  @override
  String get barbers => 'Barbers';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get locations => 'Locations';

  @override
  String get posts => 'Posts';

  @override
  String get reviews => 'Reviews';

  @override
  String get closedToday => 'Closed today';

  @override
  String openNowUntil(String time) {
    return 'Open now · until $time';
  }

  @override
  String opensAt(String time) {
    return 'Opens $time';
  }

  @override
  String get closedNow => 'Closed now';

  @override
  String get closed => 'Closed';

  @override
  String get noServicesYet => 'No services listed yet.';

  @override
  String get noBarbersYet => 'No barbers listed yet.';

  @override
  String get noReviewsYet => 'No reviews yet.';

  @override
  String get noPostsYet => 'No posts yet.';

  @override
  String get cancelSubTitle => 'Cancel your subscription?';

  @override
  String cancelSubBodyTrial(String date) {
    return 'Your free trial still runs until $date and won\'t be charged again. After that your shop is hidden from customers until you subscribe again.';
  }

  @override
  String get cancelSubBodyPaid =>
      'You keep full access until the end of the month you\'ve paid for and won\'t be charged again. After that your shop is hidden from customers until you subscribe again.';

  @override
  String get cancelSubscription => 'Cancel subscription';

  @override
  String get keepIt => 'Keep it';

  @override
  String get subscriptionCancelled => 'Subscription cancelled';

  @override
  String planWithPrice(String price) {
    return 'your subscription ($price / month)';
  }

  @override
  String get planNoPrice => 'your subscription';

  @override
  String get resubTitle => 'Subscribe again?';

  @override
  String resubBodyTrial(String date, String plan) {
    return 'Your free trial continues until $date. After that, $plan is charged to the card you already added.';
  }

  @override
  String resubBodyPaid(String plan) {
    return 'We\'ll keep charging $plan to the card you already added. Nothing extra is charged today.';
  }

  @override
  String get subscribe => 'Subscribe';

  @override
  String get notNow => 'Not now';

  @override
  String get subscribedAgain => 'You\'re subscribed again';

  @override
  String get cancelFinanceTitle => 'Cancel Finance Premium?';

  @override
  String get cancelFinanceBody =>
      'You keep Premium insights until the end of the month you\'ve paid for and won\'t be charged again. The free finance summary stays.';

  @override
  String get cancelPremium => 'Cancel Premium';

  @override
  String get financeCancelled => 'Finance Premium cancelled';

  @override
  String get resubFinanceTitle => 'Subscribe to Finance Premium again?';

  @override
  String resubFinanceBody(String what) {
    return 'We\'ll keep charging $what to the card you already added. Nothing extra is charged today.';
  }

  @override
  String get itPronoun => 'it';

  @override
  String perMonth(String price) {
    return '$price / month';
  }

  @override
  String get financeSubscribedAgain =>
      'You\'re subscribed to Finance Premium again';

  @override
  String get subscribeAgain => 'Subscribe again';

  @override
  String get freeAccess =>
      'Your shop has free access — there\'s nothing to pay.';

  @override
  String get shopSubscription => 'Shop subscription';

  @override
  String get badgeCancelled => 'Cancelled';

  @override
  String get badgeFreeTrial => 'Free trial';

  @override
  String get badgeActive => 'Active';

  @override
  String endsOn(String date) {
    return 'Ends $date';
  }

  @override
  String get shopCancelledMessage =>
      'Your shop stays visible to customers until then and you won\'t be charged again. After that it\'s hidden until you subscribe again, and its data is kept for 60 days.';

  @override
  String freeTrialUntil(String date) {
    return 'Free trial until $date';
  }

  @override
  String get trialMessage =>
      'Nothing is charged before then. After that it renews every month — cancel any time before the trial ends and you pay nothing.';

  @override
  String get renewsMonthly => 'Renews every month';

  @override
  String get shopActiveMessage =>
      'Cancel any time — you keep access until the end of the month you\'ve paid for.';

  @override
  String shopLoyaltyNote(String symbol) {
    return 'Every 2 months you stay, it costs ${symbol}5 less, never below ${symbol}100 and at most ${symbol}100 off in all.';
  }

  @override
  String get financeCancelledMessage =>
      'Premium insights stay on until then and you won\'t be charged again. The free finance summary stays after that.';

  @override
  String financeActiveMessage(String symbol) {
    return 'Cancel any time — you keep Premium insights until the end of the month you\'ve paid for. Every 2 months you stay, it costs ${symbol}1 less, up to ${symbol}5 off.';
  }

  @override
  String get paymentMethodInvoices => 'Payment method & invoices';

  @override
  String subCancelledBanner(String date) {
    return 'Subscription cancelled — you keep full access until $date and won\'t be charged.';
  }

  @override
  String trialBanner(String date) {
    return 'Free trial until $date. Cancel any time before then and you won\'t be charged.';
  }

  @override
  String get manage => 'Manage';

  @override
  String visibleForDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Customers can still find your shop for $count days.',
      one: 'Customers can still find your shop for 1 day.',
    );
    return '$_temp0';
  }

  @override
  String get shopHidden => 'Your shop is hidden from customers.';

  @override
  String deletionNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count days left before your shop and all its data are permanently deleted.',
      one:
          '1 day left before your shop and all its data are permanently deleted.',
    );
    return '$_temp0';
  }

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get subscriptionEnded => 'Subscription ended';

  @override
  String get updatePayment => 'Update payment';

  @override
  String get hiddenUntilSubscribe =>
      'Your shop is hidden from customers until you subscribe.';

  @override
  String get payOnWebsite =>
      'Payments are handled on the Fadra Cut business website.';
}
