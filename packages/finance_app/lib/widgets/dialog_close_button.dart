import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.errorDark,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.6),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
