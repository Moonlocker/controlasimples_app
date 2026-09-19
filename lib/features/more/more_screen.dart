import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/workspace.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/brand_logo.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);
    final workspace = workspaceAsync.value;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(workspaceProvider);
            await ref.read(workspaceProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              const BrandLogo(surface: BrandSurface.light, width: 64),
              const SizedBox(height: 4),
              Text(
                'Gerencie sua conta, serviços e preferências.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 20),
              _AccountCard(
                workspace: workspace,
                isLoading: workspaceAsync.isLoading && workspace == null,
                hasError: workspaceAsync.hasError && workspace == null,
                onRetry: () => ref.invalidate(workspaceProvider),
              ),
              const SizedBox(height: 20),
              _MenuCard(
                children: [
                  _MenuItem(
                    icon: Icons.notifications_active_outlined,
                    label: 'Notificações',
                    tone: AppColors.warning,
                    onTap: () => context.push('/more/notifications'),
                  ),
                  _MenuItem(
                    icon: Icons.request_quote_outlined,
                    label: 'Orçamentos',
                    tone: AppColors.info,
                    onTap: () => context.push('/more/quotes'),
                  ),
                  _MenuItem(
                    icon: Icons.insights_outlined,
                    label: 'Relatórios',
                    tone: AppColors.success,
                    onTap: () => context.push('/more/reports'),
                  ),
                  _MenuItem(
                    icon: Icons.tune_outlined,
                    label: 'Configurações',
                    tone: AppColors.mutedForeground,
                    onTap: () => context.push('/more/settings'),
                  ),
                  if (workspace?.isSuperadmin == true)
                    _MenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Administração',
                      tone: AppColors.primary,
                      onTap: () => context.push('/more/admin'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
              const SizedBox(height: 32),
              const _BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.workspace,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final Workspace? workspace;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget child;
    if (isLoading) {
      child = Row(
        children: [
          const CircleAvatar(radius: 24, backgroundColor: AppColors.muted),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 140),
                SizedBox(height: 8),
                _SkeletonLine(width: 200),
              ],
            ),
          ),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    } else if (hasError) {
      child = Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Não foi possível carregar sua conta.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar')),
        ],
      );
    } else {
      final profile = workspace?.profile;
      final plan = workspace?.plan;
      child = Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials(profile?.name ?? profile?.email ?? '?'),
              style: textTheme.titleMedium?.copyWith(
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
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  profile?.email ?? '',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Plano ${plan?.name ?? '—'}',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(6),
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
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: tone),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.mutedForeground,
      ),
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
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
