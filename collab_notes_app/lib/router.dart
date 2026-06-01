import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/notes/screens/notes_list_screen.dart';
import '../features/notes/screens/note_editor_screen.dart';
import '../features/chats/screens/chats_list_screen.dart';
import '../features/chats/screens/chat_screen.dart';
import '../features/chats/screens/chat_user_profile_screen.dart';
import '../features/groups/screens/group_detail_screen.dart';
import '../features/groups/screens/groups_list_screen.dart';
import '../features/invitations/screens/invitations_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/activity/screens/activity_feed_screen.dart';
import '../shared/widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Router is created once; redirect re-evaluates via _AuthNotifier.
  // ref.read is used so we always get the current state, not a stale closure.
  return GoRouter(
    initialLocation: '/notes',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      // Don't redirect while auth state is loading (avoids flicker on startup)
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
      final isSessionInvalidated = ApiClient.sessionInvalidated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isSessionInvalidated && !isAuthRoute) return '/login';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/notes';
      return null;
    },
    refreshListenable: _AuthNotifier(ref),
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/notes',
            builder: (_, __) => const NotesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const NoteEditorScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => NoteEditorScreen(
                  noteId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/chats',
            builder: (_, __) => const ChatsListScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),

      // Invitations (full-screen, accessible from settings)
      GoRoute(
        path: '/invitations',
        builder: (_, __) => const InvitationsScreen(),
      ),
      // User search (full-screen, accessible from settings)
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      // Activity feed (full-screen, accessible from settings)
      GoRoute(
        path: '/activity',
        builder: (_, __) => const ActivityFeedScreen(),
      ),
      // User profile (from personal chat header)
      GoRoute(
        path: '/users/:id',
        builder: (_, state) => ChatUserProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),

      // Group detail (modal/full page)
      GoRoute(
        path: '/groups/:id',
        builder: (_, state) => GroupDetailScreen(
          groupId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/groups',
        builder: (_, __) => const GroupsListScreen(),
      ),
      GoRoute(
        path: '/chats/group/:groupId',
        builder: (_, state) {
          final title = state.uri.queryParameters['title'] ?? 'Группа';
          return ChatScreen(
            groupId: state.pathParameters['groupId']!,
            title: title,
          );
        },
      ),
      GoRoute(
        path: '/chats/personal/:userId',
        builder: (_, state) {
          final username = state.uri.queryParameters['username'] ?? 'Пользователь';
          return ChatScreen(
            userId: state.pathParameters['userId']!,
            title: username,
          );
        },
      ),
      GoRoute(
        path: '/chats/note/:noteId',
        builder: (_, state) {
          final groupId = state.uri.queryParameters['groupId'];
          final title = state.uri.queryParameters['title'] ?? 'Заметка';
          final groupTitle = state.uri.queryParameters['groupTitle'];
          if (groupId == null || groupId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Не указан groupId для чата заметки')),
            );
          }
          return ChatScreen(
            groupId: groupId,
            noteId: state.pathParameters['noteId']!,
            title: title,
            subtitle: groupTitle,
          );
        },
      ),
    ],
  );
});

// Makes GoRouter re-evaluate redirects on auth state change
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ApiClient.sessionEpoch.addListener(_onSessionEpochChanged);
  }

  void _onSessionEpochChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    ApiClient.sessionEpoch.removeListener(_onSessionEpochChanged);
    super.dispose();
  }
}
