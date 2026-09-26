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
import '../../models/client_notification.dart';
import '../../models/recurring_charge.dart';
import '../../models/service.dart';
import '../../models/workspace.dart';
import '../../repositories/clients_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/breakdown_charts.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_combobox.dart';
import '../../widgets/metric_strip.dart';
import '../../widgets/period_filter.dart';
import '../../widgets/records_sheet.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/whatsapp_icon.dart';
import '../charges/charge_card.dart';
import '../charges/charge_config_sheets.dart';
import '../charges/charge_form_sheet.dart';
import '../charges/recurring_form_sheet.dart';
import '../services/service_form_sheet.dart';
import 'client_form_sheet.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _lastIndex = 0;
  ChargeStatus? _statusFilter;
  bool _openOnly = false;

  String? get _activeFilter {
    if (_openOnly) return 'open';
    if (_statusFilter == ChargeStatus.atrasado) return 'overdue';
    if (_statusFilter == ChargeStatus.pago) return 'paid';
    return null;
  }

  void _toggleOpenOnly() {
    setState(() {
      _openOnly = !_openOnly;
      _statusFilter = null;
    });
  }

  void _toggleStatus(ChargeStatus status) {
    setState(() {
      _statusFilter = _statusFilter == status ? null : status;
      _openOnly = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Troca o botão fixo conforme a aba (cobranças/serviços).
    if (_tabController.index != _lastIndex) {
      _lastIndex = _tabController.index;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(workspaceProvider);
    final clientId = widget.clientId;

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

        final clientChargeIds = views.map((view) => view.id).toSet();
        final openTotal = views
            .where(
              (view) =>
                  view.status == ChargeStatus.pendente ||
                  view.status == ChargeStatus.atrasado,
            )
            .fold<double>(0, (sum, view) => sum + view.amount);
        final overdueTotal = views
            .where((view) => view.status == ChargeStatus.atrasado)
            .fold<double>(0, (sum, view) => sum + view.amount);
        final receivedTotal = workspace.payments
            .where((payment) => clientChargeIds.contains(payment.chargeId))
            .fold<double>(0, (sum, payment) => sum + payment.amount);

        return Scaffold(
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
          floatingActionButton: _buildFab(client),
          body: Column(
            children: [
              _ClientHeader(
                client: client,
                openTotal: openTotal,
                overdueTotal: overdueTotal,
                receivedTotal: receivedTotal,
                chargesCount: views.length,
                activeFilter: _activeFilter,
                onTapMetric: (index) {
                  if (_tabController.index != 0) _tabController.animateTo(0);
                  if (index == 0) _toggleOpenOnly();
                  if (index == 1) _toggleStatus(ChargeStatus.atrasado);
                  if (index == 2) _toggleStatus(ChargeStatus.pago);
                },
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Cobranças'),
                  Tab(text: 'Serviços'),
                  Tab(text: 'Notificações'),
                  Tab(text: 'Relatório'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ChargesTab(
                      views: views.where((view) {
                        if (_openOnly) {
                          return view.status == ChargeStatus.pendente ||
                              view.status == ChargeStatus.atrasado;
                        }
                        if (_statusFilter != null) {
                          return view.status == _statusFilter;
                        }
                        return true;
                      }).toList(),
                    ),
                    _ServicesTab(
                      services: services,
                      recurring: recurring,
                      clientId: client.id,
                    ),
                    _NotificationsTab(clientId: client.id),
                    _ReportTab(client: client, workspace: workspace),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Botão fixo conforme a aba: nova cobrança, novo serviço ou nenhum.
  Widget? _buildFab(Client client) {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => showChargeForm(context, initialClientId: client.id),
          icon: const Icon(Icons.add),
          label: const Text('Nova cobrança'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => showServiceForm(context, initialClientId: client.id),
          icon: const Icon(Icons.add),
          label: const Text('Novo serviço'),
        );
      default:
        return null;
    }
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
  const _ClientHeader({
    required this.client,
    required this.openTotal,
    required this.overdueTotal,
    required this.receivedTotal,
    required this.chargesCount,
    required this.activeFilter,
    required this.onTapMetric,
  });

  final Client client;
  final double openTotal;
  final double overdueTotal;
  final double receivedTotal;
  final int chargesCount;

  /// Filtro ativo ('open', 'overdue', 'paid') para destacar o card clicado.
  final String? activeFilter;
  final void Function(int index) onTapMetric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hasPhone = client.phone != null && client.phone!.isNotEmpty;
    final hasEmail = client.email != null && client.email!.isNotEmpty;
    final hasDocument = client.document != null && client.document!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        initials(client.name),
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (client.active)
                                const StatusPill(
                                  label: 'Ativo',
                                  tone: AppColors.success,
                                  icon: Icons.check_circle_outline,
                                  compact: true,
                                )
                              else
                                const StatusPill(
                                  label: 'Inativo',
                                  tone: AppColors.danger,
                                  icon: Icons.block,
                                  compact: true,
                                ),
                              if (client.whatsappValid == true)
                                const StatusPill(
                                  label: 'WhatsApp confirmado',
                                  tone: AppColors.success,
                                  icon: Icons.verified_outlined,
                                  compact: true,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (hasPhone)
                      IconButton(
                        tooltip: 'Abrir conversa no WhatsApp',
                        onPressed: () {
                          final digits = client.phone!.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          );
                          final number = digits.length <= 11
                              ? '55$digits'
                              : digits;
                          launchUrl(Uri.parse('https://wa.me/$number'));
                        },
                        icon: const WhatsAppIcon(size: 20),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366)
                              .withValues(alpha: 0.12),
                        ),
                      ),
                    IconButton(
                      tooltip: client.notificationsEnabled
                          ? 'Avisos automáticos ativados'
                          : 'Avisos automáticos desativados',
                      onPressed: () => showClientNotificationSheet(
                        context,
                        clientId: client.id,
                      ),
                      icon: Icon(
                        client.notificationsEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: client.notificationsEnabled
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: client.notificationsEnabled
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
                if (hasPhone || hasDocument || hasEmail) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (hasPhone)
                        _ContactItem(
                          icon: Icons.call_outlined,
                          value: client.phone!,
                        ),
                      if (hasDocument)
                        _ContactItem(
                          icon: Icons.badge_outlined,
                          label: 'CPF/CNPJ',
                          value: client.document!,
                        ),
                      if (hasEmail)
                        _ContactItem(
                          icon: Icons.mail_outline,
                          value: client.email!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetricStrip(
            onTap: onTapMetric,
            items: [
              MetricItem(
                label: 'Em aberto',
                value: brl(openTotal),
                tone: AppColors.info,
                icon: Icons.schedule_outlined,
                hint: '$chargesCount cobranças',
                active: activeFilter == 'open',
              ),
              MetricItem(
                label: 'Atrasado',
                value: brl(overdueTotal),
                tone: AppColors.danger,
                icon: Icons.warning_amber_outlined,
                active: activeFilter == 'overdue',
              ),
              MetricItem(
                label: 'Recebido',
                value: brl(receivedTotal),
                tone: AppColors.success,
                icon: Icons.account_balance_wallet_outlined,
                active: activeFilter == 'paid',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({required this.icon, required this.value, this.label});

  final IconData icon;
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 5),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                if (label != null)
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                TextSpan(text: value),
              ],
            ),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
            statusLabel: service.status.label,
            statusTone: serviceStatusTone(service.status),
            onTap: () => context.push('/services/${service.id}'),
          ),
          const SizedBox(height: 10),
        ],
        for (final item in recurring) ...[
          _ServiceRow(
            name: item.description,
            subtitle: 'Recorrente · ${item.frequency.label}',
            amount: item.amount,
            statusLabel: item.active ? 'Ativa' : 'Pausada',
            statusTone: item.active
                ? AppColors.success
                : AppColors.mutedForeground,
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
    required this.statusLabel,
    required this.statusTone,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final double amount;
  final String statusLabel;
  final Color statusTone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  brl(amount),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                StatusPill(label: statusLabel, tone: statusTone, compact: true),
              ],
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedForeground,
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

const Map<String, String> _notificationKindLabels = {
  'cobranca': 'Aviso de cobrança',
  'cobranca_vencendo': 'Cobrança a vencer',
  'cobranca_atraso': 'Cobrança em atraso',
  'confirmacao_pagamento': 'Confirmação de pagamento',
  'boas_vindas': 'Boas-vindas',
  'resposta': 'Resposta',
  'modelo': 'Modelo',
};

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientNotificationsProvider(clientId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(clientNotificationsProvider(clientId)),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_outlined,
            title: 'Nenhuma notificação ainda',
            description:
                'Ative as notificações automáticas em Configurações ou avise '
                'uma cobrança pela aba Cobranças.',
          );
        }
        final sent = notifications.where((n) => !n.inbound).length;
        final delivered = notifications
            .where((n) => n.deliveredAt != null)
            .length;
        final read = notifications.where((n) => n.readAt != null).length;
        final failed = notifications
            .where((n) => !n.inbound && n.status != 'enviado')
            .length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(label: 'Enviadas', value: '$sent'),
                StatCard(
                  label: 'Entregues',
                  value: '$delivered',
                  tone: AppColors.success,
                ),
                StatCard(
                  label: 'Lidas',
                  value: '$read',
                  tone: AppColors.success,
                ),
                StatCard(
                  label: 'Falhas',
                  value: '$failed',
                  tone: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final notification in notifications)
              _NotificationTile(notification: notification),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final ClientNotification notification;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inbound = notification.inbound;
    final failed = !inbound && notification.status != 'enviado';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                inbound ? Icons.call_received : Icons.call_made,
                size: 15,
                color: inbound ? AppColors.info : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _notificationKindLabels[notification.kind] ??
                      notification.kind,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusPill(
                label: notification.deliveryLabel,
                tone: failed
                    ? AppColors.danger
                    : notification.deliveredAt != null ||
                          notification.readAt != null
                    ? AppColors.success
                    : AppColors.warning,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(notification.body.isEmpty ? '—' : notification.body),
          const SizedBox(height: 6),
          Text(
            '${formatDateTime(notification.createdAt)} · '
            '${notification.source == 'auto' ? 'automática' : 'manual'}',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          if (notification.chargeDescription.isNotEmpty)
            Text(
              'Cobrança: ${notification.chargeDescription} · '
              '${brl(notification.chargeAmount)}',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          if (notification.error != null && notification.error!.isNotEmpty)
            Text(
              notification.error!,
              style: textTheme.labelSmall?.copyWith(color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}
