// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

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
import '../../../../../settings/presentation/reader/widgets/reader_scroll_animation_tile/reader_scroll_animation_tile.dart';
import '../../../../domain/chapter/chapter_model.dart';
import '../../../../domain/chapter_page/chapter_page_model.dart';
import '../../../../domain/manga/manga_model.dart';
import '../../../manga_details/controller/manga_details_controller.dart';
import '../next_chapter_notice.dart';
import '../reader_wrapper.dart';

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
    final cacheManager = useMemoized(() => DefaultCacheManager());
    final scrollController = usePageController(
      initialPage: chapter.isRead.ifNull()
          ? 0
          : chapter.lastPageRead.getValueOnNullOrNegative(),
    );
    final currentIndex = useState(scrollController.initialPage);
    final nextPrevChapterPair = ref.watch(
      getNextAndPreviousChaptersProvider(
        mangaId: manga.id,
        chapterId: chapter.id,
      ),
    );
    
    useEffect(() {
      if (onPageChanged != null) onPageChanged!(currentIndex.value);
      int currentPage = currentIndex.value;
      // Prev page
      if (currentPage > 0) {
        cacheManager.getServerFile(
          ref,
          chapterPages.pages[currentPage - 1],
        );
      }
      // Next page
      if (currentPage < (chapter.pageCount.getValueOnNullOrNegative() - 1)) {
        cacheManager.getServerFile(
          ref,
          chapterPages.pages[currentPage + 1],
        );
      }
      // 2nd next page
      if (currentPage < (chapter.pageCount.getValueOnNullOrNegative() - 2)) {
        cacheManager.getServerFile(
          ref,
          chapterPages.pages[currentPage + 1],
        );
      }
      
      // Automatically navigate to next chapter when reaching the last page
      if (autoNextChapter && 
          currentPage >= chapter.pageCount.getValueOnNullOrNegative() - 1 && 
          nextPrevChapterPair?.first != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            context.pushReplacement(
              '/manga/${nextPrevChapterPair!.first!.mangaId}/chapter/${nextPrevChapterPair.first!.id}'
            );
          }
        });
      }
      return null;
    }, [currentIndex.value]);
    useEffect(() {
      listener() {
        final currentPage = scrollController.page;
        if (currentPage != null) currentIndex.value = (currentPage.toInt());
      }

      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);
    final isAnimationEnabled =
        ref.read(readerScrollAnimationProvider).ifNull(true);
    return ReaderWrapper(
      scrollDirection: scrollDirection,
      chapter: chapter,
      manga: manga,
      chapterPages: chapterPages,
      currentIndex: currentIndex.value,
      onChanged: (index) => scrollController.jumpToPage(index),
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
              final image = ServerImage(
                showReloadButton: true,
                fit: BoxFit.contain,
                size: Size.fromHeight(context.height),
                appendApiToUrl: false,
                imageUrl: chapterPages.pages[index],
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    CenterSorayomiShimmerIndicator(
                  value: downloadProgress.progress,
                ),
              );
              return AppUtils.wrapOn(
                !kIsWeb && (Platform.isAndroid || Platform.isIOS)
                    ? (child) => InteractiveViewer(maxScale: 5, child: child)
                    : null,
                image,
              );
            },
            itemCount: chapter.pageCount.getValueOnNullOrNegative(),
          ),
          if (autoNextChapter && 
              currentIndex.value >= chapter.pageCount.getValueOnNullOrNegative() - 1 && 
              nextPrevChapterPair?.first != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: NextChapterNotice(
                nextChapter: nextPrevChapterPair!.first!,
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