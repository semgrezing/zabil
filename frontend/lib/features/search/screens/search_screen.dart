import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../features/groups/providers/groups_provider.dart';
import '../../../features/invitations/services/invitations_service.dart';
import 'package:dio/dio.dart';

// Search result state
class UserSearchResult {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const UserSearchResult({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  String get displayLabel {
    final name = displayName?.trim();
    return name != null && name.isNotEmpty ? name : username;
  }

  String? get avatarResolvedUrl {
    final raw = avatarUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AppConfig.apiOrigin}$raw';
  }
}

final _searchDio = Dio();

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  UserSearchResult? _result;
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String username) async {
    if (username.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _result = null;
      _searchError = null;
    });

    try {
      final dio = ApiClient.create();
      final response = await dio.get(
        ApiEndpoints.usersSearch,
        queryParameters: {'username': username.trim()},
      );
      final user = response.data['user'] as Map<String, dynamic>;
      setState(() {
        _result = UserSearchResult(
          id: user['id'] as String,
          username: user['username'] as String,
          displayName: user['displayName'] as String?,
          avatarUrl: user['avatarUrl'] as String?,
        );
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        setState(() => _searchError = 'Пользователь не найден');
      } else {
        setState(() => _searchError = 'Ошибка поиска');
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendInvite(BuildContext context, String username) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет групп')),
      );
      return;
    }

    String? selectedGroupId;
    if (groups.length == 1) {
      selectedGroupId = groups.first.id;
    } else {
      selectedGroupId = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Выберите группу', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...groups.map(
              (g) => ListTile(
                title: Text(g.title),
                onTap: () => Navigator.pop(ctx, g.id),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    if (selectedGroupId == null) return;

    try {
      await InvitationsService().sendInvitation(selectedGroupId, username);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Приглашение отправлено @$username')),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        final msg = e.response?.data?['error'] ?? 'Ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg as String)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Введите точное имя пользователя...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: _search,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : () => _search(_searchCtrl.text),
                  child: const Text('Найти'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isSearching) const CircularProgressIndicator(strokeWidth: 2),
            if (_searchError != null)
              Text(
                _searchError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_result != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: _result!.avatarResolvedUrl != null
                        ? NetworkImage(_result!.avatarResolvedUrl!)
                        : null,
                    child: _result!.avatarResolvedUrl == null
                        ? Text(_result!.displayLabel[0].toUpperCase())
                        : null,
                  ),
                  title: Text(_result!.displayLabel),
                  subtitle: Text('@${_result!.username}'),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Пригласить'),
                    onPressed: () => _sendInvite(context, _result!.username),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
