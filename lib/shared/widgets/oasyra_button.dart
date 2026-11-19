import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/oasyra_colors.dart';

class OasyraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final bool isLoading;
  final bool useGradient;

  const OasyraButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isFullWidth = true,
    this.isLoading = false,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Container(
      width: isFullWidth ? double.infinity : null,
      height: 56,
      decoration: useGradient && !isLoading && !isDisabled
          ? BoxDecoration(
              gradient: OasyraColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: ElevatedButton(
        onPressed: (isLoading || isDisabled)
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: useGradient ? Colors.transparent : OasyraColors.primary,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: OasyraColors.primaryLight,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(text),
      ),
    );
  }
}
