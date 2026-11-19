import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with stronger intensity
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFF5A52D5),
                  Color(0xFF4A44B8),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 800.ms),
          
          // Enhanced Mesh/Atmospheric Glows
          Positioned(
            top: -150,
            right: -100,
            child: _buildGlow(Colors.white.withValues(alpha: 0.15), 400),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(begin: Offset.zero, end: const Offset(-30, 30), duration: 6.seconds, curve: Curves.easeInOut),

          Positioned(
            bottom: -100,
            left: -100,
            child: _buildGlow(OasyraColors.aiAccent.withValues(alpha: 0.2), 350),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(begin: Offset.zero, end: const Offset(40, -40), duration: 8.seconds, curve: Curves.easeInOut),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: OasyraColors.primary,
                    size: 50,
                  ),
                )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack)
                .shimmer(delay: 1500.ms, duration: 2.seconds),
                
                const SizedBox(height: 48),
                
                // Styled Wordmark
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'OASY',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                    ),
                    Text(
                      'RA',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1,
                          ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 600.ms, duration: 800.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                
                const SizedBox(height: 16),
                
                Text(
                  'AI Companion for Everyday Living',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                )
                .animate()
                .fadeIn(delay: 1000.ms, duration: 800.ms),
              ],
            ),
          ),
          
          // Refined Transition Indicator
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat())
               .shimmer(duration: 2.seconds),
            ),
          ).animate().fadeIn(delay: 2.seconds),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
