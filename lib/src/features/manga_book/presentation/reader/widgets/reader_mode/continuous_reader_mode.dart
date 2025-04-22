// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../../../constants/app_constants.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/misc/app_utils.dart';
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
import '../chapter_separator.dart';
import '../chapter_transition_indicator.dart';
import '../next_chapter_notice.dart';
import '../reader_wrapper.dart';
import '../../controller/reader_controller.dart';

class MultiChapterPageItem {
  final int chapterId;
  final int pageIndex;
  final ChapterPagesDto chapterPages;
  final ChapterDto chapter;

  MultiChapterPageItem({
    required this.chapterId,
    required this.pageIndex,
    required this.chapterPages,
    required this.chapter,
  });
}

class ContinuousReaderMode extends HookConsumerWidget {
  const ContinuousReaderMode({
    super.key,
    required this.manga,
    required this.chapter,
    required this.chapterPages,
    this.showSeparator = false,
    this.onPageChanged,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.showReaderLayoutAnimation = false,
  });
  final MangaDto manga;
  final ChapterDto chapter;
  final bool showSeparator;
  final ValueSetter<int>? onPageChanged;
  final Axis scrollDirection;
  final bool reverse;
  final bool showReaderLayoutAnimation;
  final ChapterPagesDto chapterPages;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoNextChapter = ref.watch(autoNextChapterToggleProvider).ifNull();
    final continuousReading = ref.watch(continuousReadingToggleProvider).ifNull();
    final scrollController = useMemoized(() => ItemScrollController());
    final positionsListener = useMemoized(() => ItemPositionsListener.create());
    
    // Track the current chapter and page
    final currentChapter = useState<ChapterDto>(chapter);
    final currentPageIndex = useState(
      chapter.isRead.ifNull()
          ? 0
          : (chapter.lastPageRead).getValueOnNullOrNegative(),
    );
    
    // Stores all loaded chapters and their pages for continuous reading
    final loadedChapters = useState<Map<int, ChapterPagesDto>>({chapter.id: chapterPages});
    final allChapterPages = useState<List<MultiChapterPageItem>>([]);
    
    // Add a lock mechanism to prevent unwanted chapter switches during initialization
    final chapterLocked = useState(true); // Start locked to prevent accidental chapter switches
    
    // Track if the widget is mounted to prevent updating state after disposal
    final isMounted = useRef(true);
    useEffect(() {
      return () {
        // Mark as unmounted on dispose
        isMounted.value = false;
      };
    }, []);
    
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
    
    // Initialize page items for the current chapter with a consistent and clean approach
    useEffect(() {
      // Always reset state when opening a new chapter
      debugPrint("🔄 Initializing chapter ${chapter.name} (ID: ${chapter.id})");
      
      // Ensure we lock the chapter first before anything else
      chapterLocked.value = true;
      
      // Clear all state completely to ensure we're starting fresh
      loadedChapters.value = {chapter.id: chapterPages};
      currentChapter.value = chapter;
      
      // Get the intended starting page index before creating pages
      final startingPageIndex = chapter.isRead.ifNull() 
          ? 0 
          : chapter.lastPageRead.getValueOnNullOrNegative();
      
      currentPageIndex.value = startingPageIndex;
      
      // Create a clean list with just this chapter's pages
      final initialPages = List.generate(
        chapterPages.chapter.pageCount,
        (index) => MultiChapterPageItem(
          chapterId: chapter.id,
          pageIndex: index,
          chapterPages: chapterPages,
          chapter: chapter,
        ),
      );
      
      // Update pages after currentIndex is set
      allChapterPages.value = initialPages;
      
      debugPrint("📘 Chapter ${chapter.id} initialized with ${initialPages.length} pages. Starting at page $startingPageIndex");
      
      // Unlock the chapter after a delay
      Future.delayed(const Duration(seconds: 3), () {
        // Check if widget is still mounted before updating state
        if (!isMounted.value) return;
        
        if (chapterLocked.value == true) {
          chapterLocked.value = false;
          debugPrint("🔓 Chapter unlocked for navigation");
        }
      });
      
      isInitialized.value = true;
      return null;
    }, [chapter.id]); // Re-initialize when chapter.id changes
    
    // Load next chapter pages when needed
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
      
      // Fetch next chapter
      final nextChapterPages = await ref.read(
        chapterPagesProvider(chapterId: nextChapterId).future,
      );
      
      if (nextChapterPages == null) return;
      
      // Add to loaded chapters
      final updatedChapters = Map<int, ChapterPagesDto>.from(loadedChapters.value);
      updatedChapters[nextChapterId] = nextChapterPages as ChapterPagesDto;
      loadedChapters.value = updatedChapters;
      
      // Create transition indicator
      final transitionItem = MultiChapterPageItem(
        chapterId: -1, // Special ID for transition
        pageIndex: -1,
        chapterPages: chapterPages,
        chapter: nextPrevPair.first!,
      );
      
      // Create page items for next chapter
      final nextChapterItems = List.generate(
        nextChapterPages.chapter.pageCount,
        (index) => MultiChapterPageItem(
          chapterId: nextChapterId,
          pageIndex: index,
          chapterPages: nextChapterPages,
          chapter: nextPrevPair.first!,
        ),
      );
      
      // Add transition and next chapter pages
      allChapterPages.value = [
        ...allChapterPages.value,
        transitionItem,
        ...nextChapterItems,
      ];
    }, [continuousReading, currentNextPrevChapterPair, loadedChapters.value]);
    
    // Load previous chapter pages when needed
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
      
      // Fetch previous chapter
      final prevChapterPages = await ref.read(
        chapterPagesProvider(chapterId: prevChapterId).future,
      );
      
      if (prevChapterPages == null) return;
      
      // Add to loaded chapters
      final updatedChapters = Map<int, ChapterPagesDto>.from(loadedChapters.value);
      updatedChapters[prevChapterId] = prevChapterPages as ChapterPagesDto;
      loadedChapters.value = updatedChapters;
      
      // Create transition indicator
      final transitionItem = MultiChapterPageItem(
        chapterId: -2, // Special ID for previous transition
        pageIndex: -1,
        chapterPages: chapterPages,
        chapter: nextPrevPair.second!,
      );
      
      // Create page items for previous chapter
      final prevChapterItems = List.generate(
        prevChapterPages.chapter.pageCount,
        (index) => MultiChapterPageItem(
          chapterId: prevChapterId,
          pageIndex: index,
          chapterPages: prevChapterPages,
          chapter: nextPrevPair.second!,
        ),
      );
      
      // Add previous chapter pages and transition at the beginning
      allChapterPages.value = [
        ...prevChapterItems,
        transitionItem,
        ...allChapterPages.value,
      ];
      
      // Adjust scroll position to maintain current view after inserting items at the beginning
      if (scrollController.isAttached) {
        final currentPosition = positionsListener.itemPositions.value.first;
        scrollController.jumpTo(
          index: currentPosition.index + prevChapterItems.length + 1,
          alignment: currentPosition.itemLeadingEdge,
        );
      }
    }, [continuousReading, currentNextPrevChapterPair, loadedChapters.value]);
    
    // Pre-load next chapter if continuous reading is enabled - with a significant delay
    // to ensure the main chapter is fully loaded first
    useEffect(() {
      if (!continuousReading) return null;
      
      // Add a considerable delay before loading next/prev chapters
      // This prevents race conditions and ensures correct initial chapter display
      final timer = Timer(const Duration(seconds: 2), () {
        // Check if widget is still mounted before updating state
        if (!isMounted.value) return;
        
        // ONLY load the next chapter, NEVER the previous one on initial load
        if (initialNextPrevChapterPair?.first != null) {
          debugPrint("⏳ Preloading next chapter: ${initialNextPrevChapterPair!.first!.name}");
          loadNextChapter(chapterPair: initialNextPrevChapterPair);
        }
      });
      
      return () => timer.cancel();
    }, [continuousReading, initialNextPrevChapterPair]);
    
    // Handle page changes and tracking
    useEffect(() {
      // Find the current page in all loaded pages
      final currentVisibleItem = allChapterPages.value.isEmpty 
          ? null 
          : allChapterPages.value.firstWhere(
              (item) => item.chapterId == currentChapter.value.id && 
                        item.pageIndex == currentPageIndex.value,
              orElse: () => allChapterPages.value.first,
            );
      
      if (currentVisibleItem != null) {
        // Page tracking for ALL chapters, not just the initial one
        // This ensures we save progress even when reading a different chapter than the one initially loaded
        if (onPageChanged != null && currentVisibleItem.chapterId > 0) {
          // Track page progress for the CURRENT chapter being viewed
          final chapterToUpdate = currentVisibleItem.chapter;
          final pageIndex = currentVisibleItem.pageIndex;
          
          // Make sure we're storing progress for the CORRECT chapter
          if (chapterToUpdate.id == chapter.id) {
            // For the original chapter, use the provided callback
            onPageChanged!(pageIndex);
          } else {
            // For other chapters, skip updates during initialization
            // This prevents unwanted side effects on other chapters
            if (!chapterLocked.value) {
              // Only update other chapters when we're deliberately navigating
              final isReadingCompleted = pageIndex >= (chapterToUpdate.pageCount - 1);
              ref.read(mangaBookRepositoryProvider).putChapter(
                chapterId: chapterToUpdate.id,
                patch: ChapterChange(
                  lastPageRead: isReadingCompleted ? 0 : pageIndex,
                  isRead: isReadingCompleted,
                ),
              );
            }
          }
        }
        
        // Near end of chapter - load next chapter if needed
        if (continuousReading && 
            currentVisibleItem.chapterId > 0 &&
            currentVisibleItem.pageIndex >= 
                (loadedChapters.value[currentVisibleItem.chapterId]?.chapter.pageCount ?? 0) - 3) {
          // Get the next chapter for the current visible chapter
          final nextPrevPair = ref.read(getNextAndPreviousChaptersProvider(
            mangaId: manga.id,
            chapterId: currentVisibleItem.chapterId,
          ));
          if (nextPrevPair != null && nextPrevPair.first != null && 
              !loadedChapters.value.containsKey(nextPrevPair.first!.id)) {
            loadNextChapter(chapterPair: nextPrevPair);
          }
        }
        
        // Near beginning of chapter - load previous chapter if needed
        if (continuousReading && 
            currentVisibleItem.chapterId > 0 &&
            currentVisibleItem.pageIndex <= 2) {
          // Get the previous chapter for the current visible chapter
          final nextPrevPair = ref.read(getNextAndPreviousChaptersProvider(
            mangaId: manga.id,
            chapterId: currentVisibleItem.chapterId,
          ));
          if (nextPrevPair != null && nextPrevPair.second != null && 
              !loadedChapters.value.containsKey(nextPrevPair.second!.id)) {
            loadPreviousChapter(chapterPair: nextPrevPair);
          }
        }
      }
      
      // If not continuous reading, use the old auto-next chapter behavior
      if (!continuousReading && autoNextChapter && 
          currentPageIndex.value >= chapterPages.chapter.pageCount - 1 && 
          currentNextPrevChapterPair?.first != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            context.pushReplacement(
              '/manga/${currentNextPrevChapterPair!.first!.mangaId}/chapter/${currentNextPrevChapterPair.first!.id}'
            );
          }
        });
      }
      
      return;
    }, [currentPageIndex.value, currentChapter.value, currentNextPrevChapterPair, continuousReading, allChapterPages.value]);
    
    // Listen for item position changes to track current page
    useEffect(() {
      listener() {
        final positions = positionsListener.itemPositions.value.toList();
        if (positions.isEmpty) return;
        
        // Sort positions by visibility (most visible first)
        positions.sort((a, b) {
          final aVisiblePortion = a.itemTrailingEdge - a.itemLeadingEdge;
          final bVisiblePortion = b.itemTrailingEdge - b.itemLeadingEdge;
          return bVisiblePortion.compareTo(aVisiblePortion);
        });
        
        // Take the most visible position
        final bestPosition = positions.first;
        final index = bestPosition.index;
        
        // Safety check
        if (index < 0 || index >= allChapterPages.value.length) return;
        
        final item = allChapterPages.value[index];
        
        // Skip transition indicators - but still need to keep track of them
        if (item.chapterId < 0) {
          // When scrolling past a transition indicator, update UI
          // This helps with cases where the transition indicator is very short
          if (bestPosition.itemLeadingEdge < 0.3 && bestPosition.itemTrailingEdge > 0.7) {
            // We're passing through a transition
            final isNextChapter = item.chapterId == -1;
            debugPrint("🔄 Passing through chapter transition to ${isNextChapter ? 'next' : 'previous'} chapter (${item.chapter.name})");
            
            // Don't do anything else with transitions - they're just markers
          }
          return;
        }
        
        // Update current chapter and page if changed AND not locked
        if (item.chapterId != currentChapter.value.id) {
          // Check if we're allowed to switch chapters yet
          if (chapterLocked.value) {
            // If the chapter is locked, DON'T change chapters
            debugPrint("🔒 Chapter switch prevented - initialization period");
            
            // Force scroll back to the correct chapter
            if (scrollController.isAttached) {
              // First try to find the exact page
              var correctIndex = allChapterPages.value.indexWhere(
                (item) => item.chapterId == chapter.id && item.pageIndex == currentPageIndex.value
              );
              
              // If exact page not found, just find any page in this chapter
              if (correctIndex < 0) {
                correctIndex = allChapterPages.value.indexWhere(
                  (item) => item.chapterId == chapter.id
                );
              }
              
              // If we found a valid index, jump to it
              if (correctIndex >= 0) {
                // Use a very brief delay to avoid race conditions
                Future.microtask(() {
                  // Check if widget is still mounted and controller is attached
                  if (isMounted.value && scrollController.isAttached) {
                    scrollController.jumpTo(index: correctIndex);
                    debugPrint("📌 Forced scroll back to the intended chapter (page ${currentPageIndex.value})");
                  }
                });
              }
            }
          } else {
            // Normal behavior when unlocked - switching is allowed
            final oldChapter = currentChapter.value;
            currentChapter.value = item.chapter;
            
            debugPrint("🔍 Chapter changed from ${oldChapter.name} to ${currentChapter.value.name}");
            
            // Check if we need to reload prev/next chapters for the new current chapter
            ref.invalidate(getNextAndPreviousChaptersProvider(
              mangaId: manga.id, 
              chapterId: currentChapter.value.id
            ));
          }
        }
        
        // Only update page index if it changed to avoid unnecessary rebuilds
        // AND chapter is not locked to prevent accidental page changes during initialization
        if (!chapterLocked.value && currentPageIndex.value != item.pageIndex) {
          // Only update if we're in the originally requested chapter or unlocked
          if (item.chapterId == chapter.id || !chapterLocked.value) {
            currentPageIndex.value = item.pageIndex;
          }
        }
      }

      positionsListener.itemPositions.addListener(listener);
      return () => positionsListener.itemPositions.removeListener(listener);
    }, [allChapterPages.value]);
    
    final isAnimationEnabled = ref.read(readerScrollAnimationProvider).ifNull(true);
    final isPinchToZoomEnabled = ref.read(pinchToZoomProvider).ifNull(true);
    
    return ReaderWrapper(
      scrollDirection: scrollDirection,
      chapterPages: loadedChapters.value[currentChapter.value.id] ?? chapterPages,
      chapter: currentChapter.value,
      manga: manga,
      showReaderLayoutAnimation: showReaderLayoutAnimation,
      currentIndex: currentPageIndex.value,
      onChanged: (index) {
        // Find the item that corresponds to this chapter+page
        final targetItemIndex = allChapterPages.value.indexWhere(
          (item) => item.chapterId == currentChapter.value.id && item.pageIndex == index
        );
        
        if (targetItemIndex >= 0) {
          scrollController.jumpTo(index: targetItemIndex);
        }
      },
      onPrevious: () {
        final itemPosition = positionsListener.itemPositions.value.toList().first;
        isAnimationEnabled
            ? scrollController.scrollTo(
                index: itemPosition.index,
                duration: kDuration,
                curve: kCurve,
                alignment: itemPosition.itemLeadingEdge + .8,
              )
            : scrollController.jumpTo(
                index: itemPosition.index,
                alignment: itemPosition.itemLeadingEdge + .8,
              );
      },
      onNext: () {
        ItemPosition itemPosition = positionsListener.itemPositions.value.first;
        final int index;
        final double alignment;
        if (itemPosition.itemTrailingEdge > 1) {
          index = itemPosition.index;
          alignment = itemPosition.itemLeadingEdge - .8;
        } else {
          index = itemPosition.index + 1;
          alignment = 0;
        }
        isAnimationEnabled
            ? scrollController.scrollTo(
                index: index,
                duration: kDuration,
                curve: kCurve,
                alignment: alignment,
              )
            : scrollController.jumpTo(
                index: index,
                alignment: alignment,
              );
      },
      child: Stack(
        children: [
          AppUtils.wrapOn(
            !kIsWeb &&
                    (Platform.isAndroid || Platform.isIOS) &&
                    isPinchToZoomEnabled
                ? (child) => InteractiveViewer(maxScale: 5, child: child)
                : null,
            ScrollablePositionedList.separated(
              itemScrollController: scrollController,
              itemPositionsListener: positionsListener,
              // Simplify initialization since we've already set up allChapterPages correctly
              // and know the target page is at the correct index
              initialScrollIndex: currentPageIndex.value,
              scrollDirection: scrollDirection,
              reverse: reverse,
              itemCount: allChapterPages.value.length,
              minCacheExtent: scrollDirection == Axis.vertical
                  ? context.height * 3  // Increased for smoother multi-chapter scrolling
                  : context.width * 3,
              separatorBuilder: (BuildContext context, int index) =>
                  showSeparator ? const Gap(16) : const SizedBox.shrink(),
              itemBuilder: (BuildContext context, int index) {
                final item = allChapterPages.value[index];
                
                // Check if this is a chapter transition indicator
                if (item.chapterId < 0) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: scrollDirection == Axis.vertical ? 24.0 : 8.0,
                      horizontal: scrollDirection != Axis.vertical ? 24.0 : 8.0,
                    ),
                    child: ChapterTransitionIndicator(
                      chapter: item.chapter,
                      manga: manga,
                      isPreviousChapter: item.chapterId == -2,
                      scrollDirection: scrollDirection,
                    ),
                  );
                }
                
                final imageUrl = loadedChapters.value[item.chapterId]?.pages[item.pageIndex];
                if (imageUrl == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final image = ServerImage(
                  showReloadButton: true,
                  fit: scrollDirection == Axis.vertical
                      ? BoxFit.fitWidth
                      : BoxFit.fitHeight,
                  appendApiToUrl: false,
                  imageUrl: imageUrl,
                  progressIndicatorBuilder: (_, __, downloadProgress) => Center(
                    child: CircularProgressIndicator(
                      value: downloadProgress.progress,
                    ),
                  ),
                  wrapper: (child) => SizedBox(
                    height: scrollDirection == Axis.vertical
                        ? context.height * .7
                        : null,
                    width: scrollDirection != Axis.vertical
                        ? context.width * .7
                        : null,
                    child: child,
                  ),
                );
                
                // Add chapter start/end indicators for first/last pages of chapters
                final isChapterStart = item.pageIndex == 0;
                final isChapterEnd = item.pageIndex == loadedChapters.value[item.chapterId]!.chapter.pageCount - 1;
                
                if (isChapterStart || isChapterEnd) {
                  final bool reverseDirection = scrollDirection == Axis.horizontal && reverse;
                  final separator = SizedBox(
                    width: scrollDirection != Axis.vertical
                        ? context.width * .5
                        : null,
                    child: ChapterSeparator(
                      manga: manga,
                      chapter: item.chapter,
                      isPreviousChapterSeparator: isChapterStart,
                    ),
                  );
                  return Flex(
                    direction: scrollDirection,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: ((isChapterStart) != reverseDirection)
                        ? [separator, image]
                        : [image, separator],
                  );
                } else {
                  return image;
                }
              },
            ),
          ),
          if (!continuousReading && autoNextChapter && 
              currentPageIndex.value >= (loadedChapters.value[currentChapter.value.id]?.chapter.pageCount ?? 0) - 1 && 
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