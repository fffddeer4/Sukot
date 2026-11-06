import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../common/app_colors.dart';

/// Animated Sukot loading state: the blue brand wordmark with three
/// pulsing dots beneath it. Purely presentational — the app name shown is
/// the Sukot brand, everything else keeps working exactly as before.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.blue5 : AppColors.blue6;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sukot',
          style: TextStyle(
            fontSize: 34.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: labelColor,
          ),
        ),
        SizedBox(height: 14.h),
        const _PulsingDots(color: AppColors.blue6),
      ],
    );
  }
}

class _PulsingDots extends StatefulWidget {
  final Color color;

  const _PulsingDots({required this.color});

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            // Each dot is phase-shifted a third of the cycle, giving a
            // gentle wave rather than a uniform blink.
            final phase = (_controller.value - i * 0.22) % 1.0;
            final scale = 0.55 + 0.45 * _wave(phase);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 12.r,
                  height: 12.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color
                        .withValues(alpha: 0.35 + 0.65 * _wave(phase)),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Smooth 0..1..0 bump so the dots swell and shrink instead of popping.
  double _wave(double t) {
    final x = (t.clamp(0.0, 1.0) * 2 - 1).abs();
    return 1 - x * x;
  }
}
