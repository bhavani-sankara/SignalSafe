import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_theme.dart';

/// iOS-style large title app bar for tab root screens: big bold title on
/// the left, actions on the right, no elevation.
PreferredSizeWidget iosLargeAppBar(
  BuildContext context,
  String title, {
  List<Widget> actions = const [],
}) {
  return AppBar(
    centerTitle: false,
    toolbarHeight: 64,
    titleSpacing: 20,
    automaticallyImplyLeading: false,
    title: Text(
      title,
      style: TextStyle(
        color: context.palette.text,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
      ),
    ),
    actions: [...actions, const SizedBox(width: 8)],
  );
}

/// An inset grouped section, as in the iOS Settings app: a small uppercase
/// header, a rounded white group with hairline separators, optional footer.
class IosSection extends StatelessWidget {
  const IosSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent = 16,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  color: pal.muted,
                  fontSize: 13,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          Material(
            color: pal.surface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.only(left: dividerIndent),
                      child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: pal.border,
                      ),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(color: pal.muted, fontSize: 13, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured rounded-square icon, like the glyphs in iOS Settings rows.
class IosIconTile extends StatelessWidget {
  const IosIconTile({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

/// A row inside an [IosSection].
class IosRow extends StatelessWidget {
  const IosRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool? chevron;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final showChevron = chevron ?? onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: pal.text,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: pal.muted,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value!,
                    style: TextStyle(color: pal.muted, fontSize: 17),
                  ),
                ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: trailing!,
                ),
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    PhosphorIconsBold.caretRight,
                    size: 14,
                    color: pal.outline.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS switch row.
class IosSwitchRow extends StatelessWidget {
  const IosSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: IosRow(
        title: title,
        subtitle: subtitle,
        leading: leading,
        chevron: false,
        onTap: () => onChanged(!value),
        trailing: IosSwitch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class IosSwitch extends StatelessWidget {
  const IosSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      activeTrackColor: const Color(0xFF34C759),
      onChanged: onChanged,
    );
  }
}
