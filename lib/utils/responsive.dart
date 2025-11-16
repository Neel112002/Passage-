import 'package:flutter/material.dart';

/// Simple responsive helpers for consistent breakpoints and paddings across the app.
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

extension ResponsiveConstraintsX on BoxConstraints {
  bool get isMobile => maxWidth < AppBreakpoints.mobile;
  bool get isTablet => maxWidth >= AppBreakpoints.mobile && maxWidth < AppBreakpoints.desktop;
  bool get isDesktop => maxWidth >= AppBreakpoints.desktop;
}

class Responsive {
  /// Horizontal page padding that grows with screen size.
  static EdgeInsets pagePadding(BoxConstraints c) {
    if (c.maxWidth >= AppBreakpoints.desktop) return const EdgeInsets.symmetric(horizontal: 32);
    if (c.maxWidth >= AppBreakpoints.tablet) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  /// Constrain very wide content for readability.
  static BoxConstraints maxContentWidth([double maxWidth = 1200]) => BoxConstraints(maxWidth: maxWidth);

  /// Max width for auth forms.
  static double authFormMaxWidth(BoxConstraints c) {
    if (c.maxWidth >= AppBreakpoints.desktop) return 560;
    if (c.maxWidth >= AppBreakpoints.tablet) return 520;
    return 480;
  }
}
