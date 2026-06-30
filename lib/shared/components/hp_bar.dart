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
    final double currentPercentage = totalMax > 0 ? (currentHp / totalMax).clamp(0.0, 1.0) : 0.0;
    final double tempPercentage = totalMax > 0 ? (tempHp / totalMax).clamp(0.0, 1.0) : 0.0;

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
            // Row containing the health bars
            Row(
              children: [
                // Current HP bar
                Expanded(
                  flex: (currentPercentage * 1000).toInt(),
                  child: Container(
                    color: AppColors.heal,
                  ),
                ),
                // Temp HP bar
                if (tempHp > 0)
                  Expanded(
                    flex: (tempPercentage * 1000).toInt(),
                    child: Container(
                      color: AppColors.tempHp,
                    ),
                  ),
                // Remaining space
                Expanded(
                  flex: ((1.0 - (currentPercentage + tempPercentage)) * 1000).toInt().clamp(0, 1000),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ],
            ),
            // Text displaying HP values
            if (showText)
              Center(
                child: Text(
                  tempHp > 0 ? '$currentHp + $tempHp / $maxHp HP' : '$currentHp / $maxHp HP',
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
