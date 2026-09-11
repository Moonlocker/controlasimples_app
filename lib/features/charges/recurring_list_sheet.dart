import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/recurring_charge.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/confirm_dialog.dart';
import 'recurring_form_sheet.dart';

Future<void> showRecurringListSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _RecurringListSheet(),
  );
}

class _RecurringListSheet extends ConsumerWidget {
  const _RecurringListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider).value;
    final recurring = workspace?.recurring ?? const <RecurringCharge>[];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recorrências',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Mensalidades e cobranças automáticas.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: recurring.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma recorrência cadastrada.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: recurring.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = recurring[index];
                      return _RecurringTile(
                        item: item,
                        clientName: workspace?.clientName(item.clientId) ?? '—',
                        serviceName: workspace?.serviceName(item.serviceId),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: () => showRecurringForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova recorrência'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({
    required this.item,
    required this.clientName,
    this.serviceName,
  });

  final RecurringCharge item;
  final String clientName;
  final String? serviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
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
                  clientName,
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                brl(item.amount),
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.mutedForeground),
                onSelected: (value) async {
                  final repository = ref.read(chargesRepositoryProvider);
                  if (value == 'edit') {
                    await showRecurringForm(context, recurring: item);
                  } else if (value == 'toggle') {
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
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.active ? 'Pausar' : 'Reativar'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${item.description}${serviceName == null ? '' : ' · $serviceName'}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Tag(
                label: item.active ? 'Ativa' : 'Pausada',
                color: item.active ? AppColors.success : AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              _Tag(label: '${item.frequency.label} · dia ${item.dueDay}', color: AppColors.info),
              if (item.autoAsaas) ...[
                const SizedBox(width: 8),
                const _Tag(label: 'Asaas', color: AppColors.primary),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
