import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/utils/responsive.dart';
import '../../../../backend/services/player_cubit.dart';

class SpeedControl extends StatelessWidget {
  final Responsive r;
  final bool isDark;
  final AudioPlayerState player;

  const SpeedControl({
    super.key,
    required this.r,
    required this.isDark,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final active = isDark ? Colors.white : Colors.black;
    final inactive = active.withValues(alpha: 0.4);

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.speed_rounded, size: r.subtitleSize, color: inactive),
            SizedBox(width: r.spacingS),
            Text(
              'Speed',
              style: TextStyle(
                fontSize: r.footerSize,
                letterSpacing: 0.4,
                color: inactive,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.read<PlayerCubit>().setRate(1.0),
              child: Text(
                player.rate == 1.0
                    ? '1.0×'
                    : '${player.rate.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                  color: player.rate == 1.0 ? active : inactive,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spacingXS),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in speeds) ...[
              if (s != speeds.first) const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.read<PlayerCubit>().setRate(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: (player.rate == s ? active : Colors.transparent)
                          .withValues(alpha: player.rate == s ? 0.12 : 0.0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: player.rate == s
                            ? active.withValues(alpha: 0.3)
                            : active.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '${s.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        fontWeight: player.rate == s ? FontWeight.w700 : FontWeight.w500,
                        color: player.rate == s ? active : inactive,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
