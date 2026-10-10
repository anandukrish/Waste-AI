import 'package:flutter/material.dart';

class ModeBadge extends StatelessWidget {
  const ModeBadge({super.key, required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final online = mode == 'online';
    final color = online ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.cloud_outlined : Icons.lan_outlined, size: 14, color: color),
          const SizedBox(width: 5),
          Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8)),
        ],
      ),
    );
  }
}
