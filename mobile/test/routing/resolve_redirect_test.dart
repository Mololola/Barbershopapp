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
        location: '/sign-in',
      ),
      null,
    );
    expect(
      resolveRedirect(
        isAuthenticated: false,
        profile: null,
        isBusinessSetupComplete: false,
        location: '/sign-up',
      ),
      null,
    );
  });

  test('authenticated with no profile row is sent to finish sign-up, even from sign-in', () {
    for (final location in ['/customer', '/sign-in']) {
      expect(
        resolveRedirect(
          isAuthenticated: true,
          profile: null,
          isProfileMissing: true,
          isBusinessSetupComplete: false,
          location: location,
        ),
        '/sign-up',
        reason: location,
      );
    }
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: null,
        isProfileMissing: true,
        isBusinessSetupComplete: false,
        location: '/sign-up',
      ),
      null,
    );
  });

  test('authenticated while the profile is still loading (or failed) is not sent to sign-up', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: null,
        isBusinessSetupComplete: false,
        location: '/sign-in',
      ),
      null,
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: null,
        isBusinessSetupComplete: false,
        location: '/customer',
      ),
      '/sign-in',
    );
  });

  test('authenticated customer is routed to /customer', () {
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
        location: '/sign-in',
      ),
      '/customer',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: customerProfile,
        isBusinessSetupComplete: false,
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
        location: '/sign-up',
      ),
      '/business-setup',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: false,
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
        location: '/sign-up',
      ),
      '/business',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        location: '/business-setup',
      ),
      '/business',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
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
        location: '/business/services',
      ),
      null,
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: businessProfile,
        isBusinessSetupComplete: true,
        location: '/business/staff',
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
        location: '/sign-up',
      ),
      '/customer',
    );
    expect(
      resolveRedirect(
        isAuthenticated: true,
        profile: minorProfile,
        isBusinessSetupComplete: false,
        location: '/customer',
      ),
      null,
    );
  });

  group('admin second factor', () {
    const adminProfile =
        Profile(id: 'u4', role: AccountRole.customer, username: 'owner', referralCode: 'OWNERCODE', isAdmin: true);

    test('an admin without their second factor can only reach the two-step screen', () {
      for (final location in ['/customer', '/admin', '/rewards']) {
        expect(
          resolveRedirect(
            isAuthenticated: true,
            profile: adminProfile,
            isBusinessSetupComplete: false,
            location: location,
            needsSecondFactor: true,
          ),
          '/two-factor',
        );
      }
    });

    test('once verified, the two-step screen sends an admin home', () {
      expect(
        resolveRedirect(
          isAuthenticated: true,
          profile: adminProfile,
          isBusinessSetupComplete: false,
          location: '/two-factor',
        ),
        '/customer',
      );
    });
  });
}
