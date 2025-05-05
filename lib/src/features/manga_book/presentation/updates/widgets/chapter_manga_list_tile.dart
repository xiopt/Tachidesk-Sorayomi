// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/chapter_progress/chapter_progress_indicator.dart';
import '../../../../../widgets/server_image.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../widgets/download_status_icon.dart';

class ChapterMangaListTile extends StatelessWidget {
  const ChapterMangaListTile({
    super.key,
    required this.chapterWithMangaDto,
    required this.updatePair,
    required this.toggleSelect,
    this.canTapSelect = false,
    this.isSelected = false,
  });
  final ChapterWithMangaDto chapterWithMangaDto;
  final AsyncCallback updatePair;
  final ValueChanged<ChapterWithMangaDto> toggleSelect;
  final bool canTapSelect;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = (chapterWithMangaDto.isRead).ifNull() ? Colors.grey : null;
    
    // Check if this chapter has progress but isn't fully read
    final hasProgress = chapterWithMangaDto.lastPageRead > 0 && 
                       !chapterWithMangaDto.isRead;
    
    // Always show progress indicator when there is progress on On Deck page
    final shouldShowProgress = hasProgress;
    
    return GestureDetector(
      onSecondaryTap: () => toggleSelect(chapterWithMangaDto),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((chapterWithMangaDto.isBookmarked).ifNull()) ...[
                  const Icon(Icons.bookmark_rounded, size: 20),
                  const Gap(4),
                ],
                Expanded(
                  child: Text(
                    chapterWithMangaDto.manga.title,
                    style: TextStyle(color: color),
                  ),
                ),
              ],
            ),
            leading: chapterWithMangaDto.manga.thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: KBorderRadius.r8.radius,
                    child: InkWell(
                      onTap: () => MangaRoute(
                        mangaId: chapterWithMangaDto.manga.id,
                      ).push(context),
                      child: ServerImage(
                        imageUrl: chapterWithMangaDto.manga.thumbnailUrl ?? "",
                        size: const Size.square(48),
                      ),
                    ),
                  )
                : null,
            subtitle:
                Text(chapterWithMangaDto.name, style: TextStyle(color: color)),
            trailing: DownloadStatusIcon(
              isDownloaded: (chapterWithMangaDto.isDownloaded).ifNull(),
              mangaId: chapterWithMangaDto.manga.id,
              chapter: chapterWithMangaDto,
              updateData: updatePair,
            ),
            selectedColor: context.theme.colorScheme.onSurface,
            selectedTileColor:
                context.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            selected: isSelected,
            onTap: () {
              if (canTapSelect) {
                toggleSelect(chapterWithMangaDto);
              } else {
                ReaderRoute(
                  mangaId: chapterWithMangaDto.manga.id,
                  chapterId: chapterWithMangaDto.id,
                  showReaderLayoutAnimation: true,
                ).push(context);
              }
            },
            onLongPress: () => toggleSelect(chapterWithMangaDto),
          ),
          // Show progress indicator if requested and chapter has progress
          if (shouldShowProgress)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
              child: ChapterProgressIndicator(
                currentPage: chapterWithMangaDto.lastPageRead,
                totalPages: chapterWithMangaDto.pageCount,
                textStyle: TextStyle(
                  fontSize: 11,
                  color: color ?? Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
