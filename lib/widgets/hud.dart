import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_theme.dart';

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? pal.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pal.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SignalChip extends StatelessWidget {
  const SignalChip({
    super.key,
    required this.level,
    this.label,
    this.compact = false,
  });

  final String level;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final color = pal.level(level);
    final text = label ?? switch (level) {
          'good' => 'Good',
          'moderate' => 'Moderate',
          'weak' => 'Weak',
          _ => 'No signal',
        };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.ibmPlexSans(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: pal.text,
            ),
          ),
        ],
      ),
    );
  }
}

class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final label = switch (source) {
      'measured' => 'Measured',
      'metadata' => 'Tower metadata',
      'community' => 'Community',
      _ => 'Estimated',
    };
    return Text(
      label,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 11,
        letterSpacing: 0.2,
        color: pal.muted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.sos = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bg = sos
        ? pal.sos
        : selected
            ? pal.beacon
            : pal.glass;
    final fg = sos || selected
        ? (sos ? Colors.white : const Color(0xFF06201C))
        : pal.text;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.palette.muted,
        ),
      ),
    );
  }
}

IconData categoryIcon(String category) {
  return switch (category) {
    'hospital' => PhosphorIconsRegular.heartbeat,
    'police' => PhosphorIconsRegular.shieldChevron,
    'fuel' => PhosphorIconsRegular.gasPump,
    'hotel' => PhosphorIconsRegular.bed,
    'restaurant' => PhosphorIconsRegular.forkKnife,
    'atm' => PhosphorIconsRegular.creditCard,
    'recovery' => PhosphorIconsRegular.wifiHigh,
    'blackspot' => PhosphorIconsRegular.warning,
    'destination' => PhosphorIconsRegular.mapPin,
    'origin' => PhosphorIconsRegular.navigationArrow,
    _ => PhosphorIconsRegular.mapPin,
  };
}

String operatorLabel(String id) => switch (id) {
      'jio' => 'Jio',
      'airtel' => 'Airtel',
      'vi' => 'Vi',
      'bsnl' => 'BSNL',
      _ => 'All networks',
    };

String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}
