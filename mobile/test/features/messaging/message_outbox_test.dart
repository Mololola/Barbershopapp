import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/offline_cache.dart';
import 'package:mobile/core/supabase_providers.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/messaging/application/messaging_controller.dart';
import 'package:mobile/features/messaging/data/messaging_repository.dart';
import 'package:mobile/features/messaging/domain/conversation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepository extends Fake implements MessagingRepository {
  bool online = false;
  final sent = <String>[];

  @override
  Future<void> sendMessage(String conversationId, String senderId, String body) async {
    if (!online) throw http.ClientException('no connection');
    sent.add(body);
  }

  @override
  Future<List<Conversation>> fetchConversations(String myId) async => [];
}

void main() {
  test('a message written offline waits on the phone and goes out once back online', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeRepository();
    final container = ProviderContainer(
      overrides: [
        currentAuthUserIdProvider.overrideWithValue('me'),
        authStateChangesProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
        currentProfileProvider.overrideWith(
          (ref) async => const Profile(id: 'me', role: AccountRole.customer, username: 'me', referralCode: 'C'),
        ),
        messagingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(messageOutboxProvider, (_, _) {});

    await container.read(messagingActionControllerProvider.notifier).sendMessage('c1', 'hola');
    expect(container.read(messagingActionControllerProvider).hasError, isFalse);
    expect((await container.read(messageOutboxProvider.future)).single.body, 'hola');
    expect(container.read(connectionProvider).online, isFalse);

    repository.online = true;
    container.read(connectionProvider.notifier).reportOnline();
    expect(await container.read(messageOutboxProvider.future), isEmpty);
    expect(repository.sent, ['hola']);
  });
}
