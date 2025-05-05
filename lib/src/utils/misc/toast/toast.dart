// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../constants/app_sizes.dart';
import '../../../routes/router_config.dart';
import '../../extensions/custom_extensions.dart';

part 'toast.g.dart';

class Toast {
  Toast(this._context) {
    _fToast = FToast().init(_context);
  }
  final BuildContext _context;
  late FToast _fToast;

  void show(
    String msg, {
    bool withMicrotask = false,
    bool instantShow = false,
  }) {
    toast() {
      if (instantShow) close();
      _fToast.showToast(
        child: ToastWidget(
          text: msg,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        ),
        gravity: ToastGravity.BOTTOM,
      );
    }

    if (withMicrotask) {
      Future.microtask(toast);
    } else {
      toast();
    }
  }

  void showError(
    String error, {
    bool withMicrotask = false,
    bool instantShow = false,
  }) {
    toast() {
      if (instantShow) close();
      _fToast.showToast(
        child: ToastWidget(
          text: error,
          backgroundColor: Colors.red.shade400,
          textColor: Colors.white,
        ),
        gravity: ToastGravity.TOP,
      );
    }

    if (withMicrotask) {
      Future.microtask(toast);
    } else {
      toast();
    }
  }

  void close() => _fToast.removeCustomToast();
}

class ToastWidget extends StatelessWidget {
  const ToastWidget({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });
  final String text;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  @override
  Widget build(BuildContext context) {
    // Determine text color based on the background
    Color resolveTextColor(BuildContext context) {
      if (textColor != null) {
        return textColor!;
      }
      
      // If background is dark (like black), use white text
      if (backgroundColor != null && backgroundColor == Colors.black) {
        return Colors.white;
      }
      
      // Otherwise use system theme color
      return context.colorScheme.onPrimaryContainer;
    }
    
    Widget textWidget = Text(
      text,
      style: TextStyle(color: resolveTextColor(context)),
      textAlign: TextAlign.center,
    );
    return Container(
      padding: KEdgeInsets.h16v8.size,
      decoration: BoxDecoration(
        borderRadius: KBorderRadius.r16.radius,
        color: backgroundColor ?? context.colorScheme.primaryContainer,
      ),
      child: icon != null
          ? Row(
              children: [
                icon!,
                const Gap(16),
                textWidget,
              ],
            )
          : textWidget,
    );
  }
}

@riverpod
Toast? toast(Ref ref) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    return null;
  }
  return Toast(context);
}
