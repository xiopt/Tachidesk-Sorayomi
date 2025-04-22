// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

part of '../router_config.dart';

// OnDeck Branch
class OnDeckBranch extends StatefulShellBranchData {
  static final $initialLocation = const OnDeckRoute().location;
  const OnDeckBranch();
}

class OnDeckRoute extends GoRouteData {
  const OnDeckRoute();
  @override
  Widget build(context, state) => const OnDeckScreen();
}