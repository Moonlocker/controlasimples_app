import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/brand_logo.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider).value;
    final profile = workspace?.profile;
    final plan = workspace?.plan;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const BrandLogo(surface: BrandSurface.light, width: 150),
            const SizedBox(height: 6),
            Text(
              'Gerencie sua conta, serviços e preferências.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      initials(profile?.name ?? profile?.email ?? '?'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Usuário',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile?.email ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plano ${plan?.name ?? '—'}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.notifications_none,
                  label: 'Notificações',
                  onTap: () => context.push('/notifications'),
                ),
                _MenuItem(
                  icon: Icons.work_outline,
                  label: 'Serviços',
                  onTap: () => context.push('/services'),
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'Orçamentos',
                  onTap: () => context.push('/quotes'),
                ),
                _MenuItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Relatórios',
                  onTap: () => context.push('/reports'),
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Configurações',
                  onTap: () => context.push('/settings'),
                ),
                if (workspace?.isSuperadmin == true)
                  _MenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Administração',
                    onTap: () => context.push('/admin'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            ),
            const SizedBox(height: 32),
            const _BrandFooter(),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.mutedForeground),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const BrandMark(size: 28),
        const SizedBox(height: 8),
        Text(
          'Controla Simples',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Cobranças e receitas sem complicação',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}
