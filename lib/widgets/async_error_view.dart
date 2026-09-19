import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/error_messages.dart';

/// Estado de erro amigável para carregamentos que falharam.
///
/// Mostra apenas uma mensagem simples e uma ação de tentar novamente, sem
/// códigos técnicos, links ou detalhes internos.
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title = 'Não foi possível carregar',
  });

  final Object error;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final offline = isOfflineError(error);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                size: 34,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              offline ? 'Sem conexão' : title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              friendlyError(error),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
