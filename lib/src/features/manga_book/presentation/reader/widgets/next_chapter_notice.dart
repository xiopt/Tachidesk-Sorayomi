// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../domain/chapter/chapter_model.dart';

class NextChapterNotice extends ConsumerWidget {
  const NextChapterNotice({
    super.key,
    required this.nextChapter,
    required this.mangaId,
    required this.showAction,
    required this.transVertical,
  });
  
  final ChapterDto nextChapter;
  final int mangaId;
  final bool showAction;
  final bool transVertical;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: KEdgeInsets.a16.size,
      padding: KEdgeInsets.a16.size,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.nextChapterComing,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Text(
            nextChapter.name,
            style: context.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (showAction) ...[
            const Gap(16),
            FilledButton(
              onPressed: () => context.pushReplacement(
                '/manga/$mangaId/chapter/${nextChapter.id}'
              ),
              child: Text(context.l10n.nextChapter(nextChapter.name)),
            ),
          ],
        ],
      ),
    );
  }
}