// lib/features/shared/refreshable_empty.dart
// An empty-state placeholder that still lets RefreshIndicator work: a plain
// Center can't be scrolled, so pull-to-refresh never starts on it.

import 'package:flutter/material.dart';

class RefreshableEmpty extends StatelessWidget {
  final Widget child;
  const RefreshableEmpty({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// For a RefreshIndicator around a TabBarView: the vertical lists inside
/// the tabs report scrolls one level below the horizontal page view.
bool tabbedRefreshPredicate(ScrollNotification n) => n.depth <= 1;
