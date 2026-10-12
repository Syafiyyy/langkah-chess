import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/app_motion.dart';
import '../../app/theme/app_type.dart';

/// "Thinking" with three softly pulsing dots (opacity only). With reduced
/// motion it is static text; the word carries the meaning either way.
class ThinkingDots extends StatelessWidget {
  const ThinkingDots({super.key, this.style = AppType.meta});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return Text('Thinking…', style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Thinking', style: style),
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
