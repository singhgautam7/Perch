import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/nav_shell.dart';
import '../../features/add_link/link_edit_screen.dart';
import '../../features/folders/folders_screen.dart';
import '../../features/link_detail/link_detail_screen.dart';
import '../../features/links/links_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/appearance_screen.dart';
import '../../features/settings/dev_tools_screen.dart';
import '../../features/settings/data_screen.dart';
import '../../features/settings/more_screen.dart';
import '../../features/settings/permissions_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../../features/settings/tags_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../db/settings_repository.dart';

abstract final class Routes {
  static const String welcome = '/welcome';
  static const String links = '/links';
  static const String folders = '/folders';
  static const String stats = '/stats';
  static const String more = '/more';
  /// Add and Edit are the same route: no id adds, an id edits (board 3b).
  static const String add = '/link/edit';
  static const String search = '/search';

  static const String appearance = '/settings/appearance';
  static const String data = '/settings/data';
  static const String tags = '/settings/tags';
  static const String permissions = '/settings/permissions';
  static const String privacy = '/settings/privacy';
  static const String about = '/settings/about';
  static const String devTools = '/settings/dev';

  static String folder(int id) => '/folders/$id';
  static String link(int id) => '/link/$id';
  static String editLink(int id) => '$add?id=$id';

  /// Search, landing with one tag already applied (board 3c).
  static String tagged(int tagId) => '$search?tag=$tagId';
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
        builder: (BuildContext c, GoRouterState s) {
          final String? id = s.uri.queryParameters['id'];
          return LinkEditScreen(
            linkId: id == null ? null : int.tryParse(id),
            sharedUrl: s.uri.queryParameters['url'],
          );
        },
      ),
      GoRoute(
        path: Routes.stats,
        builder: (BuildContext c, GoRouterState s) => const StatsScreen(),
      ),
      // Settings sub-pages are full screens with their own back, so they sit
      // above the shell rather than inside a branch.
      GoRoute(
        path: Routes.appearance,
        builder: (BuildContext c, GoRouterState s) => const AppearanceScreen(),
      ),
      GoRoute(
        path: Routes.data,
        builder: (BuildContext c, GoRouterState s) => const DataScreen(),
      ),
      GoRoute(
        path: Routes.tags,
        builder: (BuildContext c, GoRouterState s) => const TagsScreen(),
      ),
      GoRoute(
        path: Routes.permissions,
        builder: (BuildContext c, GoRouterState s) =>
            const PermissionsScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (BuildContext c, GoRouterState s) => const PrivacyScreen(),
      ),
      GoRoute(
        path: Routes.about,
        builder: (BuildContext c, GoRouterState s) => const AboutScreen(),
      ),
      GoRoute(
        path: Routes.devTools,
        builder: (BuildContext c, GoRouterState s) => const DevToolsScreen(),
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
                tabCount: shell.route.branches.length,
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
                path: Routes.search,
                builder: (BuildContext c, GoRouterState s) {
                  final String? tag = s.uri.queryParameters['tag'];
                  return SearchScreen(
                    tagId: tag == null ? null : int.tryParse(tag),
                  );
                },
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
