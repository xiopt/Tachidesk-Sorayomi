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
    return [];
  }

  Future<void> fetchInProgressChapters({
    required int pageKey,
    required PagingController<int, ChapterWithMangaDto> controller,
  }) async {
    try {
      final repository = ref.read(onDeckRepositoryProvider);
      final inProgressChapters = await repository.getInProgressChaptersPage(
        pageNo: pageKey,
      );
      
      if (inProgressChapters == null || inProgressChapters['nodes'] == null || inProgressChapters['nodes'].isEmpty) {
        controller.appendLastPage([]);
      } else {
        // Convert the dynamic map data to ChapterWithMangaDto objects
        final nodes = inProgressChapters['nodes'] as List;
        final chapterNodes = <ChapterWithMangaDto>[];
        
        for (final node in nodes) {
          try {
            // Create a Fragment$ChapterWithMangaDto first, then use the type alias
            final fragmentChapter = Fragment$ChapterWithMangaDto.fromJson(
              node as Map<String, dynamic>
            );
            // ChapterWithMangaDto is just a type alias for Fragment$ChapterWithMangaDto
            // so we can add it directly to our typed list
            chapterNodes.add(fragmentChapter);
          } catch (e) {
            // Log error but continue with other chapters
            logger.e('Error converting chapter: $e');
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