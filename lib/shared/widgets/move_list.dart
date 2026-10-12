import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_type.dart';

/// Horizontal SAN move list. [selectedPly] is the highlighted half-move
/// (1 = first move, 0 = start position). Tapping a move calls [onSelect]
/// with its ply. Optional [marks] (one per move) add a coloured symbol such
/// as "??" after the SAN.
class MoveList extends StatefulWidget {
  const MoveList({
    super.key,
    required this.sans,
    required this.selectedPly,
    required this.onSelect,
    this.marks = const [],
  });

  final List<String> sans;
  final int selectedPly;
  final ValueChanged<int> onSelect;
  final List<({String symbol, Color color})?> marks;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(MoveList old) {
    super.didUpdateWidget(old);
    // Follow the game: keep the newest move in view.
    if (widget.sans.length > old.sans.length &&
        widget.selectedPly == widget.sans.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  ({String symbol, Color color})? _mark(int i) =>
      i < widget.marks.length ? widget.marks[i] : null;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sans.isEmpty) {
      return const SizedBox(
        height: 40,
        child: Center(child: Text('Moves appear here', style: AppType.caption)),
      );
    }
    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: widget.sans.length,
        itemBuilder: (context, i) {
          final ply = i + 1;
          final selected = ply == widget.selectedPly;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i.isEven)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    right: AppSpacing.xs,
                  ),
                  child: Text('${i ~/ 2 + 1}.', style: AppType.caption),
                ),
              InkWell(
                borderRadius: const BorderRadius.all(AppRadius.sm),
                onTap: () => widget.onSelect(ply),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surfaceRaised : null,
                    borderRadius: const BorderRadius.all(AppRadius.sm),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: widget.sans[i],
                      children: [
                        if (_mark(i) case final mark?)
                          TextSpan(
                            text: mark.symbol,
                            style: TextStyle(color: mark.color),
                          ),
                      ],
                    ),
                    style: AppType.label.copyWith(
                      color: selected ? AppColors.accent : AppColors.text,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
