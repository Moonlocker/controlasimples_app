import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_card.dart';
import 'admin_providers.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administração'),
        actions: [
          IconButton(
            tooltip: 'Portal',
            icon: const Icon(Icons.grid_view_outlined),
            onPressed: () => context.push('/more/portal'),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminDataProvider),
        ),
        data: (data) {
          final recent = data.users.reversed.take(8).toList();

          final now = DateTime.now();
          final blocked = data.users.where((u) => !u.active).toList();
          final delinquent = data.users
              .where(
                (u) => u.subscriptionStatus == SubscriptionStatus.inadimplente,
              )
              .toList();
          final trialsEnding = data.users.where((u) {
            if (u.subscriptionStatus != SubscriptionStatus.trial) return false;
            final end = u.currentPeriodEnd;
            if (end == null) return false;
            final days = end.difference(now).inDays;
            return days >= 0 && days <= 7;
          }).toList();
          final attention = [
            for (final u in delinquent)
              (
                user: u,
                label: 'Pagamento pendente',
                tone: AppColors.danger,
                icon: Icons.error_outline,
              ),
            for (final u in trialsEnding)
              (
                user: u,
                label: u.currentPeriodEnd == null
                    ? 'Teste terminando'
                    : 'Teste termina ${formatDate(u.currentPeriodEnd!)}',
                tone: AppColors.warning,
                icon: Icons.hourglass_bottom,
              ),
            for (final u in blocked)
              (
                user: u,
                label: 'Acesso bloqueado',
                tone: AppColors.mutedForeground,
                icon: Icons.block,
              ),
          ];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminDataProvider);
              try {
                await ref.read(adminDataProvider.future);
              } catch (_) {}
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const ScreenHeader(
                  title: 'Visão geral',
                  description: 'Métricas da plataforma e gestão de contas.',
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      label: 'Usuários',
                      value: '${data.users.length}',
                      tone: AppColors.info,
                      icon: Icons.people_outline,
                    ),
                    StatCard(
                      label: 'Assinaturas ativas',
                      value: '${data.activeSubscriptions}',
                      tone: AppColors.success,
                      icon: Icons.check_circle_outline,
                    ),
                    StatCard(
                      label: 'Em teste',
                      value: '${data.trials}',
                      tone: AppColors.warning,
                      icon: Icons.hourglass_empty,
                    ),
                    StatCard(
                      label: 'MRR',
                      value: brl(data.mrr),
                      tone: AppColors.primary,
                      icon: Icons.trending_up,
                    ),
                    StatCard(
                      label: 'Recebido pelos usuários',
                      value: brl(data.platformReceived),
                      tone: AppColors.success,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    StatCard(
                      label: 'Clientes cadastrados',
                      value: '${data.totalClients}',
                      tone: AppColors.info,
                      icon: Icons.assignment_ind_outlined,
                    ),
                    StatCard(
                      label: 'Cobranças',
                      value: '${data.totalCharges}',
                      tone: AppColors.primary,
                      icon: Icons.receipt_long_outlined,
                    ),
                    StatCard(
                      label: 'WhatsApp no mês',
                      value: '${data.whatsappSentTotal}',
                      hint: data.whatsappFailedTotal > 0
                          ? '${data.whatsappFailedTotal} falhas'
                          : 'sem falhas',
                      tone: data.whatsappFailedTotal > 0
                          ? AppColors.danger
                          : AppColors.success,
                      icon: Icons.chat_outlined,
                    ),
                  ],
                ),
                if (attention.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Precisa de atenção',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < attention.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            onTap: () => context.push(
                              '/more/admin/users/${attention[i].user.id}',
                            ),
                            leading: Icon(
                              attention[i].icon,
                              color: attention[i].tone,
                            ),
                            title: Text(
                              attention[i].user.name.isEmpty
                                  ? attention[i].user.email
                                  : attention[i].user.name,
                            ),
                            subtitle: Text(attention[i].label),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Áreas de gestão',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _AdminMenuCard(
                  children: [
                    _AdminMenuItem(
                      icon: Icons.people_outline,
                      label: 'Usuários',
                      subtitle: 'Contas, planos e acesso',
                      onTap: () => context.push('/more/admin/users'),
                    ),
                    _AdminMenuItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Planos',
                      subtitle: 'Preços e recursos',
                      onTap: () => context.push('/more/admin/plans'),
                    ),
                    _AdminMenuItem(
                      icon: Icons.account_balance_outlined,
                      label: 'Gateways e assinaturas',
                      subtitle: 'Asaas, Mercado Pago, Pagar.me e assinantes',
                      onTap: () => context.push('/more/admin/subscriptions'),
                    ),
                    _AdminMenuItem(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      subtitle: 'Mensagens, consumo e configuração',
                      onTap: () => context.push('/more/admin/whatsapp'),
                    ),
                    _AdminMenuItem(
                      icon: Icons.payments_outlined,
                      label: 'Asaas da plataforma',
                      subtitle: 'Configuração legada',
                      onTap: () => context.push('/more/admin/asaas'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Usuários recentes',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(
                            recent[i].name.isEmpty
                                ? recent[i].email
                                : recent[i].name,
                          ),
                          subtitle: Text(recent[i].email),
                          trailing: Text(
                            data.planById(recent[i].planId)?.name ??
                                'Sem plano',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          onTap: () =>
                              context.push('/more/admin/users/${recent[i].id}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({required this.children});

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

class _AdminMenuItem extends StatelessWidget {
  const _AdminMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.mutedForeground,
      ),
    );
  }
}
