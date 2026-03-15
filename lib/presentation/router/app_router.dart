import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../library/library_screen.dart';
import '../browse/browse_screen.dart';
import '../updates/updates_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../manga_detail/manga_detail_screen.dart';
import '../reader/reader_screen.dart';
import '../browse/source_catalog_screen.dart';

part 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.library,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithBottomNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: Routes.library,
            builder: (context, state) => const LibraryScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: Routes.browse,
            builder: (context, state) => const BrowseScreen(),
            routes: [
              GoRoute(
                path: 'source/:sourceId',
                builder: (context, state) => SourceCatalogScreen(
                  sourceId: state.pathParameters['sourceId']!,
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: Routes.updates,
            builder: (context, state) => const UpdatesScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: Routes.history,
            builder: (context, state) => const HistoryScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ]),
      ],
    ),

    // Full-screen routes (outside bottom nav)
    GoRoute(
      path: Routes.mangaDetail,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return MangaDetailScreen(
          mangaUrl: extra['mangaUrl'] as String,
          sourceId: extra['sourceId'] as String,
          mangaId: extra['mangaId'] as int?,
        );
      },
    ),
    GoRoute(
      path: Routes.reader,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ReaderScreen(
          chapterId: extra['chapterId'] as int,
          mangaId: extra['mangaId'] as int,
        );
      },
    ),
  ],
);

class _ScaffoldWithBottomNav extends StatelessWidget {
  const _ScaffoldWithBottomNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.collections_bookmark_outlined),
            selectedIcon: const Icon(Icons.collections_bookmark),
            label: l10n.library,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.browse,
          ),
          NavigationDestination(
            icon: const Icon(Icons.new_releases_outlined),
            selectedIcon: const Icon(Icons.new_releases),
            label: l10n.updates,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
