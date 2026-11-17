import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/catalog/categories_screen.dart';
import '../features/catalog/category_screen.dart';
import '../features/catalog/data/manifest_provider.dart';
import '../features/purchase/data/purchase_providers.dart';
import '../features/purchase/paywall_screen.dart';
import '../features/puzzle/domain/difficulty.dart';
import '../features/puzzle/puzzle_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadePage(state, const CategoriesScreen()),
      ),
      GoRoute(
        path: '/category/:id',
        pageBuilder: (context, state) => _fadePage(
          state,
          CategoryScreen(categoryId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _fadePage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (context, state) => _fadePage(state, const AboutScreen()),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (context, state) => _fadePage(
          state,
          PaywallScreen(
            puzzleId: state.uri.queryParameters['from'],
            difficulty: Difficulty.byName(
              state.uri.queryParameters['difficulty'],
            ),
            gatePassed: state.extra == paywallGatePassed,
          ),
        ),
      ),
      GoRoute(
        path: '/puzzle/:id',
        // A locked picture opens the paywall, which asks the parental gate
        // first and returns to the picture after the purchase.
        // PuzzleController refuses it too, in case the catalog was not
        // loaded yet here.
        redirect: (context, state) {
          final id = state.pathParameters['id']!;
          final entry = ref.read(manifestProvider).value?.puzzleById(id);
          if (entry == null || ref.read(canPlayProvider(entry))) return null;
          return paywallRoute(
            puzzleId: id,
            difficulty: Difficulty.byName(
              state.uri.queryParameters['difficulty'],
            ),
          );
        },
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final difficulty =
              Difficulty.byName(state.uri.queryParameters['difficulty']) ??
              Difficulty.easy;
          return _fadePage(
            state,
            PuzzleScreen(
              key: ValueKey('$id/${difficulty.name}'),
              puzzleId: id,
              difficulty: difficulty,
            ),
          );
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// A short fade with a slight zoom in; instant when the system asks for
/// reduced motion.
Page<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curve = CurveTween(curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: animation.drive(curve),
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(begin: 0.96, end: 1).chain(curve),
            ),
            child: child,
          ),
        );
      },
    );
