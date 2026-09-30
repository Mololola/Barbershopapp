import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/messaging/application/messaging_controller.dart';
import 'package:mobile/features/messaging/domain/conversation.dart';
import 'package:mobile/features/messaging/presentation/messages_button.dart';

Conversation _chat(String id, int unread) => Conversation(
      id: id,
      otherParticipantId: 'p-$id',
      otherUsername: 'user$id',
      unreadCount: unread,
      type: ConversationType.personal,
    );

void main() {
  const adult = Profile(id: 'me', role: AccountRole.business, username: 'mle', referralCode: 'C');
  const minor = Profile(id: 'kid', role: AccountRole.customer, username: 'sam', referralCode: 'C', isMinor: true);

  Widget buildTestable(Profile profile, List<Conversation> chats) {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        conversationsProvider.overrideWith((ref) async => chats),
      ],
      child: MaterialApp(home: Scaffold(appBar: AppBar(actions: const [MessagesButton()]))),
    );
  }

  testWidgets('badge counts chats with unread messages, not messages', (tester) async {
    await tester.pumpWidget(buildTestable(adult, [_chat('a', 5), _chat('b', 1), _chat('c', 0)]));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows 9+ past nine unread chats', (tester) async {
    await tester.pumpWidget(buildTestable(adult, [for (var i = 0; i < 12; i++) _chat('$i', 1)]));
    await tester.pumpAndSettle();

    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('no badge when everything is read', (tester) async {
    await tester.pumpWidget(buildTestable(adult, [_chat('a', 0)]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('hidden entirely for an under-18 account (no direct messages)', (tester) async {
    await tester.pumpWidget(buildTestable(minor, [_chat('a', 3)]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
  });
}
