import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../models/client.dart';
import '../../models/recurring_charge.dart';
import '../../models/service.dart';
import '../../models/workspace.dart';
import '../../repositories/clients_repository.dart';
import '../../repositories/whatsapp_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/breakdown_charts.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_combobox.dart';
import '../../widgets/period_filter.dart';
import '../../widgets/records_sheet.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../charges/charge_card.dart';
import '../charges/charge_form_sheet.dart';
import '../charges/recurring_form_sheet.dart';
import '../services/service_form_sheet.dart';
import 'client_form_sheet.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return workspaceAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(workspaceProvider),
        ),
      ),
      data: (workspace) {
        final client = workspace.clientById(clientId);
        if (client == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(title: 'Cliente não encontrado'),
          );
        }

        final views = chargeViews(workspace)
            .where((view) => view.clientId == client.id)
            .toList()
            .reversed
            .toList();
        final services = workspace.services
            .where((service) => service.clientId == client.id)
            .toList();
        final recurring = workspace.recurring
            .where((item) => item.clientId == client.id)
            .toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(client.name, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showClientForm(context, client: client),
                ),
                _ClientMenu(client: client),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () =>
                  showChargeForm(context, initialClientId: client.id),
              icon: const Icon(Icons.add),
              label: const Text('Nova cobrança'),
            ),
            body: Column(
              children: [
                _ClientHeader(client: client),
                const TabBar(
                  tabs: [
                    Tab(text: 'Cobranças'),
                    Tab(text: 'Serviços'),
                    Tab(text: 'Relatório'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ChargesTab(views: views),
                      _ServicesTab(
                        services: services,
                        recurring: recurring,
                        clientId: client.id,
                      ),
                      _ReportTab(client: client, workspace: workspace),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClientMenu extends ConsumerWidget {
  const _ClientMenu({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final repository = ref.read(clientsRepositoryProvider);
        if (value == 'active') {
          await repository.setActive(client.id, !client.active);
          ref.invalidate(workspaceProvider);
        } else if (value == 'delete') {
          final confirmed = await showConfirmDialog(
            context,
            title: 'Excluir cliente',
            message: 'Todos os serviços, cobranças e pagamentos vinculados também serão removidos. Esta ação não pode ser desfeita.',
            confirmLabel: 'Excluir',
            destructive: true,
          );
          if (!confirmed) return;
          await repository.delete(client.id);
          ref.invalidate(workspaceProvider);
          if (context.mounted) context.pop();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'active',
          child: Text(client.active ? 'Inativar cliente' : 'Ativar cliente'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Excluir cliente')),
      ],
    );
  }
}

class _ClientHeader extends ConsumerWidget {
  const _ClientHeader({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials(client.name),
              style: textTheme.labelLarge?.copyWith(
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
                  client.phone ?? client.email ?? 'Sem contato',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (client.phone != null && client.email != null)
                  Text(
                    client.email!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                if (!client.active)
                  Text(
                    'Cliente inativo',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                if (client.whatsappValid == true)
                  Text(
                    'WhatsApp confirmado',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
          if (client.phone != null) ...[
            IconButton(
              tooltip: 'Verificar WhatsApp',
              icon: const Icon(Icons.verified_outlined, color: AppColors.info),
              onPressed: () => _checkWhatsapp(context, ref),
            ),
            IconButton(
              tooltip: 'Abrir conversa',
              icon: const Icon(Icons.chat_outlined, color: AppColors.success),
              onPressed: () {
                final digits = client.phone!.replaceAll(RegExp(r'[^0-9]'), '');
                final number = digits.length <= 11 ? '55$digits' : digits;
                launchUrl(Uri.parse('https://wa.me/$number'));
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkWhatsapp(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final status = await ref
          .read(whatsappRepositoryProvider)
          .checkClient(client.id);
      ref.invalidate(workspaceProvider);
      final label = switch (status) {
        'valid' => 'Número confirmado no WhatsApp.',
        'processing' =>
          'A Meta ainda está processando. Tente novamente mais tarde.',
        _ => 'Este número não parece ser um WhatsApp válido.',
      };
      messenger.showSnackBar(SnackBar(content: Text(label)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _ChargesTab extends StatelessWidget {
  const _ChargesTab({required this.views});

  final List<ChargeView> views;

  @override
  Widget build(BuildContext context) {
    if (views.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhuma cobrança',
        description: 'Crie a primeira cobrança para este cliente.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: views.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          ChargeCard(view: views[index], showClient: false),
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({
    required this.services,
    required this.recurring,
    required this.clientId,
  });

  final List<Service> services;
  final List<RecurringCharge> recurring;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty && recurring.isEmpty) {
      return const EmptyState(
        icon: Icons.work_outline,
        title: 'Nenhum serviço',
        description:
            'Cadastre um serviço ou uma recorrência para este cliente.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    showServiceForm(context, initialClientId: clientId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Serviço'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    showRecurringForm(context, initialClientId: clientId),
                icon: const Icon(Icons.repeat, size: 18),
                label: const Text('Recorrência'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final service in services) ...[
          _ServiceRow(
            name: service.name,
            subtitle: service.billingType.label,
            amount: service.amount,
            status: service.status.label,
            onTap: () => context.push('/services/${service.id}'),
          ),
          const SizedBox(height: 10),
        ],
        for (final item in recurring) ...[
          _ServiceRow(
            name: item.description,
            subtitle: 'Recorrente · ${item.frequency.label}',
            amount: item.amount,
            status: item.active ? 'Ativa' : 'Pausada',
            onTap: () => showRecurringForm(context, recurring: item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final double amount;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subtitle · $status',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              brl(amount),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTab extends ConsumerStatefulWidget {
  const _ReportTab({required this.client, required this.workspace});

  final Client client;
  final Workspace workspace;

  @override
  ConsumerState<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends ConsumerState<_ReportTab> {
  PeriodRange? _range;
  String? _serviceId;
  bool _initialized = false;

  DateTime _earliest(Workspace scoped) {
    DateTime? min;
    for (final charge in scoped.charges) {
      if (min == null || charge.dueDate.isBefore(min)) min = charge.dueDate;
    }
    for (final payment in scoped.payments) {
      if (min == null || payment.paidAt.isBefore(min)) min = payment.paidAt;
    }
    return min ?? today();
  }

  DateTime _latest(Workspace scoped) {
    DateTime? max;
    for (final charge in scoped.charges) {
      if (max == null || charge.dueDate.isAfter(max)) max = charge.dueDate;
    }
    for (final payment in scoped.payments) {
      if (max == null || payment.paidAt.isAfter(max)) max = payment.paidAt;
    }
    final now = today();
    if (max == null) return now;
    return max.isAfter(now) ? max : now;
  }

  Workspace _clientScope() {
    final workspace = widget.workspace;
    final clientId = widget.client.id;
    final charges = workspace.charges
        .where((c) => c.clientId == clientId)
        .toList();
    final chargeIds = charges.map((c) => c.id).toSet();
    final payments = workspace.payments
        .where((p) => chargeIds.contains(p.chargeId))
        .toList();
    final recurring = workspace.recurring
        .where((r) => r.clientId == clientId)
        .toList();
    return Workspace(
      clients: workspace.clients,
      services: workspace.services,
      charges: charges,
      recurring: recurring,
      payments: payments,
    );
  }

  Workspace _scope(Workspace base, DateTime from, DateTime to) {
    bool inRange(DateTime date) =>
        !dateOnly(date).isBefore(dateOnly(from)) &&
        !dateOnly(date).isAfter(dateOnly(to));
    final charges = base.charges
        .where((c) => _serviceId == null || c.serviceId == _serviceId)
        .toList();
    final allIds = charges.map((c) => c.id).toSet();
    final payments = base.payments
        .where((p) => allIds.contains(p.chargeId) && inRange(p.paidAt))
        .toList();
    final recurring = base.recurring
        .where((r) => _serviceId == null || r.serviceId == _serviceId)
        .toList();
    return Workspace(
      clients: base.clients,
      services: base.services,
      charges: charges,
      recurring: recurring,
      payments: payments,
    );
  }

  void _openMonth(BuildContext context, Workspace scoped, String key) {
    final breakdown = monthBreakdown(scoped, key);
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
    final base = _clientScope();
    final earliest = _earliest(base);
    if (!_initialized) {
      _range = presetRange(PeriodPreset.ninetyDays, earliest);
      _initialized = true;
    }
    final latest = _latest(base);
    final from = _range?.from ?? earliest;
    final to = _range?.to ?? latest;
    final scoped = _scope(base, from, to);
    final views = chargeViews(scoped)
        .where((v) => _range == null || _range!.contains(v.dueDate))
        .toList();
    final received = scoped.payments.fold<double>(
      0,
      (sum, p) => sum + p.amount,
    );
    final open = views
        .where(
          (v) =>
              v.status == ChargeStatus.pendente ||
              v.status == ChargeStatus.atrasado,
        )
        .fold<double>(0, (sum, v) => sum + v.amount);
    final ticket = scoped.payments.isEmpty
        ? 0.0
        : received / scoped.payments.length;
    final series = monthPointsInRange(scoped, from, to);
    final byMethod = receivedByMethod(scoped.payments);
    final byService = receivedByService(scoped, scoped.payments);
    final clientServices = widget.workspace.services
        .where((s) => s.clientId == widget.client.id)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        PeriodBar(
          range: _range,
          earliest: earliest,
          nullLabel: 'Desde o início',
          onChanged: (value) => setState(() => _range = value),
        ),
        if (clientServices.isNotEmpty) ...[
          const SizedBox(height: 10),
          FilterCombobox<String?>(
            options: [
              const FilterOption<String?>(
                value: null,
                label: 'Todos os serviços',
              ),
              for (final service in clientServices)
                FilterOption<String?>(value: service.id, label: service.name),
            ],
            value: _serviceId,
            hint: 'Todos os serviços',
            allLabel: 'Todos os serviços',
            icon: Icons.work_outline,
            onChanged: (value) => setState(() => _serviceId = value),
          ),
        ],
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
              label: 'Recebido',
              value: brl(received),
              hint: '${scoped.payments.length} pagamentos',
              tone: AppColors.success,
              icon: Icons.account_balance_wallet_outlined,
            ),
            StatCard(
              label: 'Em aberto',
              value: brl(open),
              tone: AppColors.info,
              icon: Icons.schedule_outlined,
            ),
            StatCard(
              label: 'Ticket médio',
              value: brl(ticket),
              tone: AppColors.primary,
              icon: Icons.receipt_outlined,
            ),
            StatCard(
              label: 'Cobranças',
              value: '${views.length}',
              tone: AppColors.warning,
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Evolução mensal',
          child: Column(
            children: [
              RevenueChart(
                series: series,
                onMonthTap: (key) => _openMonth(context, scoped, key),
              ),
              const SizedBox(height: 8),
              const ChartLegend(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Por forma de pagamento',
          child: byMethod.isEmpty
              ? const _InfoHint('Sem pagamentos no período.')
              : BreakdownPie(items: byMethod),
        ),
        if (_serviceId == null && byService.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Recebido por serviço',
            child: BreakdownBars(items: byService, tone: AppColors.info),
          ),
        ],
      ],
    );
  }
}

class _InfoHint extends StatelessWidget {
  const _InfoHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.mutedForeground),
      ),
    );
  }
}
