import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/messaging/application/messaging_controller.dart';
import 'package:mobile/features/messaging/domain/conversation.dart';
import 'package:mobile/features/messaging/domain/message.dart';
import 'package:mobile/features/messaging/presentation/conversation_screen.dart';

class _FakeMessagingActionController extends MessagingActionController {
  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<void> sendMessage(String conversationId, String body) async {}

  @override
  Future<String> startOrGetConversation(
    String otherProfileId, {
    ConversationType type = ConversationType.personal,
  }) async =>
      'fake-conversation-id';
}

void main() {
  const myProfile = Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');
  final messages = [
    Message(
      id: 'm1',
      conversationId: 'conv-1',
      senderId: 'other-1',
      body: 'Hi there',
      createdAt: DateTime.utc(2026, 8, 1, 10),
    ),
    Message(
      id: 'm2',
      conversationId: 'conv-1',
      senderId: 'me-1',
      body: 'Hello back',
      createdAt: DateTime.utc(2026, 8, 1, 10, 1),
    ),
  ];

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        conversationMessagesProvider('conv-1').overrideWith((ref) => Stream.value(messages)),
        messagingActionControllerProvider.overrideWith(_FakeMessagingActionController.new),
      ],
      child: const MaterialApp(home: ConversationScreen(conversationId: 'conv-1')),
    );
  }

  testWidgets('renders message history with mine right-aligned and theirs left-aligned', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Hello back'), findsOneWidget);

    final theirBubble = tester.widget<Align>(
      find.ancestor(of: find.text('Hi there'), matching: find.byType(Align)),
    );
    expect(theirBubble.alignment, Alignment.centerLeft);

    final myBubble = tester.widget<Align>(
      find.ancestor(of: find.text('Hello back'), matching: find.byType(Align)),
    );
    expect(myBubble.alignment, Alignment.centerRight);
  });

  testWidgets('the header names who you are talking to, and your last message says Read once seen', (tester) async {
    final read = [
      messages.first,
      Message(
        id: 'm2',
        conversationId: 'conv-1',
        senderId: 'me-1',
        body: 'Hello back',
        createdAt: DateTime.utc(2026, 8, 1, 10, 1),
        readAt: DateTime.utc(2026, 8, 1, 10, 2),
      ),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        conversationMessagesProvider('conv-1').overrideWith((ref) => Stream.value(read)),
        messagingActionControllerProvider.overrideWith(_FakeMessagingActionController.new),
        conversationByIdProvider('conv-1').overrideWithValue(const Conversation(
          id: 'conv-1',
          otherParticipantId: 'other-1',
          otherUsername: 'janedoe',
          unreadCount: 0,
          type: ConversationType.personal,
        )),
        profileByIdProvider.overrideWith((ref, id) async => null),
        pendingLeaveRequestsProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: ConversationScreen(conversationId: 'conv-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('janedoe'), findsOneWidget);
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Conversation'), findsNothing);
    expect(find.text('Aug 1'), findsOneWidget);
    expect(find.textContaining('Read'), findsOneWidget);
  });
}
