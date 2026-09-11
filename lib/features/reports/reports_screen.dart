import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/breakdown_charts.dart';
import '../../widgets/filter_combobox.dart';
import '../../widgets/period_filter.dart';
import '../../widgets/records_sheet.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import 'report_pdf.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  PeriodRange? _range;
  String? _clientId;
  String? _serviceId;
  bool _initializedRange = false;

  DateTime _earliest(Workspace workspace) {
    DateTime? min;
    for (final payment in workspace.payments) {
      if (min == null || payment.paidAt.isBefore(min)) min = payment.paidAt;
    }
    for (final charge in workspace.charges) {
      if (min == null || charge.dueDate.isBefore(min)) min = charge.dueDate;
    }
    return min ?? today();
  }

  DateTime _latest(Workspace workspace) {
    DateTime? max;
    for (final charge in workspace.charges) {
      if (max == null || charge.dueDate.isAfter(max)) max = charge.dueDate;
    }
    for (final payment in workspace.payments) {
      if (max == null || payment.paidAt.isAfter(max)) max = payment.paidAt;
    }
    final now = today();
    if (max == null) return now;
    return max.isAfter(now) ? max : now;
  }

  Workspace _scope(Workspace workspace, DateTime from, DateTime to) {
    bool inRange(DateTime date) =>
        !dateOnly(date).isBefore(dateOnly(from)) && !dateOnly(date).isAfter(dateOnly(to));
    bool matchScope(String clientId, String? serviceId) =>
        (_clientId == null || clientId == _clientId) &&
        (_serviceId == null || serviceId == _serviceId);

    final charges =
        workspace.charges.where((c) => matchScope(c.clientId, c.serviceId)).toList();
    final allScopedIds = charges.map((c) => c.id).toSet();
    final payments = workspace.payments
        .where((p) => allScopedIds.contains(p.chargeId) && inRange(p.paidAt))
        .toList();
    final recurring = workspace.recurring
        .where((r) => matchScope(r.clientId, r.serviceId))
        .toList();
    return Workspace(
      clients: workspace.clients,
      services: workspace.services,
      charges: charges,
      recurring: recurring,
      payments: payments,
    );
  }

  RangeSummary _summary(Workspace scoped, PeriodRange? range) {
    final views = chargeViews(scoped)
        .where((v) => range == null || range.contains(v.dueDate))
        .toList();
    final received = scoped.payments.fold<double>(0, (sum, p) => sum + p.amount);
    final open = views
        .where((v) => v.status == ChargeStatus.pendente || v.status == ChargeStatus.atrasado)
        .fold<double>(0, (sum, v) => sum + v.amount);
    final overdue = views
        .where((v) => v.status == ChargeStatus.atrasado)
        .fold<double>(0, (sum, v) => sum + v.amount);
    final paidCount = views.where((v) => v.status == ChargeStatus.pago).length;
    return RangeSummary(
      received: received,
      open: open,
      overdue: overdue,
      avgTicket: scoped.payments.isEmpty ? 0 : received / scoped.payments.length,
      paidCount: paidCount,
      totalCharges: views.length,
    );
  }

  Future<void> _exportCharges(Workspace scoped) async {
    final buffer = StringBuffer('Cliente;Descricao;Servico;Vencimento;Valor;Status\n');
    for (final view in chargeViews(scoped)) {
      buffer.writeln(
        '${view.clientName};${view.description};${view.serviceName ?? ''};'
        '${formatDate(view.dueDate)};${view.amount.toStringAsFixed(2).replaceAll('.', ',')};'
        '${view.status.label}',
      );
    }
    await _share('cobrancas.csv', buffer.toString());
  }

  Future<void> _exportPayments(Workspace scoped) async {
    final buffer = StringBuffer('Data;Cobranca;Cliente;Valor;Forma\n');
    for (final payment in scoped.payments) {
      final charge = scoped.chargeById(payment.chargeId);
      buffer.writeln(
        '${formatDate(payment.paidAt)};${charge?.description ?? ''};'
        '${charge == null ? '' : scoped.clientName(charge.clientId)};'
        '${payment.amount.toStringAsFixed(2).replaceAll('.', ',')};${payment.method.label}',
      );
    }
    await _share('pagamentos.csv', buffer.toString());
  }

  Future<void> _share(String name, String content) async {
    final file = XFile.fromData(utf8.encode(content), name: name, mimeType: 'text/csv');
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: 'Relatório Controla Simples'),
    );
  }

  Future<void> _exportPdf(Workspace workspace, Workspace scoped, RangeSummary summary) async {
    final bytes = await buildReportPdf(
      scoped: scoped,
      range: _range,
      rangeText: rangeLabel(_range),
      summary: summary,
      company: workspace.profile?.company ?? workspace.profile?.name,
      clientName: _clientId == null ? null : workspace.clientName(_clientId),
      serviceName: _serviceId == null ? null : workspace.serviceName(_serviceId),
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'relatorio');
  }

  void _openStat(BuildContext context, Workspace scoped, String kind) {
    final views = chargeViews(scoped);
    if (kind == 'received') {
      showRecordsSheet(
        context,
        title: 'Recebido no período',
        subtitle: rangeLabel(_range),
        sections: [
          RecordSection(
            title: 'Pagamentos (${scoped.payments.length})',
            tone: AppColors.success,
            rows: [
              for (final payment in scoped.payments)
                () {
                  final charge = scoped.chargeById(payment.chargeId);
                  return RecordRow(
                    clientName:
                        charge == null ? '—' : scoped.clientName(charge.clientId),
                    serviceName: scoped.serviceName(charge?.serviceId),
                    description: charge?.description ?? 'Pagamento registrado',
                    amount: payment.amount,
                    date: payment.paidAt,
                    dateLabel: 'Recebido em',
                    method: payment.method,
                    badgeLabel: 'Pago',
                  );
                }(),
            ],
          ),
        ],
        emptyHint: 'Nenhum pagamento recebido neste período.',
      );
      return;
    }
    final filtered = kind == 'overdue'
        ? views.where((v) => v.status == ChargeStatus.atrasado).toList()
        : views
            .where((v) => v.status == ChargeStatus.pendente || v.status == ChargeStatus.atrasado)
            .toList();
    showRecordsSheet(
      context,
      title: kind == 'overdue' ? 'Atrasado no período' : 'Em aberto no período',
      subtitle: rangeLabel(_range),
      sections: [
        RecordSection(
          title: '${filtered.length} cobrança(s)',
          tone: kind == 'overdue' ? AppColors.danger : AppColors.info,
          rows: [
            for (final view in filtered)
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
      emptyHint: 'Nenhuma cobrança neste período.',
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
    final workspaceAsync = ref.watch(workspaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: workspaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(workspaceProvider),
        ),
        data: (workspace) {
          final earliest = _earliest(workspace);
          if (!_initializedRange) {
            _range = presetRange(PeriodPreset.ninetyDays, earliest);
            _initializedRange = true;
          }
          final latest = _latest(workspace);
          final from = _range?.from ?? earliest;
          final to = _range?.to ?? latest;
          final scoped = _scope(workspace, from, to);
          final summary = _summary(scoped, _range);
          final series = monthPointsInRange(scoped, from, to);
          final byMethod = receivedByMethod(scoped.payments);
          final byClient = receivedByClient(scoped, scoped.payments);
          final byService = receivedByService(scoped, scoped.payments);

          final clientOptions = [
            const FilterOption<String?>(value: null, label: 'Todos os clientes'),
            for (final client in workspace.clients.where((c) => c.active))
              FilterOption<String?>(value: client.id, label: client.name),
          ];
          final serviceOptions = [
            const FilterOption<String?>(value: null, label: 'Todos os serviços'),
            for (final service in workspace.services
                .where((s) => _clientId == null || s.clientId == _clientId))
              FilterOption<String?>(value: service.id, label: service.name),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const ScreenHeader(
                title: 'Resumo financeiro',
                description: 'Filtre por período, cliente ou serviço.',
                leading: BrandBadge(),
              ),
              const SizedBox(height: 12),
              PeriodBar(
                range: _range,
                earliest: earliest,
                nullLabel: 'Desde o início',
                onChanged: (value) => setState(() => _range = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilterCombobox<String?>(
                      options: clientOptions,
                      value: _clientId,
                      hint: 'Todos os clientes',
                      allLabel: 'Todos os clientes',
                      icon: Icons.person_outline,
                      onChanged: (value) => setState(() {
                        _clientId = value;
                        _serviceId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilterCombobox<String?>(
                      options: serviceOptions,
                      value: _serviceId,
                      hint: 'Todos os serviços',
                      allLabel: 'Todos os serviços',
                      icon: Icons.work_outline,
                      onChanged: (value) => setState(() => _serviceId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _tap(() => _openStat(context, scoped, 'received'),
                      StatCard(
                        label: 'Recebido',
                        value: brl(summary.received),
                        hint: '${scoped.payments.length} pagamentos',
                        tone: AppColors.success,
                      )),
                  _tap(() => _openStat(context, scoped, 'open'),
                      StatCard(
                        label: 'Em aberto',
                        value: brl(summary.open),
                        tone: AppColors.info,
                      )),
                  _tap(() => _openStat(context, scoped, 'overdue'),
                      StatCard(
                        label: 'Atrasado',
                        value: brl(summary.overdue),
                        tone: AppColors.danger,
                      )),
                  StatCard(
                    label: 'Ticket médio',
                    value: brl(summary.avgTicket),
                    tone: AppColors.primary,
                  ),
                  StatCard(
                    label: 'Taxa de recebimento',
                    value: '${summary.receiveRate.toStringAsFixed(0)}%',
                    hint: '${summary.paidCount} pagas de ${summary.totalCharges}',
                    tone: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Evolução no período',
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
                title: 'Recebido por forma de pagamento',
                child: byMethod.isEmpty
                    ? const _EmptyHint('Sem pagamentos no período.')
                    : BreakdownPie(items: byMethod),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Recebido por cliente',
                child: byClient.isEmpty
                    ? const _EmptyHint('Sem recebimentos no período.')
                    : BreakdownBars(items: byClient),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Recebido por serviço',
                child: byService.isEmpty
                    ? const _EmptyHint('Sem recebimentos no período.')
                    : BreakdownBars(items: byService, tone: AppColors.info),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportCharges(scoped),
                      icon: const Icon(Icons.table_view_outlined, size: 18),
                      label: const Text('Cobranças CSV'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportPayments(scoped),
                      icon: const Icon(Icons.table_view_outlined, size: 18),
                      label: const Text('Pagamentos CSV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _exportPdf(workspace, scoped, summary),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Exportar relatório em PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tap(VoidCallback onTap, Widget child) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: child);
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.mutedForeground),
      ),
    );
  }
}
