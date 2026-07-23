import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/router.dart';
import 'package:mobile/features/auth/domain/profile.dart';

void main() {
  const customerProfile = Profile(id: 'u1', role: AccountRole.customer, username: 'alex');
  const businessProfile = Profile(id: 'u2', role: AccountRole.business, username: 'fade_kings');

  test('unauthenticated user is sent to sign-in from any non-auth route', () {
    expect(
      resolveRedirect(isAuthenticated: false, profile: null, location: '/customer'),
      '/sign-in',
    );
  });

  test('unauthenticated user is left alone on sign-in/sign-up', () {
    expect(resolveRedirect(isAuthenticated: false, profile: null, location: '/sign-in'), null);
    expect(resolveRedirect(isAuthenticated: false, profile: null, location: '/sign-up'), null);
  });

  test('authenticated with no profile yet is kept on sign-up', () {
    expect(
      resolveRedirect(isAuthenticated: true, profile: null, location: '/customer'),
      '/sign-up',
    );
    expect(resolveRedirect(isAuthenticated: true, profile: null, location: '/sign-up'), null);
  });

  test('authenticated customer is routed to /customer', () {
    expect(
      resolveRedirect(isAuthenticated: true, profile: customerProfile, location: '/sign-in'),
      '/customer',
    );
    expect(
      resolveRedirect(isAuthenticated: true, profile: customerProfile, location: '/customer'),
      null,
    );
  });

  test('authenticated business is routed to /business', () {
    expect(
      resolveRedirect(isAuthenticated: true, profile: businessProfile, location: '/sign-up'),
      '/business',
    );
    expect(
      resolveRedirect(isAuthenticated: true, profile: businessProfile, location: '/business'),
      null,
    );
  });
}
