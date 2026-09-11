import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/records_sheet.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../charges/charge_form_sheet.dart';
import '../charges/payment_form_sheet.dart';
import '../clients/client_form_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(workspaceProvider);
    try {
      await ref.read(workspaceProvider.future);
    } catch (_) {
      // O erro é exibido pelo AsyncValue da tela.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return Scaffold(
      body: SafeArea(
        child: workspaceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(workspaceProvider),
          ),
          data: (workspace) => RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: _DashboardBody(workspace: workspace),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.workspace});

  final Workspace workspace;

  void _openReceivedMonth(BuildContext context) {
    final breakdown = monthBreakdown(workspace, monthKey(today()));
    showRecordsSheet(
      context,
      title: 'Recebido em ${monthLongLabel(monthKey(today()))}',
      subtitle: '${breakdown.received.length} pagamento(s) neste mês.',
      sections: [
        RecordSection(
          title: 'Recebido no mês',
          tone: AppColors.success,
          rows: [
            for (final row in breakdown.received)
              RecordRow(
                clientName: row.clientName,
                serviceName: row.serviceName,
                description: row.description,
                amount: row.amount,
                date: row.date,
                dateLabel: 'Recebido em',
                method: row.method,
                badgeLabel: 'Pago',
              ),
          ],
        ),
      ],
      emptyHint: 'Nenhum pagamento recebido neste mês.',
    );
  }

  void _openOpenCharges(BuildContext context) {
    final views = chargeViews(workspace)
        .where((view) => view.status == ChargeStatus.pendente)
        .toList();
    showRecordsSheet(
      context,
      title: 'A receber',
      subtitle: '${views.length} cobrança(s) pendente(s).',
      sections: [
        RecordSection(
          title: 'Pendentes',
          tone: AppColors.info,
          rows: [
            for (final view in views)
              RecordRow(
                clientName: view.clientName,
                serviceName: view.serviceName,
                description: view.description,
                amount: view.amount,
                date: view.dueDate,
                status: view.status,
                badgeLabel: view.status.label,
              ),
          ],
        ),
      ],
      emptyHint: 'Nenhuma cobrança pendente.',
    );
  }

  void _openOverdue(BuildContext context) {
    final views = chargeViews(workspace)
        .where((view) => view.status == ChargeStatus.atrasado)
        .toList();
    showRecordsSheet(
      context,
      title: 'Em atraso',
      subtitle: '${views.length} cobrança(s) atrasada(s).',
      sections: [
        RecordSection(
          title: 'Atrasadas',
          tone: AppColors.danger,
          rows: [
            for (final view in views)
              RecordRow(
                clientName: view.clientName,
                serviceName: view.serviceName,
                description: view.description,
                amount: view.amount,
                date: view.dueDate,
                status: view.status,
                badgeLabel: 'Atrasado',
              ),
          ],
        ),
      ],
      emptyHint: 'Nenhuma cobrança atrasada.',
    );
  }

  void _openMonth(BuildContext context, String key) {
    final breakdown = monthBreakdown(workspace, key);
    showRecordsSheet(
      context,
      title: monthLongLabel(key),
      subtitle: 'Detalhamento de recebido e a receber do mês.',
      sections: [
        RecordSection(
          title: 'Recebido no mês',
          tone: AppColors.success,
          rows: [
            for (final row in breakdown.received)
              RecordRow(
                clientName: row.clientName,
                serviceName: row.serviceName,
                description: row.description,
                amount: row.amount,
                date: row.date,
                dateLabel: 'Recebido em',
                method: row.method,
                badgeLabel: 'Pago',
              ),
          ],
        ),
        RecordSection(
          title: 'A receber no mês',
          tone: AppColors.info,
          rows: [
            for (final row in breakdown.open)
              RecordRow(
                clientName: row.clientName,
                serviceName: row.serviceName,
                description: row.description,
                amount: row.amount,
                date: row.date,
                status: row.status,
                badgeLabel: row.projected ? 'Não gerada' : row.status.label,
                note: row.projected ? 'recorrência não gerada' : null,
              ),
          ],
        ),
      ],
      emptyHint: 'Nenhum recebimento ou cobrança em aberto neste mês.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = computeMetrics(workspace);
    final firstName = (workspace.profile?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final needsOnboarding = workspace.clients.isEmpty || workspace.charges.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        ScreenHeader(
          title: firstName.isEmpty ? 'Visão geral' : 'Olá, $firstName',
          description: 'Acompanhe o que entrou, o que falta receber e o que está atrasado.',
          leading: const BrandBadge(),
          action: const NotificationBell(),
        ),
        const SizedBox(height: 20),
        if (needsOnboarding) ...[
          _OnboardingBanner(workspace: workspace),
          const SizedBox(height: 20),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _TappableStat(
              onTap: () => _openReceivedMonth(context),
              child: StatCard(
                label: 'Recebido no mês',
                value: brl(metrics.receivedThisMonth),
                icon: Icons.account_balance_wallet_outlined,
                tone: AppColors.success,
              ),
            ),
            _TappableStat(
              onTap: () => _openOpenCharges(context),
              child: StatCard(
                label: 'A receber',
                value: brl(metrics.toReceive),
                hint: '${metrics.pendingCount} pendentes',
                icon: Icons.schedule_outlined,
                tone: AppColors.info,
              ),
            ),
            _TappableStat(
              onTap: () => _openOverdue(context),
              child: StatCard(
                label: 'Em atraso',
                value: brl(metrics.overdue),
                hint: '${metrics.overdueCount} cobranças',
                icon: Icons.warning_amber_outlined,
                tone: AppColors.danger,
              ),
            ),
            _TappableStat(
              onTap: () => context.push('/reports'),
              child: StatCard(
                label: 'Previsão 30 dias',
                value: brl(metrics.forecast30),
                hint: 'Inclui recorrentes',
                icon: Icons.trending_up_outlined,
                tone: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evolução das receitas',
                style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              RevenueChart(
                series: monthlySeries(workspace),
                onMonthTap: (key) => _openMonth(context, key),
              ),
              const SizedBox(height: 8),
              const ChartLegend(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Próximas cobranças',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/charges'),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (metrics.upcoming.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma cobrança nos próximos dias',
              description: 'Quando houver pendências a vencer, elas aparecem aqui.',
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < metrics.upcoming.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _UpcomingTile(view: metrics.upcoming[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TappableStat extends StatelessWidget {
  const _TappableStat({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: child,
    );
  }
}

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final noClients = workspace.clients.isEmpty;
    final (title, message, label, action) = noClients
        ? (
            'Comece cadastrando um cliente',
            'Clientes organizam cobranças, serviços e orçamentos.',
            'Novo cliente',
            () => showClientForm(context),
          )
        : (
            'Crie sua primeira cobrança',
            'Defina valor e vencimento para acompanhar os recebimentos.',
            'Nova cobrança',
            () => showChargeForm(context),
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: action,
            icon: const Icon(Icons.add, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.view});

  final ChargeView view;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.clientName,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  view.description,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Vence ${formatDate(view.dueDate)}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                brl(view.amount),
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              StatusBadge(status: view.status),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showPaymentForm(context, charge: view.charge),
                child: const Text('Receber'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
