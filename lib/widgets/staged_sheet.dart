import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Shows a modal sheet the way a calm maps app does it: the dim backdrop
/// fades in first, then the sheet glides up a beat later. Dragging the sheet
/// down dismisses it, and the backdrop follows the finger.
Future<T?> showStagedSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  Widget? leading,
  bool showClose = true,
  bool useRootNavigator = true,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _StagedSheetRoute<T>(
      builder: builder,
      title: title,
      subtitle: subtitle,
      leading: leading,
      showClose: showClose,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: useRootNavigator).context,
      ),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _StagedSheetRoute<T> extends PopupRoute<T> {
  _StagedSheetRoute({
    required this.builder,
    required this.capturedThemes,
    required this.showClose,
    this.title,
    this.subtitle,
    this.leading,
    this.barrierLabel,
  });

  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final bool showClose;

  /// True while the finger is dragging the sheet; motion is then 1:1.
  final ValueNotifier<bool> _dragging = ValueNotifier(false);

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null; // we draw our own staged scrim

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => Motion.modal;

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 260);

  @override
  void dispose() {
    _dragging.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final content = _SheetBody(
      title: title,
      subtitle: subtitle,
      leading: leading,
      showClose: showClose,
      child: Builder(builder: builder),
    );
    return capturedThemes.wrap(
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: BottomSheet(
            animationController: controller,
            enableDrag: true,
            showDragHandle: false,
            onDragStart: (_) => _dragging.value = true,
            onDragEnd: (_, {required isClosing}) => _dragging.value = false,
            onClosing: () {
              if (isCurrent) Navigator.of(context).pop();
            },
            builder: (_) => content,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildModalBarrier() {
    // Scrim fades in over the first ~35% of the transition, ahead of the
    // sheet, and dims to ~40%.
    return AnimatedBuilder(
      animation: Listenable.merge([animation!, _dragging]),
      builder: (context, _) {
        final t = _dragging.value
            ? animation!.value
            : const Interval(0, 0.4, curve: Curves.easeOut)
                .transform(animation!.value);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          child: Semantics(
            label: barrierLabel,
            button: true,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.4 * t),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, _dragging]),
      builder: (context, child) {
        final v = animation.value;
        final reversing = animation.status == AnimationStatus.reverse;
        final double t;
        if (_dragging.value) {
          t = v;
        } else if (reversing) {
          t = Curves.easeInCubic.transform(v);
        } else {
          // Sheet starts a beat after the scrim.
          t = const Interval(0.15, 1, curve: Motion.enter).transform(v);
        }
        return FractionalTranslation(
          translation: Offset(0, 1 - t),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.child,
    required this.showClose,
    this.title,
    this.subtitle,
    this.leading,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final hasHeader = title != null || showClose;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 9, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: pal.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (hasHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(color: pal.muted, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (showClose) const SheetCloseButton(),
                ],
              ),
            ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Round grey ✕ used at the top right of every sheet.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return IconButton(
      tooltip: 'Close',
      onPressed: onTap ?? () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        backgroundColor: pal.elevated,
        foregroundColor: pal.text,
        fixedSize: const Size(36, 36),
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(PhosphorIconsRegular.x, size: 18),
    );
  }
}
