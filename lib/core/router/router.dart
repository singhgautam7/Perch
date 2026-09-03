import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/nav_shell.dart';
import '../../features/add_link/add_link_screen.dart';
import '../../features/folders/folders_screen.dart';
import '../../features/link_detail/link_detail_screen.dart';
import '../../features/links/links_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/more_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../db/settings_repository.dart';

abstract final class Routes {
  static const String welcome = '/welcome';
  static const String links = '/links';
  static const String folders = '/folders';
  static const String stats = '/stats';
  static const String more = '/more';
  static const String add = '/add';
  static const String search = '/search';

  static String folder(int id) => '/folders/$id';
  static String link(int id) => '/link/$id';
}

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({required AppSettings settings}) {
  final String initial = settings.onboarded
      ? (settings.landingTab == LandingTab.folders
            ? Routes.folders
            : Routes.links)
      : Routes.welcome;

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.welcome,
        builder: (BuildContext c, GoRouterState s) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.add,
        builder: (BuildContext c, GoRouterState s) =>
            AddLinkScreen(sharedUrl: s.uri.queryParameters['url']),
      ),
      GoRoute(
        path: Routes.search,
        builder: (BuildContext c, GoRouterState s) => const SearchScreen(),
      ),
      GoRoute(
        path: '/link/:id',
        builder: (BuildContext c, GoRouterState s) =>
            LinkDetailScreen(linkId: int.parse(s.pathParameters['id']!)),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell shell,
            ) {
              return NavShell(
                index: shell.currentIndex,
                onSelect: (int i) =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
                onAdd: () => context.push(Routes.add),
                child: shell,
              );
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.links,
                builder: (BuildContext c, GoRouterState s) =>
                    const LinksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.folders,
                builder: (BuildContext c, GoRouterState s) =>
                    const FoldersScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    builder: (BuildContext c, GoRouterState s) => FoldersScreen(
                      folderId: int.parse(s.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.stats,
                builder: (BuildContext c, GoRouterState s) =>
                    const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.more,
                builder: (BuildContext c, GoRouterState s) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
