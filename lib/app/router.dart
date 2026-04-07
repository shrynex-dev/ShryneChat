import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/gemini_login_screen.dart';

import '../features/chat/presentation/chat_home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ChatHomeScreen(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const GeminiLoginScreen(),
          ),
          GoRoute(
            path: 'chat/:conversationId',
            builder: (context, state) => ChatHomeScreen(
              conversationId: state.pathParameters['conversationId'],
            ),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
