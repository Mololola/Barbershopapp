import 'package:flutter/material.dart';

/// From this width the app switches to its desktop layout: a sidebar instead
/// of the bottom tabs, and content laid out in columns. Decided by width,
/// not by device, so a tablet held sideways gets it as well as the website.
const wideLayoutWidth = 900.0;

bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= wideLayoutWidth;

/// Side by side when there's room for each child to be at least
/// [minChildWidth] wide, stacked (the phone layout) otherwise. Children are
/// top-aligned; [flex] gives their relative widths.
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.flex,
    this.minChildWidth = 360,
    this.spacing = 20,
  });

  final List<Widget> children;
  final List<int>? flex;
  final double minChildWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= children.length * minChildWidth + (children.length - 1) * spacing;
        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(flex: flex?[i] ?? 1, child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// How many equal columns of at least [minWidth] fit in [width], between
/// [min] and [max] — for tile grids that use the extra width on a desktop.
int columnsFor(double width, {double minWidth = 200, int min = 2, int max = 4}) =>
    (width / minWidth).floor().clamp(min, max);

/// Equal-width tiles wrapped into as many columns as fit (at least
/// [minTileWidth] each, up to [maxColumns]) — for card lists on the wide
/// layout. Tiles in a row keep their own heights, top-aligned.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minTileWidth = 320, this.maxColumns = 3, this.spacing = 12});

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth, minWidth: minTileWidth + spacing, min: 1, max: maxColumns);
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: tileWidth, child: child)],
        );
      },
    );
  }
}
