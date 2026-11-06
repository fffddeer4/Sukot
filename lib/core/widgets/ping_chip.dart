import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../common/app_semantic_colors.dart';

/// Small rounded badge showing a server's real probe latency, e.g.
/// "42 ms". Green when fast, brand blue when decent, amber when slow,
/// red when very slow, grey with "—" when the probe reports the server
/// as unreachable. Purely presentational.
class PingChip extends StatelessWidget {
  /// Successful probe delay in milliseconds; null means no successful
  /// probe yet (unreachable or still waiting).
  final int? delayMs;

  /// True when the core probed the server and it did not respond.
  final bool unreachable;

  const PingChip({super.key, required this.delayMs, this.unreachable = false});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = _appearance(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ],
      ),
    );
  }

  (Color, String) _appearance(BuildContext context) {
    if (unreachable || delayMs == null) {
      return (context.textTertiary, '—');
    }
    final ms = delayMs!;
    if (ms <= 100) {
      return (AppColors.green6, '$ms ms');
    }
    if (ms <= 250) {
      return (AppColors.blue6, '$ms ms');
    }
    if (ms <= 500) {
      return (const Color(0xFFE8A13D), '$ms ms');
    }
    return (const Color(0xFFD64545), '$ms ms');
  }
}

/// Maps a server's probe state to a [PingChip], or null when the probe
/// has not reported anything yet (no delay, not marked unreachable) —
/// callers render nothing in that case instead of an empty badge.
PingChip? pingChipFor({
  required BuildContext context,
  int? lastSuccessDelayMs,
  required bool isProbedUnreachable,
  required bool isAwaitingProbe,
}) {
  if (isProbedUnreachable) {
    return PingChip(delayMs: null, unreachable: true);
  }
  if (lastSuccessDelayMs != null && lastSuccessDelayMs > 0) {
    return PingChip(delayMs: lastSuccessDelayMs);
  }
  if (isAwaitingProbe) {
    return PingChip(delayMs: null, unreachable: false);
  }
  return null;
}
