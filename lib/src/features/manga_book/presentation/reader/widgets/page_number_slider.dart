// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../utils/extensions/custom_extensions.dart';

class PageNumberSlider extends HookWidget {
  const PageNumberSlider({
    super.key,
    required this.currentValue,
    required this.maxValue,
    required this.onChanged,
    this.inverted = false,
  });
  final int currentValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final bool inverted;
  
  @override
  Widget build(BuildContext context) {
    // Local state to track slider position for immediate updates
    final sliderPosition = useState<double>(currentValue.toDouble());
    
    // Keep track of last displayed value to reduce flickering
    final lastDisplayedValue = useRef<int>(currentValue);
    
    // Update slider position when current value changes from outside
    useEffect(() {
      // Only update if the value has actually changed, to minimize UI updates
      if (lastDisplayedValue.value != currentValue) {
        // Update the slider position
        sliderPosition.value = currentValue.toDouble();
        // Remember what we displayed 
        lastDisplayedValue.value = currentValue;
      }
      return null;
    }, [currentValue]);
    
    final sliderWidget = [
      // Use sliderPosition for displaying the current page number
      Text("${sliderPosition.value.round() + 1}"),
      Expanded(
        child: Transform.flip(
          flipX: inverted,
          child: Slider(
            value: min(sliderPosition.value, max(maxValue.toDouble() - 1, 0)),
            min: 0,
            max: max(maxValue.toDouble() - 1, 0), // Ensure max is always >= 0
            divisions: max(maxValue - 1, 1),
            // Update local state immediately
            onChanged: (val) {
              sliderPosition.value = val;
              onChanged(val.round());
            },
          ),
        ),
      ),
      Text("$maxValue"),
    ];
    
    return Card(
      color: context.theme.appBarTheme.backgroundColor?.withValues(alpha: .7),
      shape: RoundedRectangleBorder(
        borderRadius: KBorderRadius.r32.radius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: inverted ? sliderWidget.reversed.toList() : sliderWidget,
        ),
      ),
    );
  }
}
