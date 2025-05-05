// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../routes/router_config.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../widgets/emoticons.dart';
import '../../domain/chapter/chapter_model.dart';
import '../reader/controller/reader_controller.dart';
import '../updates/widgets/chapter_manga_list_tile.dart';
import 'controller/on_deck_controller.dart';


class OnDeckScreen extends ConsumerStatefulWidget {
  const OnDeckScreen({super.key});

  @override
  OnDeckScreenState createState() => OnDeckScreenState();
}

class OnDeckScreenState extends ConsumerState<OnDeckScreen> with AutomaticKeepAliveClientMixin {
  late PagingController<int, ChapterWithMangaDto> _controller;
  Map<int, ChapterWithMangaDto> _selectedChapters = {};
  DateTime? _lastRefreshTime;
  
  @override
  bool get wantKeepAlive => false;  // Don't keep alive to ensure refresh on revisit
  
  @override
  void initState() {
    super.initState();
    _controller = PagingController<int, ChapterWithMangaDto>(firstPageKey: 0);
    _controller.addPageRequestListener(_fetchPage);
    
    // Force refresh when first mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceRefresh();
    });
  }
  
  // Listen for route changes instead of didChangeDependencies
  // This is more reliable for detecting when user navigates to this screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Manual refresh on first entry
    if (_firstEntry) {
      _firstEntry = false;
      _forceRefresh();
    }
  }
  
  bool _firstEntry = true;
  String? _previousRoute;
  
  void _fetchPage(int pageKey) {
    ref.read(onDeckControllerProvider.notifier).fetchInProgressChapters(
      pageKey: pageKey,
      controller: _controller,
      forceRefresh: pageKey == 0 // Always force refresh the first page
    );
  }
  
  void _forceRefresh() {
    // Only refresh if it's been more than 1 second since last refresh
    final now = DateTime.now();
    if (_lastRefreshTime == null || now.difference(_lastRefreshTime!).inSeconds > 1) {
      _lastRefreshTime = now;
      
      // Clear selected chapters
      setState(() {
        _selectedChapters = {};
      });
      
      // Invalidate the provider to clear any cached data
      ref.invalidate(onDeckControllerProvider);
      
      // Reset and refresh the controller
      _controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Watch for route changes using our custom router observer
    final currentRoute = ref.watch(currentRouteProvider);
    
    // Check if we navigated to the On Deck page from somewhere else
    if (currentRoute == Routes.onDeck && _previousRoute != Routes.onDeck) {
      // Delay refresh to avoid initialization issues
      Future.microtask(() => _forceRefresh());
    }
    
    // Store current route for next comparison
    _previousRoute = currentRoute;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.onDeck),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // This will be called when the user manually pulls to refresh
          _forceRefresh();
          // Wait for at least 300ms for the UI effect
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: PagedListView(
          pagingController: _controller,
          builderDelegate: PagedChildBuilderDelegate<ChapterWithMangaDto>(
            firstPageProgressIndicatorBuilder: (context) =>
                const CenterSorayomiShimmerIndicator(),
            firstPageErrorIndicatorBuilder: (context) => Emoticons(
              title: _controller.error.toString(),
              button: TextButton(
                onPressed: _forceRefresh,
                child: Text(context.l10n.retry),
              ),
            ),
            noItemsFoundIndicatorBuilder: (context) => Emoticons(
              title: context.l10n.noMangaInProgress,
              button: TextButton(
                onPressed: _forceRefresh,
                child: Text(context.l10n.refresh),
              ),
            ),
            itemBuilder: (context, item, index) {
              return ChapterMangaListTile(
                chapterWithMangaDto: item,
                updatePair: () async {
                  final chapter = await ref
                      .refresh(chapterProvider(chapterId: item.id).future);
                  try {
                    if (chapter != null) {
                      setState(() {
                        _controller.itemList = [...?_controller.itemList]
                          ..replaceRange(index, index + 1, [
                            item,
                          ]);
                      });
                    }
                  } catch (e) {
                    //
                  }
                },
                isSelected: _selectedChapters.containsKey(item.id),
                canTapSelect: _selectedChapters.isNotEmpty,
                toggleSelect: (ChapterWithMangaDto val) {
                  if ((val.id).isNull) return;
                  setState(() {
                    _selectedChapters = _selectedChapters.toggleKey(val.id, val);
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}