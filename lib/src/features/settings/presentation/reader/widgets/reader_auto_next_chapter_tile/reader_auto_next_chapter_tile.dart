// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../../constants/db_keys.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/mixin/shared_preferences_client_mixin.dart';

part 'reader_auto_next_chapter_tile.g.dart';

@riverpod
class AutoNextChapterToggle extends _$AutoNextChapterToggle
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.autoNextChapter);
}

class AutoNextChapterToggleTile extends HookConsumerWidget {
  const AutoNextChapterToggleTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: const Icon(Icons.skip_next_rounded),
      title: Text(context.l10n.readerAutoNextChapter),
      subtitle: Text(context.l10n.readerAutoNextChapterDescription),
      onChanged: ref.read(autoNextChapterToggleProvider.notifier).update,
      value: ref.watch(autoNextChapterToggleProvider).ifNull(),
    );
  }
}
