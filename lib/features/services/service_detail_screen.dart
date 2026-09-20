import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../models/recurring_charge.dart';
import '../../models/service.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/services_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../charges/charge_card.dart';
import '../charges/charge_form_sheet.dart';
import '../charges/recurring_form_sheet.dart';
import 'service_form_sheet.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

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
        final service = workspace.serviceById(serviceId);
        if (service == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(title: 'Serviço não encontrado'),
          );
        }

        final views = chargeViews(workspace)
            .where((view) => view.serviceId == service.id)
            .toList()
            .reversed
            .toList();
        final recurring = workspace.recurring
            .where((item) => item.serviceId == service.id)
            .toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(service.name, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showServiceForm(context, service: service),
                ),
                _ServiceMenu(service: service),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => showChargeForm(
                context,
                initialClientId: service.clientId,
                initialServiceId: service.id,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nova cobrança'),
            ),
            body: Column(
              children: [
                _ServiceHeader(
                  service: service,
                  clientName: workspace.clientName(service.clientId),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Cobranças'),
                    Tab(text: 'Recorrências'),
                    Tab(text: 'Informações'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ChargesTab(service: service, views: views),
                      _RecurringTab(service: service, recurring: recurring),
                      _InfoTab(
                        service: service,
                        clientName: workspace.clientName(service.clientId),
                        recurring: recurring,
                      ),
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

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({required this.service, required this.clientName});

  final Service service;
  final String clientName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(
              Icons.work_outline,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${service.billingType.label} · ${brl(service.amount)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(
            label: service.status.label,
            tone: serviceStatusTone(service.status),
            icon: serviceStatusIcon(service.status),
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ChargesTab extends StatelessWidget {
  const _ChargesTab({required this.service, required this.views});

  final Service service;
  final List<ChargeView> views;

  @override
  Widget build(BuildContext context) {
    final chargeIds = views.map((view) => view.id).toSet();
    final received = views
        .where((v) => v.status == ChargeStatus.pago)
        .fold<double>(0, (total, v) => total + v.amount);
    final open = views
        .where((v) => v.status == ChargeStatus.pendente)
        .fold<double>(0, (total, v) => total + v.amount);
    final overdue = views
        .where((v) => v.status == ChargeStatus.atrasado)
        .fold<double>(0, (total, v) => total + v.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
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
              label: 'Atrasado',
              value: brl(overdue),
              tone: AppColors.danger,
              icon: Icons.warning_amber_outlined,
            ),
            StatCard(
              label: 'Cobranças',
              value: '${chargeIds.length}',
              tone: AppColors.primary,
              icon: Icons.receipt_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (views.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nenhuma cobrança',
            description: 'Crie a primeira cobrança deste serviço.',
          )
        else
          for (final view in views) ...[
            ChargeCard(view: view, showClient: false),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _RecurringTab extends StatelessWidget {
  const _RecurringTab({required this.service, required this.recurring});

  final Service service;
  final List<RecurringCharge> recurring;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        OutlinedButton.icon(
          onPressed: () => showRecurringForm(
            context,
            initialClientId: service.clientId,
            initialServiceId: service.id,
          ),
          icon: const Icon(Icons.repeat, size: 18),
          label: const Text('Nova recorrência'),
        ),
        const SizedBox(height: 16),
        if (recurring.isEmpty)
          const EmptyState(
            icon: Icons.autorenew,
            title: 'Nenhuma recorrência',
            description: 'Crie uma cobrança recorrente para este serviço.',
          )
        else
          for (final item in recurring) ...[
            _RecurringRow(item: item),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.service,
    required this.clientName,
    required this.recurring,
  });

  final Service service;
  final String clientName;
  final List<RecurringCharge> recurring;

  @override
  Widget build(BuildContext context) {
    final activeRecurring = recurring.where((item) => item.active);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        SectionCard(
          title: 'Informações',
          child: Column(
            children: [
              _InfoLine(label: 'Cliente', value: clientName),
              _InfoLine(label: 'Cobrança', value: service.billingType.label),
              _InfoLine(label: 'Situação', value: service.status.label),
              _InfoLine(label: 'Valor', value: brl(service.amount)),
              if (activeRecurring.isNotEmpty)
                _InfoLine(
                  label: 'Mensalidade',
                  value: brl(
                    activeRecurring.fold<double>(
                      0,
                      (sum, item) => sum + item.amount,
                    ),
                  ),
                ),
              _InfoLine(label: 'Início', value: formatDate(service.startDate)),
              _InfoLine(
                label: 'Término',
                value: service.endDate == null
                    ? 'Contínuo'
                    : formatDate(service.endDate!),
              ),
            ],
          ),
        ),
        if (service.description != null && service.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(title: 'Descrição', child: Text(service.description!)),
        ],
        if (service.link != null && service.link!.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(service.link!)),
            icon: const Icon(Icons.link),
            label: const Text('Abrir link do serviço'),
          ),
        ],
      ],
    );
  }
}

class _ServiceMenu extends ConsumerWidget {
  const _ServiceMenu({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final repository = ref.read(servicesRepositoryProvider);
        if (value.startsWith('status:')) {
          final status = ServiceStatus.fromWire(value.substring(7));
          await repository.setStatus(service.id, status);
          ref.invalidate(workspaceProvider);
        } else if (value == 'duplicate') {
          await showServiceForm(context, duplicateFrom: service);
        } else if (value == 'delete') {
          final confirmed = await showConfirmDialog(
            context,
            title: 'Excluir serviço',
            message: 'As cobranças e recorrências vinculadas a este serviço também serão removidas.',
            confirmLabel: 'Excluir',
            destructive: true,
          );
          if (!confirmed) return;
          await repository.delete(service.id);
          ref.invalidate(workspaceProvider);
          if (context.mounted) context.pop();
        }
      },
      itemBuilder: (context) => [
        for (final status in ServiceStatus.values)
          PopupMenuItem(
            value: 'status:${status.wire}',
            child: Text('Marcar como ${status.label.toLowerCase()}'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'duplicate',
          child: Text('Duplicar serviço'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Excluir serviço')),
      ],
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({required this.item});

  final RecurringCharge item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => showRecurringForm(context, recurring: item),
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
                    item.description,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${item.frequency.label} · ${item.active ? 'Ativa' : 'Pausada'} · dia ${item.dueDay}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              brl(item.amount),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.mutedForeground,
              ),
              onSelected: (value) async {
                final repository = ref.read(chargesRepositoryProvider);
                if (value == 'toggle') {
                  await repository.toggleRecurring(item.id, !item.active);
                  ref.invalidate(workspaceProvider);
                } else if (value == 'delete') {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Excluir recorrência',
                    message: 'As cobranças já geradas não serão removidas.',
                    confirmLabel: 'Excluir',
                    destructive: true,
                  );
                  if (!confirmed) return;
                  await repository.deleteRecurring(item.id);
                  ref.invalidate(workspaceProvider);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(item.active ? 'Pausar' : 'Reativar'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
