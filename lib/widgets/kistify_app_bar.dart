import 'package:flutter/material.dart';

import 'kistify_mark.dart';

/// A standard AppBar with the Kistify brand mark pinned before the title,
/// so every screen — not just the group list — visibly carries the app's
/// identity in a consistent, on-brand header (colors come from the app's
/// shared AppBarTheme, so this stays in sync automatically).
class KistifyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const KistifyAppBar({super.key, required this.title, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KistifyMark(size: 24),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
