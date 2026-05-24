import 'package:flutter/material.dart';

/// Wraps any widget with pointer cursor + tap handler.
/// Use instead of GestureDetector for clickable containers on web.
class Tappable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}
