import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/about/presentation/about/about_screen.dart';
import '../features/browse_center/domain/source/source_model.dart';
import '../features/browse_center/presentation/browse/browse_screen.dart';
import '../features/browse_center/presentation/extension/extension_screen.dart';
import '../features/browse_center/presentation/global_search/global_search_screen.dart';
import '../features/browse_center/presentation/source/source_screen.dart';
import '../features/browse_center/presentation/source_manga_list/source_manga_list_screen.dart';
import '../features/browse_center/presentation/source_preference/source_preference_screen.dart';
import '../features/library/presentation/category/edit_category_screen.dart';
import '../features/library/presentation/library/library_screen.dart';
import '../features/manga_book/presentation/downloads/downloads_screen.dart';
import '../features/manga_book/presentation/manga_details/manga_details_screen.dart';
import '../features/manga_book/presentation/on_deck/on_deck_screen.dart';
import '../features/manga_book/presentation/reader/reader_screen.dart';
import '../features/manga_book/presentation/updates/updates_screen.dart';
import '../features/manga_book/widgets/update_status_summary_sheet.dart';
import '../features/quick_open/presentation/search_stack/search_stack_screen.dart';
import '../features/settings/presentation/appearance/appearance_screen.dart';
import '../features/settings/presentation/backup/backup_screen.dart';
import '../features/settings/presentation/browse/browse_settings_screen.dart';
import '../features/settings/presentation/browse/widgets/extension_repository/extension_repository_screen.dart';
import '../features/settings/presentation/downloads/downloads_settings_screen.dart';
import '../features/settings/presentation/general/general_screen.dart';
import '../features/settings/presentation/library/library_settings_screen.dart';
import '../features/settings/presentation/more/more_screen.dart';
import '../features/settings/presentation/reader/reader_settings_screen.dart';
import '../features/settings/presentation/server/server_screen.dart';
import '../features/settings/presentation/settings/settings_screen.dart';
import '../utils/extensions/custom_extensions.dart';
import '../widgets/shell/navigation_shell_screen.dart';

part 'router_config.g.dart';
part 'sub_routes/browser_routes.dart';
part 'sub_routes/common_routes.dart';
part 'sub_routes/downloads_routes.dart';
part 'sub_routes/library_routes.dart';
part 'sub_routes/more_routes.dart';
part 'sub_routes/on_deck_routes.dart';
part 'sub_routes/updates_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _quickOpenNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'Quick Open');

final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final _browseNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'browse');

abstract class Routes {
  static const library = '/library/:categoryId';

  static const onDeck = '/on-deck';

  static const updates = '/updates';

  static const downloads = '/downloads';

  static const extensionRoute = '/extension';
  static const source = '/source';
  static const sourceManga = ':sourceId';
  static const sourceMangaType = '$sourceManga/:sourceType';
  static const sourcePreference = '$sourceManga/preference';

  // More
  static const more = '/more';
  static const settings = 'settings';
  static const librarySettings = 'library';
  static const editCategories = 'edit-categories';
  static const browseSettings = 'browse';
  static const extensionRepositorySettings = 'repo';
  static const readerSettings = 'reader';
  static const appearanceSettings = 'appearance';
  static const generalSettings = 'general';
  static const backup = 'backup';
  static const serverSettings = 'server';
  static const downloadsSettings = 'downloads';

  // Commons
  static const mangaRoute = '/manga/:mangaId';
  static const reader = 'chapter/:chapterId';
  static const updateStatus = "/update-status";
  static const about = 'about';
  static const globalSearch = '/global-search';
}

// Observer for router changes
class GoRouterObserver extends NavigatorObserver {
  final void Function(Route<dynamic>?, Route<dynamic>?) onRouteChange;
  
  GoRouterObserver({required this.onRouteChange});
  
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onRouteChange(route, previousRoute);
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onRouteChange(route, previousRoute);
  }
  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onRouteChange(newRoute, oldRoute);
  }
}

// Provider to expose the current route
final currentRouteProvider = StateProvider<String?>((ref) => null);

@riverpod
GoRouter routerConfig(ref) {
  final observer = GoRouterObserver(
    onRouteChange: (route, previousRoute) {
      if (route != null) {
        // Update current route provider when navigation occurs
        ref.read(currentRouteProvider.notifier).state = route.settings.name;
      }
    }
  );
  
  return GoRouter(
    routes: $appRoutes,
    debugLogDiagnostics: true,
    initialLocation: const OnDeckRoute().location,
    navigatorKey: rootNavigatorKey,
    observers: [observer],
  );
}

@TypedShellRoute<QuickSearchRoute>(
  routes: [
    TypedStatefulShellRoute<NavigationShellRoute>(
      branches: [
        TypedStatefulShellBranch<OnDeckBranch>(
          routes: [TypedGoRoute<OnDeckRoute>(path: Routes.onDeck)],
        ),
        TypedStatefulShellBranch<LibraryBranch>(
          routes: [
            TypedGoRoute<LibraryRoute>(
              path: Routes.library,
              routes: [],
            ),
          ],
        ),
        TypedStatefulShellBranch<UpdatesBranch>(
          routes: [TypedGoRoute<UpdatesRoute>(path: Routes.updates)],
        ),
        TypedStatefulShellBranch<BrowserBranch>(
          routes: [
            TypedStatefulShellRoute<BrowseShellRoute>(
              branches: [
                TypedStatefulShellBranch<BrowseSourceBranch>(
                  routes: [
                    TypedGoRoute<BrowseSourceRoute>(
                      path: Routes.source,
                      routes: [
                        TypedGoRoute<SourcePreferenceRoute>(
                          path: Routes.sourcePreference,
                        ),
                        TypedGoRoute<SourceTypeRoute>(
                          path: Routes.sourceMangaType,
                        ),
                      ],
                    ),
                  ],
                ),
                TypedStatefulShellBranch<BrowseExtensionBranch>(
                  routes: [
                    TypedGoRoute<BrowseExtensionRoute>(
                      path: Routes.extensionRoute,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        TypedStatefulShellBranch<DownloadsBranch>(
          routes: [TypedGoRoute<DownloadsRoute>(path: Routes.downloads)],
        ),
        TypedStatefulShellBranch<MoreBranch>(
          routes: [
            TypedGoRoute<MoreRoute>(
              path: Routes.more,
              routes: [
                TypedGoRoute<AboutRoute>(path: Routes.about),
                TypedGoRoute<SettingsRoute>(
                  path: Routes.settings,
                  routes: [
                    TypedGoRoute<LibrarySettingsRoute>(
                      path: Routes.librarySettings,
                      routes: [
                        TypedGoRoute<EditCategoriesRoute>(
                            path: Routes.editCategories)
                      ],
                    ),
                    TypedGoRoute<ServerSettingsRoute>(
                        path: Routes.serverSettings),
                    TypedGoRoute<ReaderSettingsRoute>(
                        path: Routes.readerSettings),
                    TypedGoRoute<AppearanceSettingsRoute>(
                        path: Routes.appearanceSettings),
                    TypedGoRoute<GeneralSettingsRoute>(
                        path: Routes.generalSettings),
                    TypedGoRoute<BrowseSettingsRoute>(
                      path: Routes.browseSettings,
                      routes: [
                        TypedGoRoute<ExtensionRepositoryRoute>(
                            path: Routes.extensionRepositorySettings)
                      ],
                    ),
                    TypedGoRoute<BackupRoute>(path: Routes.backup),
                    TypedGoRoute<DownloadsSettingsRoute>(
                        path: Routes.downloadsSettings),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    TypedGoRoute<MangaRoute>(
      path: Routes.mangaRoute,
      routes: [TypedGoRoute<ReaderRoute>(path: Routes.reader)],
    ),
    TypedGoRoute<UpdateStatusRoute>(path: Routes.updateStatus),
    TypedGoRoute<GlobalSearchRoute>(path: Routes.globalSearch),
  ],
)
@immutable
class QuickSearchRoute extends ShellRouteData {
  const QuickSearchRoute();

  static final $navigatorKey = _quickOpenNavigatorKey;

  @override
  Widget builder(context, state, navigator) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: FlexColorScheme.themedSystemNavigationBar(
          context,
          systemNavBarStyle: FlexSystemNavBarStyle.background,
          useDivider: false,
          opacity: 0.60,
        ),
        child: SearchStackScreen(child: navigator),
      );
}

// Shell Routes
class NavigationShellRoute extends StatefulShellRouteData {
  const NavigationShellRoute();

  static final $navigatorKey = _shellNavigatorKey;

  @override
  Widget builder(context, state, navigationShell) =>
      NavigationShellScreen(child: navigationShell);
}
