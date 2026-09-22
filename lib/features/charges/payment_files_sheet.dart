import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/payment_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/asaas.dart';
import '../../repositories/payments_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';

Future<void> showPaymentFilesSheet(
  BuildContext context,
  AsaasPaymentFiles files, {
  String? chargeId,
  String? description,
  String? clientName,
  double? amount,
  DateTime? dueDate,
  String title = 'Pagamento da cobrança',
}) {
  return showAppFormSheet(
    context,
    _PaymentFilesSheet(
      files: files,
      chargeId: chargeId,
      description: description,
      clientName: clientName,
      amount: amount,
      dueDate: dueDate,
      title: title,
    ),
  );
}

const Map<String, (String, Color)> _statusView = {
  'PENDING': ('Aguardando pagamento', AppColors.warning),
  'RECEIVED': ('Pago', AppColors.success),
  'CONFIRMED': ('Pago', AppColors.success),
  'OVERDUE': ('Vencido', AppColors.danger),
  'CANCELLED': ('Cancelado', AppColors.mutedForeground),
};

const Map<String, String> _billingLabels = {
  'BOLETO': 'Boleto',
  'PIX': 'Pix',
  'CREDIT_CARD': 'Cartão de crédito',
  'UNDEFINED': 'Cliente escolhe',
};

class _PaymentFilesSheet extends ConsumerStatefulWidget {
  const _PaymentFilesSheet({
    required this.files,
    this.chargeId,
    this.description,
    this.clientName,
    this.amount,
    this.dueDate,
    required this.title,
  });

  final AsaasPaymentFiles files;
  final String? chargeId;
  final String? description;
  final String? clientName;
  final double? amount;
  final DateTime? dueDate;
  final String title;

  @override
  ConsumerState<_PaymentFilesSheet> createState() => _PaymentFilesSheetState();
}

class _PaymentFilesSheetState extends ConsumerState<_PaymentFilesSheet> {
  late AsaasPaymentFiles _files;
  bool _busy = false;

  bool get _canManage => widget.chargeId != null;

  @override
  void initState() {
    super.initState();
    _files = widget.files;
  }

  /// O gateway pode devolver o QR como base64 puro, data URI ou URL; aceitamos
  /// os formatos para o QR Code sempre renderizar.
  static Uint8List? _decodeQr(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var value = raw.trim();
    if (value.startsWith('http')) return null;
    final comma = value.indexOf(',');
    if (value.startsWith('data:') && comma != -1) {
      value = value.substring(comma + 1);
    }
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  static String? _qrUrl(String? raw) {
    final value = raw?.trim() ?? '';
    return value.startsWith('http') ? value : null;
  }

  Future<BillingType?> _pickBillingType(String gateway) {
    return showDialog<BillingType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Forma de pagamento · $gateway'),
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

  Future<void> _emit() async {
    final chargeId = widget.chargeId;
    if (chargeId == null) return;
    final gateway = _activeGatewayLabel();
    final billingType = await _pickBillingType(gateway);
    if (billingType == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final files = await ref
          .read(paymentsRepositoryProvider)
          .emit(chargeId, billingType);
      ref.invalidate(workspaceProvider);
      if (mounted) setState(() => _files = files);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelAtGateway() async {
    final chargeId = widget.chargeId;
    if (chargeId == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar cobrança no gateway?',
      message: 'A cobrança emitida será cancelada e você poderá gerar uma nova, inclusive com outra forma de pagamento.',
      confirmLabel: 'Cancelar no gateway',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(paymentsRepositoryProvider).resetEmission(chargeId);
      final files = await ref.read(paymentsRepositoryProvider).files(chargeId);
      ref.invalidate(workspaceProvider);
      if (mounted) setState(() => _files = files);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _activeGatewayLabel() {
    final active = ref.read(paymentProvidersProvider).value?.activeProvider;
    return paymentProviderLabel(active);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final files = _files;
    final qrBytes = _decodeQr(files.pixQrCode);
    final qrUrl = _qrUrl(files.pixQrCode);
    final hasQr = qrBytes != null || qrUrl != null;
    final hasPixCode = files.pixPayload != null && files.pixPayload!.isNotEmpty;
    final hasLink = files.invoiceUrl != null && files.invoiceUrl!.isNotEmpty;
    final hasBoleto =
        files.bankSlipUrl != null && files.bankSlipUrl!.isNotEmpty;
    final status = _statusView[files.asaasStatus ?? ''];

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
                        widget.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.description ??
                            'Envie o link, o boleto ou o QR Code ao cliente.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.clientName != null ||
                      widget.amount != null ||
                      widget.dueDate != null ||
                      status != null)
                    _SummaryCard(
                      clientName: widget.clientName,
                      amount: widget.amount,
                      dueDate: widget.dueDate,
                      status: status,
                      billingType: files.billingType,
                    ),
                  if (!files.emitted) ...[
                    const SizedBox(height: 16),
                    _EmptyEmission(
                      busy: _busy,
                      canManage: _canManage,
                      gateway: _activeGatewayLabel(),
                      onEmit: _emit,
                    ),
                  ] else ...[
                    if (hasQr) ...[
                      const SizedBox(height: 16),
                      _SectionTitle(
                        icon: Icons.qr_code_2,
                        label: 'Pix — pagamento na hora',
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: qrBytes != null
                              ? Image.memory(
                                  qrBytes,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                )
                              : Image.network(
                                  qrUrl!,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Escaneie o QR Code ou use o código copia-e-cola em qualquer banco.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                    if (hasPixCode) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: files.pixPayload!),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código Pix copiado.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar código Pix'),
                      ),
                    ],
                    if (hasLink) ...[
                      const SizedBox(height: 16),
                      _LinkTile(
                        icon: Icons.link,
                        title: 'Link de pagamento',
                        subtitle: 'Envie ao cliente para pagar online.',
                        actionLabel: 'Abrir',
                        onOpen: () => launchUrl(Uri.parse(files.invoiceUrl!)),
                      ),
                    ],
                    if (hasBoleto) ...[
                      const SizedBox(height: 10),
                      _LinkTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Boleto bancário (PDF)',
                        subtitle: 'Abra ou compartilhe o boleto.',
                        actionLabel: 'Abrir',
                        onOpen: () => launchUrl(Uri.parse(files.bankSlipUrl!)),
                      ),
                    ],
                    if (!hasQr && !hasPixCode && !hasLink && !hasBoleto) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Nenhum arquivo de pagamento disponível ainda. '
                        'Se você acabou de gerar a cobrança, aguarde alguns instantes e tente novamente.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                    if (_canManage) ...[
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Text(
                        'Precisa trocar a forma de pagamento? Cancele no gateway e emita de novo.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _cancelAtGateway,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                              ),
                              icon: const Icon(Icons.block, size: 18),
                              label: const Text('Cancelar no gateway'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _emit,
                              icon: const Icon(Icons.bolt, size: 18),
                              label: const Text('Emitir novamente'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEmission extends StatelessWidget {
  const _EmptyEmission({
    required this.busy,
    required this.canManage,
    required this.gateway,
    required this.onEmit,
  });

  final bool busy;
  final bool canManage;
  final String gateway;
  final VoidCallback onEmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Esta cobrança ainda não foi emitida no gateway.',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha a forma de pagamento para gerar o Pix, boleto ou link no $gateway.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || !canManage ? null : onEmit,
            icon: const Icon(Icons.bolt, size: 18),
            label: Text(busy ? 'Emitindo…' : 'Emitir cobrança'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    this.clientName,
    this.amount,
    this.dueDate,
    this.status,
    this.billingType,
  });

  final String? clientName;
  final double? amount;
  final DateTime? dueDate;
  final (String, Color)? status;
  final String? billingType;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (clientName != null)
                      Text(
                        clientName!,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (dueDate != null)
                      Text(
                        'Vence em ${formatDate(dueDate!)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              if (amount != null)
                Text(
                  brl(amount!),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (status != null || billingType != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != null)
                  StatusPill(
                    label: status!.$1,
                    tone: status!.$2,
                    compact: true,
                  ),
                if (billingType != null && _billingLabels[billingType] != null)
                  StatusPill(
                    label: _billingLabels[billingType]!,
                    tone: AppColors.info,
                    compact: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.success),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
