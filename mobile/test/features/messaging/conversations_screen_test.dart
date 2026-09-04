import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messaging/application/messaging_controller.dart';
import 'package:mobile/features/messaging/domain/conversation.dart';
import 'package:mobile/features/messaging/presentation/conversations_screen.dart';

void main() {
  final conversations = [
    Conversation(
      id: 'conv-1',
      otherParticipantId: 'other-1',
      otherUsername: 'janedoe',
      lastMessageBody: 'See you Friday!',
      lastMessageAt: DateTime.utc(2026, 8, 1),
      unreadCount: 2,
      type: ConversationType.personal,
    ),
    const Conversation(
      id: 'conv-2',
      otherParticipantId: 'other-2',
      otherUsername: 'newshop',
      unreadCount: 0,
      type: ConversationType.personal,
    ),
  ];

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        conversationsProvider.overrideWith((ref) async => conversations),
      ],
      child: const MaterialApp(home: ConversationsScreen()),
    );
  }

  testWidgets('lists conversations with last message preview and unread badge', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('janedoe'), findsOneWidget);
    expect(find.text('See you Friday!'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    expect(find.text('newshop'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
  });
}
