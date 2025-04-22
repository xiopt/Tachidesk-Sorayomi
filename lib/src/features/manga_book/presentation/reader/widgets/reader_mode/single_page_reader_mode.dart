// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../constants/app_constants.dart';
import '../../../../../../utils/extensions/cache_manager_extensions.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
import '../../../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../../../widgets/server_image.dart';
import '../../../../../settings/presentation/reader/widgets/reader_auto_next_chapter_tile/reader_auto_next_chapter_tile.dart';
import '../../../../../settings/presentation/reader/widgets/reader_continuous_reading_tile/reader_continuous_reading_tile.dart';
import '../../../../../settings/presentation/reader/widgets/reader_pinch_to_zoom/reader_pinch_to_zoom.dart';
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../data/manga_book/manga_book_repository.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_batch/chapter_batch_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../../manga_details/controller/manga_details_controller.dart';
import '../../../reader/controller/reader_controller.dart';
import '../chapter_transition_indicator.dart';
import '../next_chapter_notice.dart';
import '../reader_wrapper.dart';

class HorizontalMultiChapterPageItem {
  final int chapterId;
  final int pageIndex;
  final ChapterPagesDto chapterPages;
  final ChapterDto chapter;
  final bool isTransitionIndicator;
  final bool isPreviousChapter;

  HorizontalMultiChapterPageItem({
    required this.chapterId,
    required this.pageIndex,
    required this.chapterPages,
    required this.chapter,
    this.isTransitionIndicator = false,
    this.isPreviousChapter = false,
  });
}

class SinglePageReaderMode extends HookConsumerWidget {
  const SinglePageReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    this.onPageChanged,
    this.reverse = false,
    this.scrollDirection = Axis.horizontal,
    this.showReaderLayoutAnimation = false,
  });

  final MangaDto manga;
  final ChapterDto chapter;
  final ValueSetter<int>? onPageChanged;
  final bool reverse;
  final Axis scrollDirection;
  final bool showReaderLayoutAnimation;
  final ChapterPagesDto chapterPages;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoNextChapter = ref.watch(autoNextChapterToggleProvider).ifNull();
    final continuousReading = ref.watch(continuousReadingToggleProvider).ifNull();
    final cacheManager = useMemoized(() => DefaultCacheManager());
    
    // Store the current chapter and page
    final currentChapter = useState<ChapterDto>(chapter);
    
    // Track if the component is mounted to prevent state updates after disposal
    final isMounted = useRef(true);
    useEffect(() {
      return () {
        isMounted.value = false;
      };
    }, []);
    
    // Stores all loaded chapters and their pages
    final loadedChapters = useState<Map<int, ChapterPagesDto>>({chapter.id: chapterPages});
    
    // Track all pages across chapters for continuous reading
    final allPages = useState<List<HorizontalMultiChapterPageItem>>([]);
    
    // Add a locking mechanism to prevent unwanted chapter switches during initialization
    final chapterLocked = useState(true);
    
    // Initialize the page controller with the current chapter's page
    final initialPageIndex = chapter.isRead.ifNull()
        ? 0
        : chapter.lastPageRead.getValueOnNullOrNegative();
    
    // This is for calculating the proper page index in the PageView
    final pageOffset = useState(0); 
    
    // Create the page controller with the combined page count
    final scrollController = usePageController(
      initialPage: initialPageIndex,
    );
    
    final currentIndex = useState(initialPageIndex);
    
    // Get next and previous chapters for original chapter on initial load
    final initialNextPrevChapterPair = ref.watch(
      getNextAndPreviousChaptersProvider(
        mangaId: manga.id,
        chapterId: chapter.id, // Always use the original chapter for the initial load
      ),
    );
    
    // Watch for chapters relative to the current chapter being viewed (for UI updates)
    final currentNextPrevChapterPair = ref.watch(
      getNextAndPreviousChaptersProvider(
        mangaId: manga.id,
        chapterId: currentChapter.value.id,
      ),
    );
    
    // Component initialization flag
    final isInitialized = useRef(false);
    
    // Initialize page items for this chapter
    useEffect(() {
      debugPrint("🔄 Initializing chapter ${chapter.name} (ID: ${chapter.id})");
      
      // Ensure we lock the chapter first before anything else
      chapterLocked.value = true;
      
      // Clear all state completely to ensure we're starting fresh
      loadedChapters.value = {chapter.id: chapterPages};
      currentChapter.value = chapter;
      pageOffset.value = 0;
      
      // Create initial pages for just this chapter
      final initialPages = List.generate(
        chapterPages.chapter.pageCount,
        (index) => HorizontalMultiChapterPageItem(
          chapterId: chapter.id,
          pageIndex: index,
          chapterPages: chapterPages,
          chapter: chapter,
        ),
      );
      
      allPages.value = initialPages;
      
      // Unlock the chapter after a delay to prevent unwanted transitions
      Future.delayed(const Duration(seconds: 3), () {
        if (!isMounted.value) return;
        
        if (chapterLocked.value == true) {
          chapterLocked.value = false;
          debugPrint("🔓 Chapter unlocked for navigation");
        }
      });
      
      isInitialized.value = true;
      return null;
    }, [chapter.id]);
    
    // Load next chapter when needed
    final loadNextChapter = useCallback(({dynamic chapterPair}) async {
      // Use provided chapterPair if given, otherwise use current
      final nextPrevPair = chapterPair ?? currentNextPrevChapterPair;
      
      if (!continuousReading || nextPrevPair?.first == null) {
        return;
      }
      
      final nextChapter = nextPrevPair.first!;
      final nextChapterId = nextChapter.id;
      
      // Validate that this is truly the next chapter (higher chapter number)
      if (nextChapter.chapterNumber <= chapter.chapterNumber) {
        return; // Skip if not a higher chapter number to avoid loading wrong chapters
      }
      
      // Skip if already loaded
      if (loadedChapters.value.containsKey(nextChapterId)) {
        return;
      }
      
      debugPrint("⏳ Loading next chapter: ${nextChapter.name}");
      
      // Fetch next chapter
      final nextChapterPages = await ref.read(
        chapterPagesProvider(chapterId: nextChapterId).future,
      );
      
      // Safety check: verify widget is still mounted
      if (!isMounted.value || nextChapterPages == null) return;
      
      try {
        // Add to loaded chapters
        final updatedChapters = Map<int, ChapterPagesDto>.from(loadedChapters.value);
        updatedChapters[nextChapterId] = nextChapterPages;
        
        // Safety check again before updating state
        if (!isMounted.value) return;
        loadedChapters.value = updatedChapters;
        
        // Create transition indicator
        final transitionItem = HorizontalMultiChapterPageItem(
          chapterId: nextChapterId,
          pageIndex: -1,
          chapterPages: nextChapterPages,
          chapter: nextChapter,
          isTransitionIndicator: true,
          isPreviousChapter: false,
        );
        
        // Create page items for next chapter
        final nextChapterItems = List.generate(
          nextChapterPages.chapter.pageCount,
          (index) => HorizontalMultiChapterPageItem(
            chapterId: nextChapterId,
            pageIndex: index,
            chapterPages: nextChapterPages,
            chapter: nextChapter,
          ),
        );
        
        // Final safety check before updating pages
        if (!isMounted.value) return;
        
        // Add transition and next chapter pages
        allPages.value = [
          ...allPages.value,
          transitionItem,
          ...nextChapterItems,
        ];
        
        debugPrint("✅ Loaded next chapter ${nextChapter.name} with ${nextChapterItems.length} pages");
      } catch (e) {
        // If an error occurs (like widget disposed), log it but don't crash
        debugPrint("⚠️ Error loading next chapter: $e");
      }
    }, [continuousReading, currentNextPrevChapterPair, loadedChapters.value]);
    
    // Load previous chapter when needed
    final loadPreviousChapter = useCallback(({dynamic chapterPair}) async {
      // Use provided chapterPair if given, otherwise use current
      final nextPrevPair = chapterPair ?? currentNextPrevChapterPair;
      
      if (!continuousReading || nextPrevPair?.second == null) {
        return;
      }
      
      final prevChapter = nextPrevPair.second!;
      final prevChapterId = prevChapter.id;
      
      // Validate that this is truly the previous chapter (lower chapter number)
      if (prevChapter.chapterNumber >= chapter.chapterNumber) {
        return; // Skip if not a lower chapter number to avoid loading wrong chapters
      }
      
      // Skip if already loaded
      if (loadedChapters.value.containsKey(prevChapterId)) {
        return;
      }
      
      debugPrint("⏳ Loading previous chapter: ${prevChapter.name}");
      
      // Fetch previous chapter
      final prevChapterPages = await ref.read(
        chapterPagesProvider(chapterId: prevChapterId).future,
      );
      
      // Safety check: verify widget is still mounted
      if (!isMounted.value || prevChapterPages == null) return;
      
      try {
        // Add to loaded chapters
        final updatedChapters = Map<int, ChapterPagesDto>.from(loadedChapters.value);
        updatedChapters[prevChapterId] = prevChapterPages;
        
        // Safety check again before updating state
        if (!isMounted.value) return;
        loadedChapters.value = updatedChapters;
        
        // Create transition indicator
        final transitionItem = HorizontalMultiChapterPageItem(
          chapterId: prevChapterId,
          pageIndex: -1,
          chapterPages: prevChapterPages,
          chapter: prevChapter,
          isTransitionIndicator: true,
          isPreviousChapter: true,
        );
        
        // Create page items for previous chapter
        final prevChapterItems = List.generate(
          prevChapterPages.chapter.pageCount,
          (index) => HorizontalMultiChapterPageItem(
            chapterId: prevChapterId,
            pageIndex: index,
            chapterPages: prevChapterPages,
            chapter: prevChapter,
          ),
        );
        
        // Update the page offset to account for the new pages added at the beginning
        final newOffset = prevChapterItems.length + 1; // +1 for transition indicator
        
        // Safety check before updating offset
        if (!isMounted.value) return;
        pageOffset.value += newOffset;
        
        // Safety check before updating pages
        if (!isMounted.value) return;
        
        // Add transition and previous chapter pages at the beginning
        allPages.value = [
          ...prevChapterItems,
          transitionItem,
          ...allPages.value,
        ];
        
        // Adjust the page controller to maintain the current visual position
        if (isMounted.value && scrollController.hasClients) {
          final currentPosition = scrollController.page ?? 0;
          scrollController.jumpToPage(currentPosition.toInt() + newOffset);
        }
        
        debugPrint("✅ Loaded previous chapter ${prevChapter.name} with ${prevChapterItems.length} pages");
      } catch (e) {
        // If an error occurs (like widget disposed), log it but don't crash
        debugPrint("⚠️ Error loading previous chapter: $e");
      }
    }, [continuousReading, currentNextPrevChapterPair, loadedChapters.value]);
    
    // Pre-load next chapter if continuous reading is enabled
    useEffect(() {
      if (!continuousReading) return null;
      
      // Add a delay before loading next chapter to prevent race conditions
      final timer = Timer(const Duration(seconds: 2), () {
        // Check if widget is still mounted before updating state
        if (!isMounted.value) return;
        
        try {
          // ONLY load the next chapter, NEVER the previous one on initial load
          if (initialNextPrevChapterPair?.first != null) {
            debugPrint("⏳ Preloading next chapter: ${initialNextPrevChapterPair!.first!.name}");
            loadNextChapter(chapterPair: initialNextPrevChapterPair);
          }
        } catch (e) {
          // If an error occurs, log it but don't crash
          debugPrint("⚠️ Error preloading next chapter: $e");
        }
      });
      
      return () {
        timer.cancel();
        // When this effect is cleaned up, ensure we don't try to update state
        debugPrint("🧹 Cleaning up chapter preloading");
      };
    }, [continuousReading, initialNextPrevChapterPair]);
    
    // Track the last viewed page for immediate saving when changing chapters or exiting
    final lastViewedPage = useRef<HorizontalMultiChapterPageItem?>(null);
    
    // Handle page changes and tracking
    useEffect(() {
      if (onPageChanged != null) onPageChanged!(currentIndex.value);
      
      // Check if we need to load more chapters based on current position
      if (continuousReading && !chapterLocked.value) {
        // Find the current item in our array of all pages
        final currentItemIndex = currentIndex.value;
        if (currentItemIndex < 0 || currentItemIndex >= allPages.value.length) {
          return null;
        }
        
        final currentItem = allPages.value[currentItemIndex];
        
        // Skip if this is a transition indicator
        if (currentItem.isTransitionIndicator) {
          debugPrint("📍 At chapter transition indicator - skipping actions");
          return null;
        }
        
        // Store the current page for potential exit/cleanup saving
        lastViewedPage.value = currentItem;
        
        // Update current chapter if changed
        if (currentItem.chapterId != currentChapter.value.id) {
          debugPrint("🔀 Switching chapter from ${currentChapter.value.name} to ${currentItem.chapter.name}");
          currentChapter.value = currentItem.chapter;
          
          // Reset next/prev chapter pair for the new current chapter
          ref.invalidate(getNextAndPreviousChaptersProvider(
            mangaId: manga.id,
            chapterId: currentChapter.value.id
          ));
        }
        
        // Near the end of the current chapter - load next chapter if needed
        if (currentItem.pageIndex >= currentItem.chapterPages.chapter.pageCount - 3) {
          // Get the next chapter for current chapter
          final nextPrevPair = ref.read(getNextAndPreviousChaptersProvider(
            mangaId: manga.id,
            chapterId: currentItem.chapterId,
          ));
          
          if (nextPrevPair != null && nextPrevPair.first != null && 
              !loadedChapters.value.containsKey(nextPrevPair.first!.id)) {
            loadNextChapter(chapterPair: nextPrevPair);
          }
        }
        
        // Near the beginning of the current chapter - load previous chapter if needed
        if (currentItem.pageIndex <= 2) {
          // Get the previous chapter for current chapter
          final nextPrevPair = ref.read(getNextAndPreviousChaptersProvider(
            mangaId: manga.id,
            chapterId: currentItem.chapterId,
          ));
          
          if (nextPrevPair != null && nextPrevPair.second != null && 
              !loadedChapters.value.containsKey(nextPrevPair.second!.id)) {
            loadPreviousChapter(chapterPair: nextPrevPair);
          }
        }
        
        // Update read progress for current chapter
        if (currentItem.chapterId != chapter.id) {
          // For chapters other than the original one
          final isReadingCompleted = currentItem.pageIndex >= (currentItem.chapterPages.chapter.pageCount - 1);
          ref.read(mangaBookRepositoryProvider).putChapter(
            chapterId: currentItem.chapterId,
            patch: ChapterChange(
              lastPageRead: isReadingCompleted ? 0 : currentItem.pageIndex,
              isRead: isReadingCompleted,
            ),
          );
        }
      } else if (!continuousReading) {
        // Even in single chapter mode, track the last viewed page
        final currentItemIndex = currentIndex.value;
        if (currentItemIndex >= 0 && currentItemIndex < allPages.value.length) {
          final currentItem = allPages.value[currentItemIndex];
          if (!currentItem.isTransitionIndicator) {
            lastViewedPage.value = currentItem;
          }
        }
      }
      
      // Preload images around current page
      
      // Find the current item for preloading images
      final currentItemIndex = currentIndex.value;
      if (currentItemIndex < 0 || currentItemIndex >= allPages.value.length) {
        return null;
      }
      
      final currentItem = allPages.value[currentItemIndex];
      if (currentItem.isTransitionIndicator) {
        return null; // Skip preloading for transition indicators
      }
      
      // Cache previous page
      if (currentItemIndex > 0 && !allPages.value[currentItemIndex - 1].isTransitionIndicator) {
        final prevItem = allPages.value[currentItemIndex - 1];
        final prevUrl = loadedChapters.value[prevItem.chapterId]?.pages[prevItem.pageIndex];
        if (prevUrl != null) {
          cacheManager.getServerFile(ref, prevUrl);
        }
      }
      
      // Cache next page
      if (currentItemIndex < allPages.value.length - 1 && !allPages.value[currentItemIndex + 1].isTransitionIndicator) {
        final nextItem = allPages.value[currentItemIndex + 1];
        final nextUrl = loadedChapters.value[nextItem.chapterId]?.pages[nextItem.pageIndex];
        if (nextUrl != null) {
          cacheManager.getServerFile(ref, nextUrl);
        }
      }
      
      // Cache second next page
      if (currentItemIndex < allPages.value.length - 2 && !allPages.value[currentItemIndex + 2].isTransitionIndicator) {
        final nextNextItem = allPages.value[currentItemIndex + 2];
        final nextNextUrl = loadedChapters.value[nextNextItem.chapterId]?.pages[nextNextItem.pageIndex];
        if (nextNextUrl != null) {
          cacheManager.getServerFile(ref, nextNextUrl);
        }
      }
      
      // If not using continuous reading, handle old auto-next chapter behavior
      if (!continuousReading && autoNextChapter && 
          currentIndex.value >= chapterPages.chapter.pageCount - 1 && 
          currentNextPrevChapterPair?.first != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            context.pushReplacement(
              '/manga/${currentNextPrevChapterPair!.first!.mangaId}/chapter/${currentNextPrevChapterPair.first!.id}'
            );
          }
        });
      }
      
      return null;
    }, [currentIndex.value, currentChapter.value, continuousReading, allPages.value]);
    
    // Prepopulate repository for safe access during cleanup
    final repository = ref.read(mangaBookRepositoryProvider);
    
    // Cleanup effect to save progress when exiting the reader
    useEffect(() {
      return () {
        // Save progress for the last viewed page when unmounting
        final lastPage = lastViewedPage.value;
        if (lastPage != null && !lastPage.isTransitionIndicator) {
          final pageIndex = lastPage.pageIndex;
          final isReadingCompleted = pageIndex >= (lastPage.chapterPages.chapter.pageCount - 1);
          
          debugPrint("💾 Saving final progress on exit - Chapter: ${lastPage.chapter.name}, Page: $pageIndex");
          
          try {
            // Use the pre-captured repository instance without referring to ref
            repository.putChapter(
              chapterId: lastPage.chapterId,
              patch: ChapterChange(
                lastPageRead: isReadingCompleted ? 0 : pageIndex,
                isRead: isReadingCompleted,
              ),
            );
          } catch (e) {
            debugPrint("⚠️ Error saving reading progress: $e");
          }
        }
      };
    }, [repository]);
    
    // Listen for page changes
    useEffect(() {
      listener() {
        final currentPage = scrollController.page;
        if (currentPage != null) {
          final newIndex = currentPage.round();
          if (newIndex != currentIndex.value) {
            currentIndex.value = newIndex;
          }
        }
      }

      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);
    
    final isAnimationEnabled = ref.read(readerScrollAnimationProvider).ifNull(true);
    final isPinchToZoomEnabled = ref.read(pinchToZoomProvider).ifNull(true);
    
    return ReaderWrapper(
      scrollDirection: scrollDirection,
      chapter: currentChapter.value,
      manga: manga,
      chapterPages: loadedChapters.value[currentChapter.value.id] ?? chapterPages,
      currentIndex: continuousReading 
          ? (currentIndex.value >= 0 && currentIndex.value < allPages.value.length && !allPages.value[currentIndex.value].isTransitionIndicator) 
              ? allPages.value[currentIndex.value].pageIndex 
              : 0
          : currentIndex.value,
      onChanged: (index) {
        if (continuousReading) {
          // Find the index in allPages that corresponds to this chapter+page
          final targetItemIndex = allPages.value.indexWhere(
            (item) => item.chapterId == currentChapter.value.id && item.pageIndex == index && !item.isTransitionIndicator
          );
          
          if (targetItemIndex >= 0) {
            scrollController.jumpToPage(targetItemIndex);
          }
        } else {
          scrollController.jumpToPage(index);
        }
      },
      showReaderLayoutAnimation: showReaderLayoutAnimation,
      onPrevious: () => scrollController.previousPage(
        duration: isAnimationEnabled ? kDuration : kInstantDuration,
        curve: kCurve,
      ),
      onNext: () => scrollController.nextPage(
        duration: isAnimationEnabled ? kDuration : kInstantDuration,
        curve: kCurve,
      ),
      child: Stack(
        children: [
          PageView.builder(
            scrollDirection: scrollDirection,
            reverse: reverse,
            controller: scrollController,
            allowImplicitScrolling: true,
            itemBuilder: (BuildContext context, int index) {
              // If no pages available or index out of range, show loading
              if (allPages.value.isEmpty || index < 0 || index >= allPages.value.length) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final item = allPages.value[index];
              
              // If this is a transition indicator, show it
              if (item.isTransitionIndicator) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: scrollDirection == Axis.vertical ? 24.0 : 8.0,
                    horizontal: scrollDirection != Axis.vertical ? 24.0 : 8.0,
                  ),
                  child: ChapterTransitionIndicator(
                    chapter: item.chapter,
                    manga: manga,
                    isPreviousChapter: item.isPreviousChapter,
                    scrollDirection: scrollDirection,
                  ),
                );
              }
              
              // Get the image URL for this page from the appropriate chapter
              final imageUrl = loadedChapters.value[item.chapterId]?.pages[item.pageIndex];
              
              if (imageUrl == null) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final image = ServerImage(
                showReloadButton: true,
                fit: scrollDirection == Axis.vertical ? BoxFit.fitWidth : BoxFit.contain,
                size: Size.fromHeight(context.height),
                appendApiToUrl: false,
                imageUrl: imageUrl,
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    CenterSorayomiShimmerIndicator(
                  value: downloadProgress.progress,
                ),
              );
              
              return AppUtils.wrapOn(
                !kIsWeb && (Platform.isAndroid || Platform.isIOS) && isPinchToZoomEnabled
                    ? (child) => InteractiveViewer(maxScale: 5, child: child)
                    : null,
                image,
              );
            },
            itemCount: allPages.value.length,
          ),
          if (!continuousReading && autoNextChapter && 
              currentIndex.value >= chapter.pageCount.getValueOnNullOrNegative() - 1 && 
              currentNextPrevChapterPair?.first != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: NextChapterNotice(
                nextChapter: currentNextPrevChapterPair!.first!,
                mangaId: manga.id,
                showAction: false,
                transVertical: scrollDirection != Axis.vertical,
              ),
            ),
        ],
      ),
    );
  }
}