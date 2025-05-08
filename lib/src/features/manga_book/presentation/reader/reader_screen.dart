// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../constants/enum.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../settings/presentation/reader/widgets/reader_keep_screen_on_tile/reader_keep_screen_on_tile.dart';
import '../../../settings/presentation/reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import '../../data/reading_progress/reading_progress_repository.dart';
import '../../domain/manga/manga_model.dart';
import '../../domain/reading_progress/reading_progress_model.dart';
import '../manga_details/controller/manga_details_controller.dart';
import 'controller/reader_controller.dart';
import 'widgets/reader_mode/continuous_reader_mode.dart';
import 'widgets/reader_mode/single_page_reader_mode.dart';

class ReaderScreen extends HookConsumerWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    this.showReaderLayoutAnimation = false,
  });
  final int mangaId;
  final int chapterId;
  final bool showReaderLayoutAnimation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaProvider = mangaWithIdProvider(mangaId: mangaId);
    final chapterProviderWithIndex = chapterProvider(chapterId: chapterId);
    final chapterPages = ref.watch(chapterPagesProvider(chapterId: chapterId));
    final manga = ref.watch(mangaProvider);
    final chapter = ref.watch(chapterProviderWithIndex);
    final defaultReaderMode = ref.watch(readerModeKeyProvider);
    
    // Reference to progress sync service
    final syncServiceProvider = ref.watch(progressSyncServiceProvider.notifier);
    
    // Local storage repositories
    final progressRepository = ref.read(readingProgressRepositoryProvider);

    // We still use this for exit cleanup, but won't use it for active reading
    final lastPageIndex = useRef<int>(-1);

    // Update reading progress - now uses local storage first, then queues for sync
    final updateLocalProgress = useCallback((int currentPage) async {
      final chapterValue = chapter.valueOrNull;
      if (chapterValue == null) return;

      final isReadingCompleted = ((chapterValue.isRead).ifNull() ||
          (currentPage >=
              ((chapterValue.pageCount).getValueOnNullOrNegative() - 1)));
      
      // Create progress dto
      final progress = ReadingProgressDto(
        chapterId: chapterValue.id,
        pageIndex: currentPage,
        isRead: isReadingCompleted,
        timestamp: DateTime.now(),
        synced: false,
      );
      
      // Update local storage immediately - no await for better UI responsiveness
      progressRepository.saveProgress(progress);
      
      // Add to sync queue for background processing - no await for better UI responsiveness
      progressRepository.addToSyncQueue(progress);
      
    }, [chapter.valueOrNull, progressRepository]);

    // Handle page changes - now fully local for UI responsiveness
    final onPageChanged = useCallback<AsyncValueSetter<int>>(
      (int index) async {
        final chapterValue = chapter.valueOrNull;
        if ((chapterValue?.isRead).ifNull() ||
            (chapterValue?.lastPageRead).getValueOnNullOrNegative() >= index) {
          return;
        }

        // Always update the lastPageIndex for potential exit saving
        lastPageIndex.value = index;

        // Update local immediately without debounce for smooth UI
        final isReadingCompleted = index >=
            ((chapter.valueOrNull?.pageCount).getValueOnNullOrNegative() - 1);
            
        if (isReadingCompleted) {
          // Immediately update locally for chapter completion
          await updateLocalProgress(index);
          
          // Try to sync immediately for chapter completion
          syncServiceProvider.syncChapter(chapterValue!.id);
        } else {
          // Always update locally, but don't immediately sync minor page changes
          await updateLocalProgress(index);
        }
        return;
      },
      [chapter, updateLocalProgress, syncServiceProvider],
    );

    // Pre-capture dependencies for cleanup to avoid using ref after disposal
    final cachedChapter = chapter.valueOrNull;
    
    // Make sure that we save progress when leaving the screen
    useEffect(() {
      return () {
        // Save if we have a valid page
        if (lastPageIndex.value >= 0 && cachedChapter != null) {
          // Always save the last page read locally
          // Using cachedChapter instead of chapter.valueOrNull
          final isCompleted = ((cachedChapter.isRead).ifNull() ||
              (lastPageIndex.value >=
                  ((cachedChapter.pageCount).getValueOnNullOrNegative() - 1)));
                  
          // Create the progress directly instead of using updateLocalProgress
          final progress = ReadingProgressDto(
            chapterId: cachedChapter.id,
            pageIndex: lastPageIndex.value,
            isRead: isCompleted,
            timestamp: DateTime.now(),
            synced: false,
          );
          
          // Use the already captured repositories
          progressRepository.saveProgress(progress);
          progressRepository.addToSyncQueue(progress);
        }
      };
    }, [cachedChapter, progressRepository]);
    
    // Get the keep screen on setting
    final keepScreenOn = ref.watch(keepScreenOnProvider).ifNull();
    
    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      // Enable or disable wake lock based on setting
      if (keepScreenOn) {
        WakelockPlus.enable();
      }
      
      return () {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        
        // Always disable wake lock when leaving the reader
        WakelockPlus.disable();
      };
    }, [keepScreenOn]);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          // Save the last read page before popping
          if (lastPageIndex.value >= 0 && chapter.valueOrNull != null) {
            // Always save the last page read locally - not using await for responsiveness
            updateLocalProgress(lastPageIndex.value);
            
            // Force sync this specific chapter when exiting - not using await for responsiveness
            // This will happen in the background
            syncServiceProvider.syncChapter(chapter.valueOrNull!.id);
          }
          
          // We'll invalidate providers in the next frame to avoid invalidating during disposal
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.invalidate(chapterProviderWithIndex);
            ref.invalidate(mangaChapterListProvider(mangaId: mangaId));
          });
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SafeArea(
          child: manga.showUiWhenData(
            context,
            (data) {
              if (data == null) return const SizedBox.shrink();
              return chapter.showUiWhenData(
                context,
                (chapterData) {
                  if (chapterData == null) return const SizedBox.shrink();
                  return chapterPages.showUiWhenData(
                    context,
                    (chapterPagesData) {
                      if (chapterPagesData == null) {
                        return const SizedBox.shrink();
                      }
                      return switch (
                          data.metaData.readerMode ?? defaultReaderMode) {
                        ReaderMode.singleVertical => SinglePageReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            scrollDirection: Axis.vertical,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.singleHorizontalRTL => SinglePageReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            reverse: true,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.continuousHorizontalLTR =>
                          ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            scrollDirection: Axis.horizontal,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.continuousHorizontalRTL =>
                          ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.singleHorizontalLTR => SinglePageReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.continuousVertical => ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            showSeparator: true,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.webtoon => ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          ),
                        ReaderMode.defaultReader ||
                        null =>
                          ContinuousReaderMode(
                            chapter: chapterData,
                            manga: data,
                            onPageChanged: onPageChanged,
                            showReaderLayoutAnimation:
                                showReaderLayoutAnimation,
                            chapterPages: chapterPagesData,
                          )
                      };
                    },
                  );
                },
                refresh: () => ref.refresh(chapterProviderWithIndex.future),
                addScaffoldWrapper: true,
              );
            },
            addScaffoldWrapper: true,
            refresh: () => ref.refresh(mangaProvider.future),
          ),
        ),
      ),
    );
  }
}
