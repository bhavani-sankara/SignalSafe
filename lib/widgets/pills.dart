import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Pill, chip and round-button primitives measured off Google Maps
/// screenshots (Nov 2026) and its Figma kit, so every pill in the app shares
/// one set of sizes:
///
/// * Action pill: 40 tall, 16 leading / 20 trailing padding, 18 icon, 8 gap,
///   15 medium label, 8 between pills.
/// * Filter chip: 32 tall, 8 radius, 12 padding, 13 medium label.
/// * Header icon button: 36 circle on a light grey fill, 20 icon.
/// * Suggestion pill: 38 tall stadium on a slightly darker tint than its card.
abstract final class PillMetrics {
  static const height = 40.0;
  static const gap = 8.0;
  static const iconSize = 18.0;
  static const chipHeight = 32.0;
  static const chipRadius = 8.0;
}

enum PillTone { filled, tonal, elevated }

/// A Maps-style action pill. Exactly one [PillTone.filled] per surface.
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = PillTone.tonal,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (Color bg, Color fg) = switch (tone) {
      PillTone.filled => (pal.beacon, dark ? pal.ink : Colors.white),
      PillTone.tonal => (
        dark ? pal.secondaryContainer : const Color(0xFFDCE7FD),
        dark ? pal.onSecondaryContainer : const Color(0xFF0F3A94),
      ),
      PillTone.elevated => (
        dark ? pal.elevated : Colors.white,
        dark ? pal.beacon : const Color(0xFF1F5BD6),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PillMetrics.height / 2),
        boxShadow: tone == PillTone.elevated
            ? softShadow(context, strength: 1.2)
            : null,
      ),
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: PillMetrics.height,
            padding: EdgeInsets.only(left: icon == null ? 20 : 16, right: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: PillMetrics.iconSize, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of [ActionPill]s that bleeds off the right edge, so you
/// can tell there's more to scroll to.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children, this.padding = 16});

  final List<Widget> children;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PillMetrics.height + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: PillMetrics.gap),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// 36dp circle icon button on a light grey fill (sheet header actions).
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? pal.elevated : const Color(0xFFEEF1F5),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 19, color: pal.text),
          ),
        ),
      ),
    );
  }
}

/// Maps-style filter chip: 32 tall, 8 radius, grey fill, a check when on.
/// With [dropdown] it shows a caret instead and never shows a check.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.dropdown = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final bool dropdown;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final on = selected && !dropdown;
    final bg = on
        ? (dark ? pal.secondaryContainer : const Color(0xFFDCE7FD))
        : (dark ? pal.elevated : const Color(0xFFF0F2F5));
    final fg = on
        ? (dark ? pal.onSecondaryContainer : const Color(0xFF0F3A94))
        : pal.text;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.enter,
          height: PillMetrics.chipHeight,
          padding: EdgeInsets.only(
            left: on || icon != null ? 8 : 12,
            right: dropdown ? 6 : 12,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(PillMetrics.chipRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on)
                Icon(Icons.check_rounded, size: 18, color: fg)
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              if (on || icon != null) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (dropdown) ...[
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down_rounded, size: 22, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stadium suggestion inside a tinted card ("↪ Things to do this weekend?").
class SuggestionPill extends StatelessWidget {
  const SuggestionPill({
    super.key,
    required this.label,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF26324A) : const Color(0xFFDFE6F3),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.only(left: 12, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: pal.text),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: pal.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
