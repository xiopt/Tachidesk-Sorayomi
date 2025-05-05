// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that displays the reading progress for a chapter
class ChapterProgressIndicator extends StatelessWidget {
  const ChapterProgressIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.height = 4.0,
    this.backgroundColor,
    this.progressColor,
    this.showText = true,
    this.textStyle,
    this.borderRadius,
    this.trailing,
  });

  /// Current page number (0-based)
  final int currentPage;

  /// Total number of pages in the chapter
  final int totalPages;

  /// Height of the progress bar
  final double height;

  /// Background color of the progress bar
  final Color? backgroundColor;

  /// Color of the progress indicator
  final Color? progressColor;

  /// Whether to show text indicating the progress
  final bool showText;

  /// Style for the progress text
  final TextStyle? textStyle;

  /// Border radius for the progress bar
  final BorderRadius? borderRadius;

  /// Widget to display after the progress indicator
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Ensure we have valid values
    final validCurrentPage = max(currentPage, 0);
    final validTotalPages = max(totalPages, 1);
    
    // Calculate progress percentage
    final progress = validCurrentPage / validTotalPages;
    
    // Format the progress text
    final progressText = '${validCurrentPage + 1}/$validTotalPages';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showText)
          Row(
            children: [
              Text(
                progressText,
                style: textStyle ?? 
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(2.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: backgroundColor ?? 
                Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            color: progressColor ?? Theme.of(context).colorScheme.primary,
            minHeight: height,
          ),
        ),
      ],
    );
  }
}