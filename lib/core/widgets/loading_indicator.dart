import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../common/app_asset.dart' show AppImage;
import '../common/app_colors.dart';
import '../common/app_image_paths.dart' show AppImagePaths;

/// Sukot loading state — a branded medallion card in the poster's deep-blue
/// style: the hooded guardian art inside a rotating electric-blue ring, the
/// Sukot icon badge, the wordmark and the "Stay free • Stay safe" motto, with
/// pulsing dots underneath. Self-contained, so it renders correctly both as
/// the global loader overlay and inside constrained panels.
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({super.key});

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290.w,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 26.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020817),
            Color(0xFF04123A),
            Color(0xFF0A2A6B),
          ],
        ),
        border: Border.all(color: AppColors.blue5.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006FF0).withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Medallion(ring: _ring, pulse: _pulse),
          SizedBox(height: 16.h),
          Text(
            'Sukot',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'STAY FREE • STAY SAFE',
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.2,
              color: AppColors.blue3,
            ),
          ),
          SizedBox(height: 14.h),
          const _PulsingDots(color: AppColors.blue3),
        ],
      ),
    );
  }
}

/// The circular poster art wrapped in a rotating gradient ring with a
/// breathing glow, plus the Sukot icon badge at the lower right.
class _Medallion extends StatelessWidget {
  final AnimationController ring;
  final AnimationController pulse;

  const _Medallion({required this.ring, required this.pulse});

  @override
  Widget build(BuildContext context) {
    const size = 118.0;
    return AnimatedBuilder(
      animation: Listenable.merge([ring, pulse]),
      builder: (context, _) {
        final breath = 0.5 - 0.5 * math.cos(2 * math.pi * pulse.value);
        return SizedBox(
          width: size + 26,
          height: size + 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // breathing ambient glow
              Container(
                width: size + 26 + 18 * breath,
                height: size + 26 + 18 * breath,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue5.withValues(
                          alpha: 0.35 + 0.25 * breath),
                      blurRadius: 34 + 14 * breath,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // rotating conic ring
              Transform.rotate(
                angle: 2 * math.pi * ring.value,
                child: SizedBox(
                  width: size + 22,
                  height: size + 22,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.6,
                    strokeCap: StrokeCap.round,
                    value: 0.78,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue4),
                    backgroundColor: Color(0x220078F8),
                  ),
                ),
              ),
              // poster art
              Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF01051E),
                ),
                clipBehavior: Clip.antiAlias,
                child: Opacity(
                  opacity: 0.96,
                  child: Image.asset(
                    'assets/images/sukot_poster.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              // Sukot icon badge
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF020817),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blue4, width: 1.4),
                      color: AppColors.white,
                    ),
                    child: AppImage(
                      path: AppImagePaths.appIcon,
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
