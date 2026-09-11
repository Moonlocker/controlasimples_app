import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../models/asaas.dart';
import '../../models/charge.dart';
import '../../repositories/asaas_repository.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../repositories/whatsapp_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';
import 'charge_form_sheet.dart';
import 'payment_files_sheet.dart';
import 'payment_form_sheet.dart';

Future<T> _withProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 14),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  try {
    return await action();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}

class ChargeCard extends StatelessWidget {
  const ChargeCard({
    super.key,
    required this.view,
    this.showClient = true,
    this.selectionMode = false,
    this.selected = false,
    this.onToggle,
    this.onLongPress,
  });

  final ChargeView view;
  final bool showClient;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: selectionMode ? onToggle : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectionMode) ...[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle?.call(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    showClient
                        ? view.clientName
                        : (view.charge.recurringId != null
                            ? '${view.description} · recorrente'
                            : view.description),
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  brl(view.amount),
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (!selectionMode) ChargeActionsButton(charge: view.charge),
              ],
            ),
            if (showClient) ...[
              const SizedBox(height: 3),
              Text(
                view.charge.recurringId != null
                    ? '${view.description} · recorrente'
                    : view.description,
                style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  'Vence ${formatDate(view.dueDate)}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                ),
                if (view.charge.asaasPaymentId != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.receipt_outlined, size: 14, color: AppColors.info),
                ],
                const Spacer(),
                StatusBadge(status: view.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChargeActionsButton extends ConsumerWidget {
  const ChargeActionsButton({super.key, required this.charge});

  final Charge charge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen =
        charge.status == ChargeStatus.pendente || charge.status == ChargeStatus.atrasado;
    final isPaid = charge.status == ChargeStatus.pago;
    final emitted = charge.asaasPaymentId != null;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.mutedForeground),
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (context) => [
        if (isOpen && !emitted)
          const PopupMenuItem(value: 'emit', child: Text('Emitir no Asaas')),
        if (emitted)
          const PopupMenuItem(value: 'files', child: Text('Ver pagamento (Pix/boleto)')),
        if (emitted && isOpen)
          const PopupMenuItem(value: 'sync', child: Text('Atualizar status no Asaas')),
        if (isOpen)
          const PopupMenuItem(value: 'whatsapp', child: Text('Enviar WhatsApp')),
        if (isOpen) const PopupMenuDivider(),
        if (isOpen)
          const PopupMenuItem(value: 'pay', child: Text('Registrar recebimento')),
        if (isOpen) const PopupMenuItem(value: 'edit', child: Text('Editar')),
        if (isPaid) const PopupMenuItem(value: 'reopen', child: Text('Reabrir cobrança')),
        if (isOpen) const PopupMenuItem(value: 'cancel', child: Text('Cancelar cobrança')),
        const PopupMenuItem(value: 'delete', child: Text('Excluir')),
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    final repository = ref.read(chargesRepositoryProvider);
    try {
      switch (action) {
        case 'emit':
          final billingType = await _pickBillingType(context);
          if (billingType == null || !context.mounted) return;
          final files = await _withProgress(
            context,
            'Emitindo cobrança…',
            () => ref.read(asaasRepositoryProvider).emit(charge.id, billingType),
          );
          ref.invalidate(workspaceProvider);
          if (context.mounted) {
            await showPaymentFilesSheet(context, files, description: charge.description);
          }
        case 'files':
          final files = await _withProgress(
            context,
            'Carregando…',
            () => ref.read(asaasRepositoryProvider).files(charge.id),
          );
          if (context.mounted) {
            await showPaymentFilesSheet(context, files, description: charge.description);
          }
        case 'sync':
          final status = await _withProgress(
            context,
            'Atualizando…',
            () => ref.read(asaasRepositoryProvider).sync(charge.id),
          );
          ref.invalidate(workspaceProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Status no Asaas: $status')),
            );
          }
        case 'whatsapp':
          final confirmed = await showConfirmDialog(
            context,
            title: 'Enviar WhatsApp',
            message: 'Enviar o aviso de cobrança para o cliente?',
            confirmLabel: 'Enviar',
          );
          if (!confirmed || !context.mounted) return;
          await _withProgress(
            context,
            'Enviando…',
            () => ref.read(whatsappRepositoryProvider).sendCharge(charge.id),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mensagem enviada.')),
            );
          }
        case 'pay':
          await showPaymentForm(context, charge: charge);
        case 'edit':
          await showChargeForm(context, charge: charge);
        case 'reopen':
          final confirmed = await showConfirmDialog(
            context,
            title: 'Reabrir cobrança',
            message: 'O pagamento registrado será removido e a cobrança voltará a ficar pendente.',
            confirmLabel: 'Reabrir',
          );
          if (!confirmed) return;
          await repository.reopen(charge.id);
          ref.invalidate(workspaceProvider);
        case 'cancel':
          final confirmed = await showConfirmDialog(
            context,
            title: 'Cancelar cobrança',
            message: 'A cobrança será marcada como cancelada.',
            confirmLabel: 'Cancelar cobrança',
            destructive: true,
          );
          if (!confirmed) return;
          await repository.cancel(charge.id);
          ref.invalidate(workspaceProvider);
        case 'delete':
          final confirmed = await showConfirmDialog(
            context,
            title: 'Excluir cobrança',
            message: 'Esta ação não pode ser desfeita.',
            confirmLabel: 'Excluir',
            destructive: true,
          );
          if (!confirmed) return;
          await repository.delete(charge.id);
          ref.invalidate(workspaceProvider);
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<BillingType?> _pickBillingType(BuildContext context) {
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
}
