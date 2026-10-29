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

  @override
  String get refresh => 'Refresh';

  @override
  String couldntLoadFigures(String error) {
    return 'Couldn\'t load your figures: $error';
  }

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get profit => 'Profit';

  @override
  String get loss => 'Loss';

  @override
  String bookingsCompleted(int count) {
    return 'Bookings ($count completed)';
  }

  @override
  String get otherIncome => 'Other income';

  @override
  String get costs => 'Costs';

  @override
  String get addCostsHint => 'Add your costs below to see where you stand.';

  @override
  String get costsCovered => 'Costs covered — everything from here is profit.';

  @override
  String breakEvenProgress(int percent) {
    return '$percent% of the way to breaking even';
  }

  @override
  String bookingsToBreakEven(int count, Object average) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count more bookings at your average $average would cover this month\'s costs.',
      one:
          '1 more booking at your average $average would cover this month\'s costs.',
    );
    return '$_temp0';
  }

  @override
  String get addACost => 'Add a cost';

  @override
  String get everyMonth => 'Every month';

  @override
  String get oneOff => 'One-off';

  @override
  String monthlyCostHint(String month) {
    return 'Rent, wages, software… counted from $month on.';
  }

  @override
  String oneOffCostHint(String month) {
    return 'Counted in $month only.';
  }

  @override
  String get whatIsIt => 'What is it?';

  @override
  String get amount => 'Amount';

  @override
  String get enterAnAmount => 'Enter an amount';

  @override
  String get add => 'Add';

  @override
  String costsIn(String month) {
    return 'Costs in $month';
  }

  @override
  String get noCostsYet =>
      'No costs yet. Add rent, wages and anything else you pay to run the shop.';

  @override
  String get everyMonthAutomatic => 'Every month · added automatically';

  @override
  String stopAfter(String month) {
    return 'Stop after $month';
  }

  @override
  String get deleteFromEveryMonth => 'Delete from every month';

  @override
  String get delete => 'Delete';

  @override
  String otherIncomeFor(String month) {
    return 'Other income, $month';
  }

  @override
  String get otherIncomeHint => 'Walk-ins, cash, product sales…';

  @override
  String get otherIncomeSubtitle =>
      'Walk-ins and cash not booked through the app';

  @override
  String get premiumFeatureForecast =>
      'Month-end forecast and the day you\'ll break even';

  @override
  String get premiumFeatureOffers =>
      'Offers worked out for your shop, with what they\'ll earn you';

  @override
  String get premiumFeatureHistory => '12 months of profit history';

  @override
  String get premiumFeatureBusy =>
      'When your chairs are busy — and when they sit empty';

  @override
  String get premiumFeatureBarbers =>
      'Each barber\'s bookings, revenue and how full they are';

  @override
  String get premiumFeatureRegulars =>
      'Returning customers, and regulars you\'re losing';

  @override
  String get premiumFeatureWhatIf =>
      'What-if: try a price change before you make it';

  @override
  String get premiumTagline => 'Your numbers, turned into decisions.';

  @override
  String get tryFree14Days => 'Try it free for 14 days';

  @override
  String getPremium(String price) {
    return 'Get Premium — $price/month';
  }

  @override
  String get cancelFromSettings =>
      'Cancel anytime from Settings › Subscription & billing.';

  @override
  String get noCardForTrial => 'No card needed for the trial.';

  @override
  String get premiumInsights => 'Premium insights';

  @override
  String get whatToDoNext => 'What to do next';

  @override
  String get whatToDoNextSub =>
      'Moves worked out from your own bookings, best first.';

  @override
  String get suggestionsAppear =>
      'Suggestions appear once you have about 10 completed bookings in the last 90 days.';

  @override
  String get profit12Months => 'Profit, last 12 months';

  @override
  String get tapABar => 'Tap a bar for the month\'s figures.';

  @override
  String get chairsBusy => 'When your chairs are busy';

  @override
  String chairsBusySub(String percent) {
    return 'Share of chair time booked, last 8 weeks · overall $percent';
  }

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get customersHeading => 'Customers';

  @override
  String get servicesSub => 'Last 90 days, vs the 90 before';

  @override
  String get whatIf => 'What if…';

  @override
  String whatIfSub(String month) {
    return 'Try a change on $month\'s figures before making it.';
  }

  @override
  String get thisMonth => 'This month';

  @override
  String get thisMonthSub => 'Where you\'re heading at this pace';

  @override
  String get forecastAppears =>
      'A forecast appears once the month is under way.';

  @override
  String freeTrialDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Free trial · $count days left',
      one: 'Free trial · 1 day left',
    );
    return '$_temp0';
  }

  @override
  String keepPremiumFor(String price) {
    return 'Keep Premium for $price/month';
  }

  @override
  String get alreadyCoveredCosts =>
      'You\'ve already covered this month\'s costs.';

  @override
  String breakEvenOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'At this pace you\'ll break even on $dateString.';
  }

  @override
  String get wontCoverCosts =>
      'At this pace you won\'t cover this month\'s costs — see the suggestions below.';

  @override
  String get monthEndForecast => 'Month-end forecast';

  @override
  String projectedProfitOn(String revenue) {
    return 'Projected profit on $revenue revenue';
  }

  @override
  String projectedLossOn(String revenue) {
    return 'Projected loss on $revenue revenue';
  }

  @override
  String alreadyBookedRest(String amount) {
    return '$amount already booked for the rest of the month.';
  }

  @override
  String get basedOnPace =>
      'Based on your pace so far this month and bookings already in the diary.';

  @override
  String gainPerMonthShort(String amount) {
    return '+$amount/mo';
  }

  @override
  String estimate(String text) {
    return 'Estimate: $text';
  }

  @override
  String revenueLine(String amount) {
    return 'Revenue $amount';
  }

  @override
  String costsLine(String amount) {
    return 'Costs $amount';
  }

  @override
  String profitLine(String amount) {
    return 'Profit $amount';
  }

  @override
  String lossLine(String amount) {
    return 'Loss $amount';
  }

  @override
  String get setHoursToSee => 'Set your opening hours and staff to see this.';

  @override
  String heatClosed(String day, int hour) {
    return '$day $hour:00 · closed';
  }

  @override
  String heatBooked(String day, int hour, String percent) {
    return '$day $hour:00 · $percent booked';
  }

  @override
  String get heatEmpty => 'Empty ';

  @override
  String get heatFull => ' Full';

  @override
  String get noStaffYet => 'No staff yet.';

  @override
  String barberStats(int count, Object percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings · $percent of their hours booked',
      one: '1 booking · $percent of their hours booked',
    );
    return '$_temp0';
  }

  @override
  String get statCustomers => 'customers';

  @override
  String get statNew => 'new';

  @override
  String get statReturning => 'returning';

  @override
  String get statCameBack => 'came back*';

  @override
  String get cameBackFootnote =>
      '* Of customers who visited 6–12 weeks ago, the share who have been back since.';

  @override
  String get regularsLosing => 'Regulars you\'re losing';

  @override
  String get regularsLosingSub =>
      'Usually back every few weeks — now well overdue. Worth a message.';

  @override
  String visitsUsually(int visits, int days) {
    return '$visits visits · usually every $days days';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get noCompletedBookings90 =>
      'No completed bookings in the last 90 days.';

  @override
  String serviceStats(int count, String percent, String arrow, int previous) {
    return '$count bookings · $percent of all · $arrow from $previous';
  }

  @override
  String pricesChange(String change) {
    return 'Prices $change';
  }

  @override
  String bookingsChange(String change) {
    return 'Number of bookings $change';
  }

  @override
  String monthActual(String month, String amount) {
    return '$month actual: $amount';
  }

  @override
  String wouldBe(String amount) {
    return 'Would be $amount';
  }

  @override
  String amountAMonth(String amount) {
    return '$amount a month';
  }
}
