// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:graphql/client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../global_providers/global_providers.dart';
import '../../../../graphql/__generated__/schema.graphql.dart';
import '../updates/graphql/__generated__/query.graphql.dart';

part 'on_deck_repository.g.dart';

class OnDeckRepository {
  const OnDeckRepository(this.client);
  final GraphQLClient client;

  Future<dynamic> getInProgressChaptersPage({
    int pageNo = 0,
  }) async {
    final result = await client.query$GetChapterWithMangaPage(
      Options$Query$GetChapterWithMangaPage(
        variables: Variables$Query$GetChapterWithMangaPage(
          filter: Input$ChapterFilterInput(
            inLibrary: Input$BooleanFilterInput(equalTo: true),
            isRead: Input$BooleanFilterInput(equalTo: false),
            lastPageRead: Input$IntFilterInput(greaterThan: 0),
          ),
          first: 20,
          offset: pageNo * 20,
          order: [
            Input$ChapterOrderInput(
              by: Enum$ChapterOrderBy.LAST_READ_AT,
              byType: Enum$SortOrder.DESC,
            ),
          ],
        ),
      ),
    );
    
    if (result.hasException) {
      throw result.exception!;
    }
    
    return result.data != null ? result.data!['chapters'] : null;
  }
}

@riverpod
OnDeckRepository onDeckRepository(OnDeckRepositoryRef ref) =>
    OnDeckRepository(ref.watch(graphQlClientProvider));