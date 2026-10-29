import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';

class ProfileSearchScreen extends ConsumerStatefulWidget {
  const ProfileSearchScreen({super.key});

  @override
  ConsumerState<ProfileSearchScreen> createState() => _ProfileSearchScreenState();
}

class _ProfileSearchScreenState extends ConsumerState<ProfileSearchScreen> {
  final _queryController = TextEditingController();
  List<Profile>? _results;
  bool _isSearching = false;
  Object? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await ref.read(profileRepositoryProvider).searchByUsername(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.findPeople)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(labelText: context.l10n.usernameLabel),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _isSearching ? null : _search,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(describeError(context.l10n, _error)),
            if (_isSearching) const LoadingView(),
            if (results != null)
              Expanded(
                child: results.isEmpty
                    ? Text(context.l10n.noUsersFound)
                    : ListView(
                        children: [
                          for (final profile in results)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                                child: profile.avatarUrl == null ? const Icon(Icons.person) : null,
                              ),
                              title: Text(profile.username),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/profile/${profile.id}'),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
