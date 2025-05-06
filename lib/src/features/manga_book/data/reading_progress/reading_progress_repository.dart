// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/reading_progress/reading_progress_model.dart';
import '../../../../global_providers/global_providers.dart';
import '../manga_book/manga_book_repository.dart';

part 'reading_progress_repository.g.dart';

/// Repository for managing local reading progress
class ReadingProgressRepository {
  const ReadingProgressRepository(this.sharedPreferences);
  final SharedPreferences sharedPreferences;

  /// Storage key prefix for progress items
  static const String _progressKeyPrefix = 'reading_progress_';
  
  /// Storage key for sync queue
  static const String _syncQueueKey = 'reading_progress_sync_queue';

  /// Get local progress for a chapter
  ReadingProgressDto? getProgress(int chapterId) {
    final key = _getProgressKey(chapterId);
    final jsonString = sharedPreferences.getString(key);
    if (jsonString == null) return null;
    
    try {
      return ReadingProgressDto.fromJson(jsonDecode(jsonString));
    } catch (e) {
      // If parsing fails, remove corrupted data
      sharedPreferences.remove(key);
      return null;
    }
  }

  /// Save reading progress locally
  Future<bool> saveProgress(ReadingProgressDto progress) async {
    final key = _getProgressKey(progress.chapterId);
    return await sharedPreferences.setString(
      key,
      jsonEncode(progress),
    );
  }
  
  /// Get the sync queue
  ReadingProgressQueue getSyncQueue() {
    final jsonString = sharedPreferences.getString(_syncQueueKey);
    if (jsonString == null) return const ReadingProgressQueue();
    
    try {
      return ReadingProgressQueue.fromJson(jsonDecode(jsonString));
    } catch (e) {
      // If parsing fails, return empty queue
      return const ReadingProgressQueue();
    }
  }
  
  /// Add progress to sync queue
  Future<bool> addToSyncQueue(ReadingProgressDto progress) async {
    final queue = getSyncQueue();
    
    // Check if we already have an entry for this chapter
    final existingIndex = queue.queue.indexWhere(
      (item) => item.chapterId == progress.chapterId,
    );
    
    final newQueue = List<ReadingProgressDto>.from(queue.queue);
    
    if (existingIndex >= 0) {
      // Replace existing entry with newer one
      newQueue[existingIndex] = progress;
    } else {
      // Add new entry
      newQueue.add(progress);
    }
    
    return await sharedPreferences.setString(
      _syncQueueKey,
      jsonEncode(ReadingProgressQueue(queue: newQueue)),
    );
  }
  
  /// Remove item from sync queue
  Future<bool> removeFromSyncQueue(int chapterId) async {
    final queue = getSyncQueue();
    final newQueue = queue.queue.where(
      (item) => item.chapterId != chapterId,
    ).toList();
    
    return await sharedPreferences.setString(
      _syncQueueKey,
      jsonEncode(ReadingProgressQueue(queue: newQueue)),
    );
  }
  
  /// Get progress key for a specific chapter
  String _getProgressKey(int chapterId) => '$_progressKeyPrefix$chapterId';
}

/// Provider for reading progress repository
@riverpod
ReadingProgressRepository readingProgressRepository(
  Ref ref,
) =>
    ReadingProgressRepository(ref.watch(sharedPreferencesProvider));

/// Global provider for the background sync service
@riverpod
class ProgressSyncService extends _$ProgressSyncService {
  Timer? _syncTimer;
  static const Duration _syncInterval = Duration(seconds: 30);
  
  @override
  Future<void> build() async {
    // Clean up timer on dispose
    ref.onDispose(() {
      _syncTimer?.cancel();
    });
    
    // Start periodic sync
    _startPeriodicSync();
    
    return;
  }
  
  // Start timer for periodic syncing
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => syncPendingUpdates());
  }
  
  // Sync all pending updates from the queue
  Future<void> syncPendingUpdates() async {
    final repository = ref.read(readingProgressRepositoryProvider);
    final apiRepository = ref.read(mangaBookRepositoryProvider);
    final queue = repository.getSyncQueue();
    
    if (queue.queue.isEmpty) return;
    
    // Sort by timestamp (oldest first) to maintain proper order
    final sortedQueue = List<ReadingProgressDto>.from(queue.queue)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    for (final progress in sortedQueue) {
      try {
        // Convert local model to API model and sync
        await apiRepository.putChapter(
          chapterId: progress.chapterId,
          patch: progress.toChapterChange(),
        );
        
        // If successful, remove from queue
        await repository.removeFromSyncQueue(progress.chapterId);
        
        // Mark as synced in local storage
        await repository.saveProgress(progress.copyWith(synced: true));
      } catch (e) {
        // If sync fails, leave in queue for retry later
        continue;
      }
    }
  }
  
  // Force immediate sync of pending updates
  Future<void> forceSyncNow() async {
    await syncPendingUpdates();
  }
  
  // Sync a specific chapter immediately
  Future<bool> syncChapter(int chapterId) async {
    final repository = ref.read(readingProgressRepositoryProvider);
    final apiRepository = ref.read(mangaBookRepositoryProvider);
    final progress = repository.getProgress(chapterId);
    
    if (progress == null) return false;
    
    try {
      // Try to sync with server
      await apiRepository.putChapter(
        chapterId: progress.chapterId,
        patch: progress.toChapterChange(),
      );
      
      // If successful, mark as synced and remove from queue
      await repository.saveProgress(progress.copyWith(synced: true));
      await repository.removeFromSyncQueue(chapterId);
      return true;
    } catch (e) {
      return false;
    }
  }
}