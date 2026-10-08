import 'package:flutter/material.dart';
import 'package:pelevo/core/theme/app_theme.dart';

/// Visual hero for the Download Episode screen (replaces flat arrow assets).
class DownloadHeroBadge extends StatelessWidget {
  const DownloadHeroBadge({
    super.key,
    this.size = 120,
    this.complete = false,
  });

  final double size;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final accent = complete ? PelevoColors.green : PelevoColors.green;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.22),
              PelevoColors.surface,
              PelevoColors.border.withValues(alpha: 0.55),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.14,
              child: Icon(
                Icons.cloud_outlined,
                size: size * 0.34,
                color: PelevoColors.textMuted.withValues(alpha: 0.55),
              ),
            ),
            Container(
              width: size * 0.46,
              height: size * 0.46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                complete
                    ? Icons.offline_pin_rounded
                    : Icons.cloud_download_rounded,
                color: Colors.white,
                size: size * 0.24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
