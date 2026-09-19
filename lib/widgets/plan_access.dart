import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

/// Selo pequeno que indica que uma funcionalidade não está disponível no plano.
class PlanLockBadge extends StatelessWidget {
  const PlanLockBadge({super.key, this.size = 12});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.lock_outline_rounded,
        size: size,
        color: AppColors.warning,
      ),
    );
  }
}

/// Diálogo amigável explicando que o recurso depende do plano do usuário.
Future<void> showPlanLockedDialog(
  BuildContext context, {
  required String feature,
  String? description,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const PlanLockBadge(size: 20),
      title: Text('$feature não está no seu plano'),
      content: Text(
        description ??
            'Este recurso não está disponível no seu plano atual. '
                'Faça upgrade para liberar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            context.push('/more/settings');
          },
          child: const Text('Ver planos'),
        ),
      ],
    ),
  );
}

/// Botão de ícone que fica visualmente bloqueado quando o recurso depende de
/// um plano que o usuário não possui.
class PlanGatedIconButton extends StatelessWidget {
  const PlanGatedIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.allowed,
    required this.onPressed,
    this.feature = 'Este recurso',
  });

  final IconData icon;
  final String tooltip;
  final bool allowed;
  final VoidCallback onPressed;
  final String feature;

  @override
  Widget build(BuildContext context) {
    if (allowed) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      );
    }
    return IconButton(
      tooltip: '$feature indisponível no seu plano',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: AppColors.mutedForeground.withValues(alpha: 0.55)),
          const Positioned(right: -3, top: -3, child: PlanLockBadge(size: 11)),
        ],
      ),
      onPressed: () => showPlanLockedDialog(context, feature: feature),
    );
  }
}
