import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/error_messages.dart';
import '../../models/asaas.dart';
import '../../models/charge.dart';
import '../../core/constants/payment_providers.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/payments_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/payment_provider_logo.dart';
import '../../widgets/plan_access.dart';
import '../../widgets/status_badge.dart';
import 'charge_config_sheets.dart';
import 'charge_form_sheet.dart';
import 'charge_notifications_sheet.dart';
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
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(friendlyError(error))));
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(
    this.label, {
    required this.locked,
    this.icon,
    this.tone,
    this.leading,
  });

  final String label;
  final bool locked;
  final IconData? icon;
  final Color? tone;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.foreground;
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(label, style: TextStyle(color: color)),
        ),
        if (locked) ...[
          const SizedBox(width: 8),
          const PlanLockBadge(size: 12),
        ],
      ],
    );
  }
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

  Color get _accent => switch (view.status) {
    ChargeStatus.pago => AppColors.success,
    ChargeStatus.pendente => AppColors.info,
    ChargeStatus.atrasado => AppColors.danger,
    ChargeStatus.cancelado => AppColors.mutedForeground,
  };

  (String, Color) _dueInfo() {
    final days = daysBetween(today(), view.dueDate);
    switch (view.status) {
      case ChargeStatus.atrasado:
        final late = -days;
        return (
          late <= 1 ? 'Atrasado há 1 dia' : 'Atrasado há $late dias',
          AppColors.danger,
        );
      case ChargeStatus.pendente:
        if (days == 0) return ('Vence hoje', AppColors.warning);
        if (days == 1) return ('Vence amanhã', AppColors.warning);
        return ('Vence ${formatDate(view.dueDate)}', AppColors.mutedForeground);
      case ChargeStatus.pago:
        return (
          'Venceu ${formatDate(view.dueDate)}',
          AppColors.mutedForeground,
        );
      case ChargeStatus.cancelado:
        return (
          'Vencia ${formatDate(view.dueDate)}',
          AppColors.mutedForeground,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = showClient
        ? view.clientName
        : (view.charge.recurringId != null
              ? '${view.description} · recorrente'
              : view.description);
    final isRecurring = view.charge.recurringId != null;
    final emitted = view.charge.providerPaymentId != null;
    final gateway = paymentProviderLabel(view.charge.provider);
    final (dueText, dueColor) = _dueInfo();

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: selectionMode ? onToggle : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selectionMode) ...[
                              Checkbox(
                                value: selected,
                                onChanged: (_) => onToggle?.call(),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              brl(view.amount),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!selectionMode)
                              ChargeActionsButton(
                                charge: view.charge,
                                clientName: view.clientName,
                              ),
                          ],
                        ),
                        if (showClient) ...[
                          const SizedBox(height: 2),
                          Text(
                            view.description,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (isRecurring || emitted) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (isRecurring)
                                const StatusPill(
                                  label: 'Recorrente',
                                  tone: AppColors.primary,
                                  icon: Icons.autorenew,
                                  compact: true,
                                ),
                              if (emitted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PaymentProviderLogo(
                                        provider: view.charge.provider,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        gateway,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.info,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            StatusBadge(status: view.status, compact: true),
                            const Spacer(),
                            Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: dueColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueText,
                              style: textTheme.bodySmall?.copyWith(
                                color: dueColor,
                                fontWeight:
                                    dueColor == AppColors.mutedForeground
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
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
      ),
    );
  }
}

class ChargeActionsButton extends ConsumerWidget {
  const ChargeActionsButton({super.key, required this.charge, this.clientName});

  final Charge charge;
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen =
        charge.status == ChargeStatus.pendente ||
        charge.status == ChargeStatus.atrasado;
    final isPaid = charge.status == ChargeStatus.pago;
    final emitted = charge.providerPaymentId != null;
    final workspace = ref.watch(workspaceProvider).value;
    final canUseAsaas = workspace?.canUseAsaas ?? true;
    final canUseWhatsapp = workspace?.canUseWhatsapp ?? true;
    final activeProvider = ref
        .watch(paymentProvidersProvider)
        .value
        ?.activeProvider;
    final gateway = paymentProviderLabel(activeProvider);

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: AppColors.mutedForeground,
      ),
      tooltip: 'Ações da cobrança',
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (context) => [
        if (isOpen && !emitted)
          PopupMenuItem(
            value: 'emit',
            child: _MenuLabel(
              activeProvider == null
                  ? 'Gerar cobrança'
                  : 'Gerar cobrança no $gateway',
              icon: Icons.bolt_outlined,
              leading: activeProvider == null
                  ? null
                  : PaymentProviderLogo(provider: activeProvider, size: 18),
              locked: !canUseAsaas,
            ),
          ),
        if (emitted)
          PopupMenuItem(
            value: 'files',
            child: _MenuLabel(
              'Ver Pix/boleto',
              icon: Icons.qr_code_2_outlined,
              locked: !canUseAsaas,
            ),
          ),
        if (emitted && isOpen)
          PopupMenuItem(
            value: 'sync',
            child: _MenuLabel(
              'Atualizar status',
              icon: Icons.sync,
              locked: !canUseAsaas,
            ),
          ),
        if (isOpen)
          PopupMenuItem(
            value: 'whatsapp',
            child: _MenuLabel(
              'Notificações no WhatsApp',
              icon: Icons.chat_outlined,
              locked: !canUseWhatsapp,
            ),
          ),
        if (isOpen || emitted) const PopupMenuDivider(),
        if (isOpen)
          const PopupMenuItem(
            value: 'pay',
            child: _MenuLabel(
              'Registrar recebimento',
              icon: Icons.check_circle_outline,
              locked: false,
            ),
          ),
        if (isOpen)
          const PopupMenuItem(
            value: 'edit',
            child: _MenuLabel(
              'Editar',
              icon: Icons.edit_outlined,
              locked: false,
            ),
          ),
        if (isPaid)
          const PopupMenuItem(
            value: 'reopen',
            child: _MenuLabel(
              'Reabrir cobrança',
              icon: Icons.undo,
              locked: false,
            ),
          ),
        const PopupMenuDivider(),
        if (isOpen)
          PopupMenuItem(
            value: 'cancel',
            child: _MenuLabel(
              'Cancelar cobrança',
              icon: Icons.block,
              locked: false,
              tone: AppColors.danger,
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: _MenuLabel(
            'Excluir',
            icon: Icons.delete_outline,
            locked: false,
            tone: AppColors.danger,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final workspace = ref.read(workspaceProvider).value;
    if ((action == 'emit' || action == 'files' || action == 'sync') &&
        workspace?.canUseAsaas == false) {
      if (context.mounted) {
        await showPlanLockedDialog(
          context,
          feature: 'Integração de pagamentos',
        );
      }
      return;
    }
    if (action == 'whatsapp' && workspace?.canUseWhatsapp == false) {
      if (context.mounted) {
        await showPlanLockedDialog(
          context,
          feature: 'Notificações por WhatsApp',
        );
      }
      return;
    }
    final repository = ref.read(chargesRepositoryProvider);
    try {
      switch (action) {
        case 'emit':
          final activeProvider = ref
              .read(paymentProvidersProvider)
              .value
              ?.activeProvider;
          if (activeProvider == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Configure um meio de pagamento antes de gerar cobranças.',
                  ),
                ),
              );
              await showAsaasConfigSheet(context);
            }
            return;
          }
          final billingType = await _pickBillingType(ref, context);
          if (billingType == null || !context.mounted) return;
          final files = await _withProgress(
            context,
            'Emitindo cobrança…',
            () => ref
                .read(paymentsRepositoryProvider)
                .emit(charge.id, billingType),
          );
          ref.invalidate(workspaceProvider);
          if (context.mounted) {
            await showPaymentFilesSheet(
              context,
              files,
              chargeId: charge.id,
              description: charge.description,
              clientName: clientName,
              amount: charge.amount,
              dueDate: charge.dueDate,
            );
          }
        case 'files':
          final files = await _withProgress(
            context,
            'Carregando…',
            () => ref.read(paymentsRepositoryProvider).files(charge.id),
          );
          if (context.mounted) {
            await showPaymentFilesSheet(
              context,
              files,
              chargeId: charge.id,
              description: charge.description,
              clientName: clientName,
              amount: charge.amount,
              dueDate: charge.dueDate,
            );
          }
        case 'sync':
          final status = await _withProgress(
            context,
            'Atualizando…',
            () => ref.read(paymentsRepositoryProvider).sync(charge.id),
          );
          ref.invalidate(workspaceProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Status no gateway: $status')),
            );
          }
        case 'whatsapp':
          await showChargeNotificationsSheet(
            context,
            chargeId: charge.id,
            description: charge.description,
          );
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

  Future<BillingType?> _pickBillingType(WidgetRef ref, BuildContext context) {
    final active = ref.read(paymentProvidersProvider).value?.activeProvider;
    final gateway = paymentProviderLabel(active);
    return showDialog<BillingType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          active == null
              ? 'Forma de pagamento'
              : 'Forma de pagamento · $gateway',
        ),
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
