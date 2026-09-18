import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';

class PortalScreen extends ConsumerWidget {
  const PortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Portal')),
      body: workspaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(workspaceProvider),
        ),
        data: (workspace) {
          if (!workspace.isSuperadmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Acesso restrito ao administrador.'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PortalCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Painel administrativo',
                description:
                    'Usuários, planos, WhatsApp e Asaas da plataforma.',
                tone: AppColors.primary,
                onTap: () => context.push('/admin'),
              ),
              const SizedBox(height: 12),
              _PortalCard(
                icon: Icons.space_dashboard_outlined,
                title: 'Usar o Controla Simples',
                description: 'Voltar para o painel de gestão do seu negócio.',
                tone: AppColors.info,
                onTap: () => context.go('/dashboard'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
