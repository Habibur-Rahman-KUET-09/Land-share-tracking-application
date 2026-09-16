import 'package:flutter/material.dart';

/// Flat pastel pill badge — see AppColors' *Bg/*Fg pairs for the palette.
class StatusChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  const StatusChip({super.key, required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
