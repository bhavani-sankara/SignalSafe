import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// A soft grey placeholder block. Shown while content "loads" so the layout
/// never jumps, instead of a spinner.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.elevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Runs a light sweep across its skeleton children, on a loop.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return child
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1300.ms,
          delay: 150.ms,
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.75),
        );
  }
}

/// Placeholder that matches the route summary in the directions sheet.
class RouteSheetSkeleton extends StatelessWidget {
  const RouteSheetSkeleton({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: TextStyle(color: pal.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SkeletonBox(width: 120, height: 30, radius: 10),
                      SizedBox(width: 10),
                      SkeletonBox(width: 60, height: 18),
                      Spacer(),
                      SkeletonBox(width: 44, height: 36, radius: 12),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 220, height: 12),
                  const SizedBox(height: 16),
                  const SkeletonBox(height: 10, radius: 5),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        SkeletonBox(
                          width: i == 0 ? 104 : 92,
                          height: 40,
                          radius: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < 3; i++) ...[
                    const Row(
                      children: [
                        SkeletonBox(width: 36, height: 36, radius: 12),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 160, height: 12),
                              SizedBox(height: 6),
                              SkeletonBox(width: 90, height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic list placeholder used by screens while their data loads.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: 28, radius: 10),
            const SizedBox(height: 24),
            const SkeletonBox(height: 140, radius: 22),
            const SizedBox(height: 20),
            for (var i = 0; i < rows; i++) ...[
              const Row(
                children: [
                  SkeletonBox(width: 44, height: 44, radius: 14),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 120, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}
