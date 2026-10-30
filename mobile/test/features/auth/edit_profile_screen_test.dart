import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/data/profile_repository.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/auth/presentation/edit_profile_screen.dart';

class _FakeProfiles extends Fake implements ProfileRepository {
  final saved = <({String displayName, String bio})>[];
  final removed = <String>[];

  @override
  Future<void> updateDetails(String profileId, {required String displayName, required String bio}) async {
    saved.add((displayName: displayName, bio: bio));
  }

  @override
  Future<void> removeAvatar(String profileId, String avatarUrl) async {
    removed.add(avatarUrl);
  }
}

void main() {
  const me = Profile(
    id: 'me',
    role: AccountRole.customer,
    username: 'alex',
    referralCode: 'CODE',
    avatarUrl: 'https://x.supabase.co/storage/v1/object/public/avatars/me/avatar.jpg?v=1',
    displayName: 'Alex',
  );

  Future<_FakeProfiles> pump(WidgetTester tester) async {
    final profiles = _FakeProfiles();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => me),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: const MaterialApp(home: EditProfileScreen()),
    ));
    await tester.pumpAndSettle();
    return profiles;
  }

  testWidgets('the name starts filled in and saving sends what was typed', (tester) async {
    final profiles = await pump(tester);

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Shown above @alex'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Bio (optional)'), 'Fades only.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(profiles.saved, [(displayName: 'Alex', bio: 'Fades only.')]);
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('removing the photo deletes it and says so', (tester) async {
    final profiles = await pump(tester);

    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(profiles.removed, [me.avatarUrl]);
    expect(find.text('Photo removed.'), findsOneWidget);
  });
}
