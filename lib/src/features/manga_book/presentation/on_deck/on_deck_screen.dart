// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/hooks/paging_controller_hook.dart';
import '../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../widgets/emoticons.dart';
import '../../domain/chapter/chapter_model.dart';
import '../reader/controller/reader_controller.dart';
import '../updates/widgets/chapter_manga_list_tile.dart';
import 'controller/on_deck_controller.dart';

class OnDeckScreen extends HookConsumerWidget {
  const OnDeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = usePagingController<int, ChapterWithMangaDto>(firstPageKey: 0);
    final selectedChapters = useState<Map<int, ChapterDto>>({});

    useEffect(() {
      controller.addPageRequestListener((pageKey) {
        ref.read(onDeckControllerProvider.notifier).fetchInProgressChapters(
          pageKey: pageKey, 
          controller: controller
        );
      });
      return;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.onDeck),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          selectedChapters.value = ({});
          controller.refresh();
        },
        child: PagedListView(
          pagingController: controller,
          builderDelegate: PagedChildBuilderDelegate<ChapterWithMangaDto>(
            firstPageProgressIndicatorBuilder: (context) =>
                const CenterSorayomiShimmerIndicator(),
            firstPageErrorIndicatorBuilder: (context) => Emoticons(
              title: controller.error.toString(),
              button: TextButton(
                onPressed: () => controller.refresh(),
                child: Text(context.l10n.retry),
              ),
            ),
            noItemsFoundIndicatorBuilder: (context) => Emoticons(
              title: context.l10n.noMangaInProgress,
              button: TextButton(
                onPressed: () => controller.refresh(),
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
                      controller.itemList = [...?controller.itemList]
                        ..replaceRange(index, index + 1, [
                          item,
                        ]);
                    }
                  } catch (e) {
                    //
                  }
                },
                isSelected: selectedChapters.value.containsKey(item.id),
                canTapSelect: selectedChapters.value.isNotEmpty,
                toggleSelect: (ChapterDto val) {
                  if ((val.id).isNull) return;
                  selectedChapters.value =
                      (selectedChapters.value.toggleKey(val.id, val));
                },
              );
            },
          ),
        ),
      ),
    );
  }
}