import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';

class DividerBlockWidget extends StatelessWidget {
  const DividerBlockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.fgSoft.withValues(alpha: 0.2),
      ),
    );
  }
}
