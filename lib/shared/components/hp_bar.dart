import 'package:flutter/material.dart';
import 'package:ilithid/shared/theme/app_colors.dart';

class HpBar extends StatelessWidget {
  const HpBar({
    super.key,
    required this.currentHp,
    required this.maxHp,
    this.tempHp = 0,
    this.height = 24,
    this.showText = true,
  });

  final int currentHp;
  final int maxHp;
  final int tempHp;
  final double height;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final double totalMax = (maxHp + tempHp).toDouble();
    final double currentPercentage = totalMax > 0
        ? (currentHp / totalMax).clamp(0.0, 1.0)
        : 0.0;
    final double tempPercentage = totalMax > 0
        ? (tempHp / totalMax).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            // Bars animate towards the new percentages whenever HP changes,
            // so combat actions (Story 7.2/7.3) read as a visible HP shift.
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              tween: Tween<double>(
                begin: currentPercentage,
                end: currentPercentage,
              ),
              builder: (context, animatedCurrent, _) {
                return TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  tween: Tween<double>(
                    begin: tempPercentage,
                    end: tempPercentage,
                  ),
                  builder: (context, animatedTemp, _) {
                    final remaining = (1.0 - (animatedCurrent + animatedTemp))
                        .clamp(0.0, 1.0);
                    return Row(
                      children: [
                        Expanded(
                          flex: (animatedCurrent * 1000).toInt(),
                          child: Container(color: AppColors.heal),
                        ),
                        if (tempHp > 0)
                          Expanded(
                            flex: (animatedTemp * 1000).toInt(),
                            child: Container(color: AppColors.tempHp),
                          ),
                        Expanded(
                          flex: (remaining * 1000).toInt(),
                          child: Container(color: Colors.transparent),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            // Text displaying HP values
            if (showText)
              Center(
                child: Text(
                  tempHp > 0
                      ? '$currentHp + $tempHp / $maxHp HP'
                      : '$currentHp / $maxHp HP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
