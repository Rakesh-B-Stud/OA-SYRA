import 'package:flutter/material.dart';

enum OasyraLogoVariant {
  /// Complete logo featuring both the gradient symbol and OASYRA wordmark.
  full,

  /// Compact symbol-only variant featuring only the gradient symbol.
  symbol,
}

/// A reusable branding widget displaying the official OASYRA logo or symbol.
class OasyraLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final OasyraLogoVariant variant;
  final BoxFit fit;
  final String? semanticsLabel;
  final bool useContainer;
  final Color? containerColor;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;

  const OasyraLogo({
    super.key,
    this.width,
    this.height,
    this.variant = OasyraLogoVariant.full,
    this.fit = BoxFit.contain,
    this.semanticsLabel,
    this.useContainer = false,
    this.containerColor,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = variant == OasyraLogoVariant.full
        ? 'assets/images/oasyra_brand_purple.png'
        : 'assets/images/oasyra_symbol.png';

    final label = semanticsLabel ??
        (variant == OasyraLogoVariant.full
            ? 'OASYRA Healthcare & Nutrition Logo'
            : 'OASYRA Symbol');

    Widget imageWidget = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
    );

    if (useContainer) {
      imageWidget = Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: containerColor ?? const Color(0xFF0A0E1A),
          borderRadius: borderRadius ?? BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            assetPath,
            fit: fit,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    return Semantics(
      label: label,
      image: true,
      child: imageWidget,
    );
  }
}
