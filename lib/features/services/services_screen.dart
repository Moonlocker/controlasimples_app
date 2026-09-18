import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/service.dart';
import '../../models/workspace.dart';
import '../../repositories/services_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import 'service_form_sheet.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  ServiceStatus? _status;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showServiceForm(context),
          ),
        ],
      ),
      body: workspaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(workspaceProvider),
        ),
        data: (workspace) {
          final query = _query.trim().toLowerCase();
          final services = workspace.services.where((service) {
            if (_status != null && service.status != _status) return false;
            if (query.isEmpty) return true;
            return service.name.toLowerCase().contains(query) ||
                workspace
                    .clientName(service.clientId)
                    .toLowerCase()
                    .contains(query);
          }).toList();
          final stats = _stats(workspace);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por serviço ou cliente',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _Pill(
                      label: 'Todos',
                      selected: _status == null,
                      onTap: () => setState(() => _status = null),
                    ),
                    for (final status in ServiceStatus.values)
                      _Pill(
                        label: status.label,
                        selected: _status == status,
                        onTap: () => setState(() => _status = status),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: services.isEmpty
                    ? const EmptyState(
                        icon: Icons.work_outline,
                        title: 'Nenhum serviço encontrado',
                        description:
                            'Ajuste os filtros ou cadastre um novo serviço.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(workspaceProvider);
                          try {
                            await ref.read(workspaceProvider.future);
                          } catch (_) {}
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: services.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final service = services[index];
                            return _ServiceTile(
                              service: service,
                              clientName: workspace.clientName(
                                service.clientId,
                              ),
                              stats: stats[service.id] ?? _ServiceStats(),
                              onTap: () =>
                                  context.push('/services/${service.id}'),
                              onDuplicate: () => showServiceForm(
                                context,
                                duplicateFrom: service,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, _ServiceStats> _stats(Workspace workspace) {
    final map = <String, _ServiceStats>{};
    for (final service in workspace.services) {
      map[service.id] = _ServiceStats();
    }
    for (final charge in workspace.charges) {
      final id = charge.serviceId;
      if (id == null) continue;
      final entry = map[id];
      if (entry == null) continue;
      entry.chargeCount += 1;
      if (charge.status == ChargeStatus.pago) {
        entry.received += charge.amount;
      }
    }
    for (final recurring in workspace.recurring) {
      final id = recurring.serviceId;
      if (id == null) continue;
      final entry = map[id];
      if (entry == null) continue;
      if (recurring.active) entry.monthly += recurring.amount;
    }
    return map;
  }
}

class _ServiceStats {
  _ServiceStats();

  double received = 0;
  double monthly = 0;
  int chargeCount = 0;
}

class _ServiceTile extends ConsumerWidget {
  const _ServiceTile({
    required this.service,
    required this.clientName,
    required this.stats,
    required this.onTap,
    required this.onDuplicate,
  });

  final Service service;
  final String clientName;
  final _ServiceStats stats;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;

  Color _statusColor() {
    switch (service.status) {
      case ServiceStatus.negociacao:
        return AppColors.warning;
      case ServiceStatus.andamento:
        return AppColors.info;
      case ServiceStatus.concluido:
        return AppColors.success;
      case ServiceStatus.cancelado:
        return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isRecurring = service.billingType != ServiceBilling.unico;
    final progress = !isRecurring && service.amount > 0
        ? (stats.received / service.amount).clamp(0.0, 1.0)
        : 0.0;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (service.link != null && service.link!.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.open_in_new,
                      size: 18,
                      color: AppColors.info,
                    ),
                    onPressed: () => launchUrl(Uri.parse(service.link!)),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await showServiceForm(context, service: service);
                    } else if (value == 'duplicate') {
                      onDuplicate();
                    } else if (value == 'delete') {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Excluir serviço',
                        message: 'As cobranças e recorrências vinculadas também serão removidas.',
                        confirmLabel: 'Excluir',
                        destructive: true,
                      );
                      if (!confirmed) return;
                      await ref
                          .read(servicesRepositoryProvider)
                          .delete(service.id);
                      ref.invalidate(workspaceProvider);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            Text(
              '$clientName · ${service.billingType.label}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (service.description != null &&
                service.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                service.description!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    service.status.label,
                    style: textTheme.labelSmall?.copyWith(
                      color: _statusColor(),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  isRecurring
                      ? '${brl(stats.monthly)}/mês'
                      : brl(service.amount),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (!isRecurring && service.amount > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppColors.muted,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${brl(stats.received)} de ${brl(service.amount)} · ${(progress * 100).toStringAsFixed(0)}%',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ] else if (isRecurring) ...[
              const SizedBox(height: 4),
              Text(
                '${stats.chargeCount} cobrança(s)',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? AppColors.primary : AppColors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundColor: AppColors.muted,
      ),
    );
  }
}
