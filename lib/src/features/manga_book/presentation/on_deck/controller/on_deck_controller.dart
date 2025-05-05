// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/manga_book/on_deck_repository.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/chapter/graphql/__generated__/fragment.graphql.dart';
import '../../../../../utils/logger/logger.dart';

part 'on_deck_controller.g.dart';

@riverpod
class OnDeckController extends _$OnDeckController {
  @override
  Future<List<ChapterWithMangaDto>> build() async {
    // Log when the controller is built/refreshed
    logger.i("Building OnDeckController");
    // Clear any cached data from the repository
    ref.read(onDeckRepositoryProvider).clearCache();
    return [];
  }

  Future<void> fetchInProgressChapters({
    required int pageKey,
    required PagingController<int, ChapterWithMangaDto> controller,
    bool forceRefresh = false,
  }) async {
    logger.i("Fetching in-progress chapters. Page: $pageKey, forceRefresh: $forceRefresh");
    
    // Clear the controller's cached items to force a fresh load
    if (forceRefresh && pageKey == 0) {
      // Always clear the list when forcing a refresh
      controller.itemList?.clear();
    }
    
    try {
      final repository = ref.read(onDeckRepositoryProvider);
      // Pass the forceRefresh parameter to the repository
      final inProgressChapters = await repository.getInProgressChaptersPage(
        pageNo: pageKey,
        forceRefresh: forceRefresh,
      );
      
      if (inProgressChapters == null || inProgressChapters['nodes'] == null || inProgressChapters['nodes'].isEmpty) {
        controller.appendLastPage([]);
      } else {
        // Convert the dynamic map data to ChapterWithMangaDto objects
        final nodes = inProgressChapters['nodes'] as List;
        
        // First pass - collect all chapters grouped by manga
        final Map<int, List<ChapterWithMangaDto>> mangaToChapters = {};
        
        for (final node in nodes) {
          try {
            // Create a Fragment$ChapterWithMangaDto first, then use the type alias
            final fragmentChapter = Fragment$ChapterWithMangaDto.fromJson(
              node as Map<String, dynamic>
            );
            
            // Group chapters by manga ID
            if (!mangaToChapters.containsKey(fragmentChapter.manga.id)) {
              mangaToChapters[fragmentChapter.manga.id] = [];
            }
            mangaToChapters[fragmentChapter.manga.id]!.add(fragmentChapter);
          } catch (e) {
            // Log error but continue with other chapters
            logger.e('Error converting chapter: $e');
          }
        }
        
        // Second pass - for each manga, find the most recently read chapter that isn't complete
        final chapterNodes = <ChapterWithMangaDto>[];
        
        for (final mangaId in mangaToChapters.keys) {
          final mangaChapters = mangaToChapters[mangaId]!;
          
          // First, check if the manga has any unfinished chapters (read progress but not fully read)
          final hasUnfinishedChapters = mangaChapters.any((chapter) => 
            chapter.lastPageRead > 0 && !chapter.isRead
          );
          
          // Only show manga that have unfinished chapters
          if (hasUnfinishedChapters) {
            // Sort by lastReadAt (descending) to get the most recently accessed chapter first
            mangaChapters.sort((a, b) {
              // Compare timestamps (higher = more recent)
              final aTimestamp = int.tryParse(a.lastReadAt) ?? 0;
              final bTimestamp = int.tryParse(b.lastReadAt) ?? 0;
              return bTimestamp.compareTo(aTimestamp);
            });
            
            // Find the most recently read chapter that has progress but isn't complete
            for (final chapter in mangaChapters) {
              if (chapter.lastPageRead > 0 && !chapter.isRead) {
                chapterNodes.add(chapter);
                break;
              }
            }
          }
        }
        
        if (inProgressChapters['pageInfo'] != null && inProgressChapters['pageInfo']['hasNextPage'] == false) {
          controller.appendLastPage(chapterNodes);
        } else {
          controller.appendPage(chapterNodes, pageKey + 1);
        }
      }
    } catch (e) {
      controller.error = e;
    }
  }
}

@riverpod
Future<List<ChapterWithMangaDto>> onDeckItems(OnDeckItemsRef ref) async {
  return ref.watch(onDeckControllerProvider.future);
}

