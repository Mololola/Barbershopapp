import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/router.dart';
import 'package:mobile/features/auth/domain/profile.dart';

void main() {
  const customerProfile =
      Profile(id: 'u1', role: AccountRole.customer, username: 'alex', referralCode: 'ALEXCODE');
  const businessProfile =
      Profile(id: 'u2', role: AccountRole.business, username: 'fade_kings', referralCode: 'FADECODE');
  const minorProfile = Profile(
    id: 'u3',
    role: AccountRole.customer,
    username: 'sam',
    referralCode: 'SAMCODE',
    isMinor: true,
  );

  test('unauthenticated user is sent to sign-in from any non-auth route', () {
    expect(
      resolveRedirect(
        isAuthenticated: false,
        profile: null,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/customer',
      ),
      '/sign-in',
    );
  });

  test('unauthenticated user is left alone on sign-in/sign-up', () {
    expect(
      resolveRedirect(
        isAuthenticated: false,
        profile: null,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/sign-in',
      ),
      null,
    );
    expect(
      resolveRedirect(
        isAuthenticated: false,
        profile: null,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/sign-up',
      ),
      null,
    );
  });

  test('authenticated with no profile yet is kept on sign-up', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: null,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/customer',
      ),
      '/sign-up',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: null,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/sign-up',
      ),
      null,
    );
  });

  test('authenticated customer is routed to /customer', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/sign-in',
      ),
      '/customer',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/customer',
      ),
      null,
    );
  });

  test('business that has not finished onboarding is sent to business-setup', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/sign-up',
      ),
      '/business-setup',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/business-setup',
      ),
      null,
    );
  });

  test('business that finished onboarding is routed to /business', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        pendingReviewBookingId: null,
        location: '/sign-up',
      ),
      '/business',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        pendingReviewBookingId: null,
        location: '/business-setup',
      ),
      '/business',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        pendingReviewBookingId: null,
        location: '/business',
      ),
      null,
    );
  });

  test('business already set up is left alone on sub-routes like services/staff', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        pendingReviewBookingId: null,
        location: '/business/services',
      ),
      null,
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        pendingReviewBookingId: null,
        location: '/business/staff',
      ),
      null,
    );
  });

  test('customer with a pending review is redirected there from anywhere', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: 'booking-1',
        location: '/customer',
      ),
      '/customer/bookings/booking-1/review',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: 'booking-1',
        location: '/customer/businesses',
      ),
      '/customer/bookings/booking-1/review',
    );
  });

  test('customer is left alone on the review route for their own pending booking', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: 'booking-1',
        location: '/customer/bookings/booking-1/review',
      ),
      null,
    );
  });

  test('password recovery forces the reset-password route from anywhere, even signed out', () {
    expect(
      resolveRedirect(
        isAuthenticated: false,
        profile: null,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/customer',
        passwordRecovery: true,
      ),
      '/reset-password',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/customer',
        passwordRecovery: true,
      ),
      '/reset-password',
    );
  });

  test('password recovery leaves the user alone once on the reset-password route', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/reset-password',
        passwordRecovery: true,
      ),
      null,
    );
  });

  test('a minor account routes exactly like any other customer — no guardian gate', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: minorProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/sign-up',
      ),
      '/customer',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: minorProfile,
        isBusinessSetupComplete: false,
        pendingReviewBookingId: null,
        location: '/customer',
      ),
      null,
    );
  });

  test('a pending review for a business account does not gate business routes', () {
    // pendingReviewBookingId only ever applies to the customer role in
    // practice, but the gate should be inert for a business account anyway.
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        pendingReviewBookingId: 'booking-1',
        location: '/business',
      ),
      null,
    );
  });
}
