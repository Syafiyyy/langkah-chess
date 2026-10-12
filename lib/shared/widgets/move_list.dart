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

  /// The strip (for layout tests).
  static const stripKey = ValueKey('move-strip');

  /// The pill drawn around the selected move.
  static const selectedPillKey = ValueKey('move-pill');

  /// Strip height: a 48 dp tap row plus the 1 px border top and bottom.
  static const double height = _MoveListState.itemHeight + 2;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelectedAfterFrame();
  }

  @override
  void didUpdateWidget(MoveList old) {
    super.didUpdateWidget(old);
    // Keep the selected move in view: new moves, browsing, jumps.
    if (widget.selectedPly != old.selectedPly ||
        widget.sans.length != old.sans.length) {
      _revealSelectedAfterFrame();
    }
  }

  void _revealSelectedAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 0.5);
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(0); // start position selected
      }
    });
  }

  ({String symbol, Color color})? _mark(int i) =>
      i < widget.marks.length ? widget.marks[i] : null;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Tap row height (48 dp target); the pill inside is [_pillHeight].
  static const double itemHeight = 48;
  static const double _pillHeight = 28;

  @override
  Widget build(BuildContext context) {
    // An L1 card on the 16 px gutter, the same width as the tiles below.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: _strip(),
    );
  }

  Widget _strip() {
    return Container(
      key: MoveList.stripKey,
      height: MoveList.height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(AppRadius.md),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: widget.sans.isEmpty
          ? const Center(
              child: Text('Moves appear here', style: AppType.secondary),
            )
          // Not a lazy ListView: the scroll extent must be exact so the
          // newest move can be scrolled fully into view on first open.
          : SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  for (var i = 0; i < widget.sans.length; i++) _item(i),
                ],
              ),
            ),
    );
  }

  Widget _item(int i) {
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
            child: Text(
              '${i ~/ 2 + 1}.',
              style: AppType.move.copyWith(color: AppColors.textMuted),
            ),
          ),
        Semantics(
          key: selected ? _selectedKey : null,
          button: true,
          selected: selected,
          child: InkWell(
            borderRadius: const BorderRadius.all(AppRadius.pill),
            onTap: () => widget.onSelect(ply),
            child: SizedBox(
              // 48 dp tap area; the compact pill is centred inside it.
              height: itemHeight,
              child: Center(
                child: Container(
                  key: selected ? MoveList.selectedPillKey : null,
                  height: _pillHeight,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: selected
                      ? const BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.all(AppRadius.pill),
                        )
                      : null,
                  child: Text.rich(
                    TextSpan(
                      text: widget.sans[i],
                      children: [
                        if (_mark(i) case final mark?)
                          TextSpan(
                            text: mark.symbol,
                            style: TextStyle(
                              color: selected ? AppColors.onAccent : mark.color,
                            ),
                          ),
                      ],
                    ),
                    style: AppType.move.copyWith(
                      color: selected ? AppColors.onAccent : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
