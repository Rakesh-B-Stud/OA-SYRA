import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/oasyra_colors.dart';

enum OasyraBrandSize {
  /// Prominent size for splash screen (fontSize 34)
  large,

  /// Medium size for authentication & onboarding screens (fontSize 26)
  medium,

  /// Compact size for application headers and app bars (fontSize 18)
  compact,
}

/// Reusable clean geometric wordmark widget for OASYRA branding.
class OasyraBrand extends StatelessWidget {
  final OasyraBrandSize size;
  final double? customFontSize;
  final Color textColor;
  final bool useContainer;
  final Color? containerColor;
  final EdgeInsetsGeometry? padding;

  const OasyraBrand({
    super.key,
    this.size = OasyraBrandSize.medium,
    this.customFontSize,
    this.textColor = Colors.white,
    this.useContainer = false,
    this.containerColor,
    this.padding,
  });

  double get _fontSize {
    if (customFontSize != null) return customFontSize!;
    switch (size) {
      case OasyraBrandSize.large:
        return 34.0;
      case OasyraBrandSize.medium:
        return 26.0;
      case OasyraBrandSize.compact:
        return 18.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins(
      fontSize: _fontSize,
      fontWeight: FontWeight.w700,
      color: textColor,
      letterSpacing: 2.2,
    );

    Widget brandWidget = Text(
      'OASYRA',
      style: textStyle,
      semanticsLabel: 'OASYRA',
    );

    if (useContainer) {
      brandWidget = Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: containerColor ?? OasyraColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: OasyraColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: brandWidget,
      );
    }

    return Semantics(
      label: 'OASYRA Brand Wordmark',
      child: brandWidget,
    );
  }
}
