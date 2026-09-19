import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../models/asaas.dart';
import '../../repositories/asaas_repository.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_combobox.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/metric_strip.dart';
import '../../widgets/period_filter.dart';
import '../../widgets/plan_access.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_badge.dart';
import '../auth/auth_providers.dart';
import 'charge_card.dart';
import 'charge_config_sheets.dart';
import 'charge_form_sheet.dart';

class ChargesScreen extends ConsumerStatefulWidget {
  const ChargesScreen({super.key});

  @override
  ConsumerState<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends ConsumerState<ChargesScreen> {
  PeriodRange? _range = currentMonthWindow();
  ChargeStatus? _status;
  String? _clientId;
  String _query = '';
  bool _showFilters = false;
  bool _generating = false;
  bool _autoRan = false;
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  bool get _hasFilters => _status != null || _clientId != null;

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _selectAll(List<ChargeView> views) {
    setState(() {
      _selected
        ..clear()
        ..addAll(views.map((view) => view.charge.id));
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<BillingType?> _pickBillingType() {
    return showDialog<BillingType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Forma de pagamento no Asaas'),
        children: [
          for (final type in BillingType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(type),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(type.label),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _bulkEmit(List<ChargeView> views) async {
    final targets = views
        .where(
          (view) =>
              _selected.contains(view.charge.id) &&
              view.charge.asaasPaymentId == null &&
              (view.status == ChargeStatus.pendente ||
                  view.status == ChargeStatus.atrasado),
        )
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma cobrança elegível para emissão.'),
        ),
      );
      return;
    }
    final billingType = await _pickBillingType();
    if (billingType == null || !mounted) return;
    setState(() => _bulkBusy = true);
    var ok = 0;
    var failed = 0;
    for (final view in targets) {
      try {
        await ref
            .read(asaasRepositoryProvider)
            .emit(view.charge.id, billingType);
        ok++;
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(workspaceProvider);
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$ok emitida(s)${failed > 0 ? ' · $failed falha(s)' : ''}.',
        ),
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Excluir cobranças',
      message:
          '${ids.length} cobrança(s) serão excluídas. Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      for (final id in ids) {
        await ref.read(chargesRepositoryProvider).delete(id);
      }
      ref.invalidate(workspaceProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _bulkBusy = false;
          _selected.clear();
        });
      }
    }
  }

  Future<void> _generate(List<PendingOccurrence> pending) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || pending.isEmpty) return;
    setState(() => _generating = true);
    try {
      final rows = pending
          .map((occurrence) => occurrence.toChargeMap(userId))
          .toList();
      await ref.read(chargesRepositoryProvider).insertOccurrences(rows);
      ref.invalidate(workspaceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${rows.length} cobrança(s) gerada(s).')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível gerar: ${friendlyError(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  bool _matches(ChargeView view) {
    if (_status != null && view.status != _status) return false;
    if (_clientId != null && view.clientId != _clientId) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final normalizedAmount = query.replaceAll('.', '').replaceAll(',', '.');
    return view.clientName.toLowerCase().contains(query) ||
        view.description.toLowerCase().contains(query) ||
        (view.serviceName?.toLowerCase().contains(query) ?? false) ||
        brl(view.amount).toLowerCase().contains(query) ||
        view.amount.toStringAsFixed(2).contains(normalizedAmount);
  }

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(workspaceProvider);
    final workspace = workspaceAsync.value;
    final chargesLocked = workspace?.chargesLimitReached ?? false;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: chargesLocked
            ? () => showPlanLockedDialog(
                context,
                feature: 'Nova cobrança',
                description:
                    'Seu plano permite até ${workspace?.plan?.maxChargesMonth} '
                    'cobranças por mês. Faça upgrade para criar mais.',
              )
            : () => showChargeForm(context),
        icon: Icon(chargesLocked ? Icons.lock_outline_rounded : Icons.add),
        label: Text(chargesLocked ? 'Limite do plano' : 'Nova cobrança'),
      ),
      body: SafeArea(
        child: workspaceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(workspaceProvider),
          ),
          data: (workspace) {
            if (!_autoRan &&
                workspace.recurring.any((r) => r.active && r.autoAsaas)) {
              _autoRan = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final created = await ref
                      .read(asaasRepositoryProvider)
                      .runAuto();
                  if (created > 0) ref.invalidate(workspaceProvider);
                } catch (_) {
                  // Falha silenciosa: o usuário pode emitir manualmente.
                }
              });
            }
            final inRange = chargeViews(workspace)
                .where(
                  (view) => _range == null || _range!.contains(view.dueDate),
                )
                .toList()
                .reversed
                .toList();
            final views = inRange.where(_matches).toList();
            final pending =
                (_range == null
                        ? const <PendingOccurrence>[]
                        : pendingOccurrencesInRange(
                            workspace,
                            _range!.from,
                            _range!.to,
                          ))
                    .where(
                      (occurrence) =>
                          (_clientId == null ||
                              occurrence.clientId == _clientId) &&
                          (_query.trim().isEmpty ||
                              occurrence.clientName.toLowerCase().contains(
                                _query.toLowerCase(),
                              ) ||
                              occurrence.description.toLowerCase().contains(
                                _query.toLowerCase(),
                              )),
                    )
                    .toList();

            // Contagem por status considerando período, cliente e busca, para
            // o usuário ver a quantidade antes de filtrar.
            final baseForCounts = inRange.where((view) {
              if (_clientId != null && view.clientId != _clientId) {
                return false;
              }
              final query = _query.trim().toLowerCase();
              if (query.isEmpty) return true;
              final normalizedAmount = query
                  .replaceAll('.', '')
                  .replaceAll(',', '.');
              return view.clientName.toLowerCase().contains(query) ||
                  view.description.toLowerCase().contains(query) ||
                  (view.serviceName?.toLowerCase().contains(query) ?? false) ||
                  brl(view.amount).toLowerCase().contains(query) ||
                  view.amount.toStringAsFixed(2).contains(normalizedAmount);
            }).toList();
            final statusCounts = <ChargeStatus, int>{};
            for (final view in baseForCounts) {
              statusCounts.update(
                view.status,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
            final totalCount = baseForCounts.length + pending.length;

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
                .where((p) => _range == null || _range!.contains(p.paidAt))
                .fold<double>(0, (sum, p) => sum + p.amount);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _selected.isEmpty
                      ? ScreenHeader(
                          title: 'Cobranças',
                          description:
                              'Acompanhe, cobre e receba em um só lugar.',
                          leading: const BrandBadge(),
                          action: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlanGatedIconButton(
                                tooltip: 'Configurar Asaas',
                                icon: Icons.account_balance_outlined,
                                allowed: workspace.canUseAsaas,
                                feature: 'Integração Asaas',
                                onPressed: () => showAsaasConfigSheet(context),
                              ),
                              PlanGatedIconButton(
                                tooltip: 'Notificações do cliente',
                                icon: Icons.notifications_active_outlined,
                                allowed: workspace.canUseWhatsapp,
                                feature: 'Notificações por WhatsApp',
                                onPressed: () =>
                                    showNotificationPreferencesSheet(context),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_selected.length} selecionada(s)',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Selecionar todas',
                              icon: const Icon(Icons.done_all),
                              onPressed: () => _selectAll(views),
                            ),
                            IconButton(
                              tooltip: 'Limpar seleção',
                              icon: const Icon(Icons.close),
                              onPressed: _clearSelection,
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: PeriodBar(
                    range: _range,
                    onChanged: (value) => setState(() => _range = value),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MetricStrip(
                    items: [
                      MetricItem(
                        label: 'Em aberto',
                        value: brl(openTotal),
                        tone: AppColors.info,
                        icon: Icons.schedule_outlined,
                        hint: '${views.length} cobranças',
                      ),
                      MetricItem(
                        label: 'Atrasado',
                        value: brl(overdueTotal),
                        tone: AppColors.danger,
                        icon: Icons.warning_amber_outlined,
                      ),
                      MetricItem(
                        label: 'Recebido',
                        value: brl(receivedTotal),
                        tone: AppColors.success,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            hintText: 'Buscar cobranças',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        active: _hasFilters,
                        expanded: _showFilters,
                        onTap: () =>
                            setState(() => _showFilters = !_showFilters),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _showFilters
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterPill(
                                label: 'Todas',
                                selected: _status == null,
                                count: totalCount,
                                icon: Icons.all_inclusive,
                                onTap: () => setState(() => _status = null),
                              ),
                              for (final status in [
                                ChargeStatus.pendente,
                                ChargeStatus.atrasado,
                                ChargeStatus.pago,
                                ChargeStatus.cancelado,
                              ])
                                FilterPill(
                                  label: status.label,
                                  selected: _status == status,
                                  tone: StatusBadge.styleFor(status).$1,
                                  icon: StatusBadge.styleFor(status).$2,
                                  count:
                                      (statusCounts[status] ?? 0) +
                                      (status == ChargeStatus.pendente
                                          ? pending.length
                                          : 0),
                                  onTap: () => setState(() => _status = status),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilterCombobox<String?>(
                          options: [
                            const FilterOption<String?>(
                              value: null,
                              label: 'Todos os clientes',
                            ),
                            for (final client in workspace.clients)
                              FilterOption<String?>(
                                value: client.id,
                                label: client.name,
                              ),
                          ],
                          value: _clientId,
                          hint: 'Todos os clientes',
                          allLabel: 'Todos os clientes',
                          icon: Icons.person_outline,
                          onChanged: (value) =>
                              setState(() => _clientId = value),
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox(width: double.infinity),
                ),
                if (pending.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.autorenew,
                            size: 18,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${pending.length} recorrência(s) ainda não gerada(s).',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.foreground),
                            ),
                          ),
                          TextButton(
                            onPressed: _generating
                                ? null
                                : () => _generate(pending),
                            child: Text(
                              _generating ? 'Gerando…' : 'Gerar todas',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: views.isEmpty && pending.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Nenhuma cobrança encontrada',
                          description: 'Ajuste os filtros ou cadastre uma nova cobrança.',
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(workspaceProvider);
                            try {
                              await ref.read(workspaceProvider.future);
                            } catch (_) {}
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            children: [
                              for (final occurrence in pending) ...[
                                _PendingCard(
                                  occurrence: occurrence,
                                  onGenerate: () => _generate([occurrence]),
                                ),
                                const SizedBox(height: 10),
                              ],
                              for (final view in views) ...[
                                ChargeCard(
                                  view: view,
                                  selectionMode: _selected.isNotEmpty,
                                  selected: _selected.contains(view.charge.id),
                                  onToggle: () => _toggleSelect(view.charge.id),
                                  onLongPress: () =>
                                      _toggleSelect(view.charge.id),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                ),
                if (_selected.isNotEmpty)
                  _BulkBar(
                    count: _selected.length,
                    busy: _bulkBusy,
                    onEmit: () => _bulkEmit(views),
                    onDelete: _bulkDelete,
                    onClear: _clearSelection,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || expanded;
    return Tooltip(
      message: 'Filtros',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Icon(
            Icons.tune,
            size: 20,
            color: highlighted ? AppColors.primary : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.busy,
    required this.onEmit,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final bool busy;
  final VoidCallback onEmit;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count selecionada(s)',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : onEmit,
              icon: const Icon(Icons.receipt_outlined, size: 18),
              label: const Text('Asaas'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.danger,
              ),
              label: const Text('Excluir'),
            ),
            IconButton(
              tooltip: 'Fechar seleção',
              onPressed: busy ? null : onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.occurrence, required this.onGenerate});

  final PendingOccurrence occurrence;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.info),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              occurrence.clientName,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            brl(occurrence.amount),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        occurrence.description,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const StatusPill(
                            label: 'Não gerada',
                            tone: AppColors.mutedForeground,
                            icon: Icons.autorenew,
                            compact: true,
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Vence ${formatDate(occurrence.dueDate)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          TextButton(
                            onPressed: onGenerate,
                            child: const Text('Gerar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
