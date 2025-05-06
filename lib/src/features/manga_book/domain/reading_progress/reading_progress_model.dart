// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../chapter_batch/chapter_batch_model.dart';

part 'reading_progress_model.freezed.dart';
part 'reading_progress_model.g.dart';

/// Model to store chapter reading progress locally
@freezed
class ReadingProgressDto with _$ReadingProgressDto {
  /// Create a new reading progress entry
  const factory ReadingProgressDto({
    required int chapterId,
    required int pageIndex,
    required bool isRead,
    required DateTime timestamp,
    @Default(false) bool synced,
  }) = _ReadingProgressDto;

  /// Create from JSON
  factory ReadingProgressDto.fromJson(Map<String, dynamic> json) =>
      _$ReadingProgressDtoFromJson(json);
  
  /// Internal constructor for extension methods
  const ReadingProgressDto._();
  
  /// Convert to ChapterChange for API sync
  ChapterChange toChapterChange() => ChapterChange(
    lastPageRead: isRead ? 0 : pageIndex,
    isRead: isRead,
  );
}

/// Model for managing a queue of reading progress updates
@freezed
class ReadingProgressQueue with _$ReadingProgressQueue {
  /// Create a new reading progress queue
  const factory ReadingProgressQueue({
    @Default([]) List<ReadingProgressDto> queue,
  }) = _ReadingProgressQueue;

  /// Create from JSON
  factory ReadingProgressQueue.fromJson(Map<String, dynamic> json) =>
      _$ReadingProgressQueueFromJson(json);
}