// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../domain/chapter/chapter_model.dart';
import '../../../domain/manga/manga_model.dart';

class ChapterTransitionIndicator extends ConsumerWidget {
  const ChapterTransitionIndicator({
    super.key,
    required this.chapter,
    required this.manga,
    required this.isPreviousChapter,
    required this.scrollDirection,
  });

  final ChapterDto chapter;
  final MangaDto manga;
  final bool isPreviousChapter;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      margin: KEdgeInsets.a8.size,
      padding: KEdgeInsets.a16.size,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest.withAlpha(250),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.theme.colorScheme.shadow.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: context.theme.colorScheme.primary.withAlpha(100),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPreviousChapter 
                  ? Icons.arrow_upward_rounded 
                  : Icons.arrow_downward_rounded,
                color: context.theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isPreviousChapter
                    ? "Previous Chapter"
                    : "Next Chapter",
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            chapter.name,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}