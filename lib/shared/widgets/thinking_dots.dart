import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/app_motion.dart';
import '../../app/theme/app_type.dart';

/// "Thinking" (or [label]) with three softly pulsing dots (opacity only).
/// With reduced motion it is static text; the words carry the meaning either
/// way.
class ThinkingDots extends StatelessWidget {
  const ThinkingDots({
    super.key,
    this.style = AppType.meta,
    this.label = 'Thinking',
  });

  final TextStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return Text('$label…', style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, style: style)),
        for (var i = 0; i < 3; i++)
          Text('.', style: style)
              .animate(
                onPlay: (c) => c.repeat(reverse: true),
                delay: AppMotion.fast * i,
              )
              .fade(
                begin: 0.25,
                duration: AppMotion.slow,
                curve: AppMotion.curve,
              ),
      ],
    );
  }
}
