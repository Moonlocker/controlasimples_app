import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/asaas.dart';
import '../../widgets/app_form_sheet.dart';

Future<void> showPaymentFilesSheet(
  BuildContext context,
  AsaasPaymentFiles files, {
  String? description,
  String title = 'Pagamento da cobrança',
}) {
  return showAppFormSheet(
    context,
    _PaymentFilesSheet(files: files, description: description, title: title),
  );
}

class _PaymentFilesSheet extends StatelessWidget {
  const _PaymentFilesSheet({
    required this.files,
    this.description,
    required this.title,
  });

  final AsaasPaymentFiles files;
  final String? description;
  final String title;

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final qrBytes = _decodeQr(files.pixQrCode);
    final qrUrl = _qrUrl(files.pixQrCode);
    final hasQr = qrBytes != null || qrUrl != null;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
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
                        title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description != null)
                        Text(
                          description!,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (hasQr) ...[
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
                  const SizedBox(height: 16),
                ],
                if (files.pixPayload != null && files.pixPayload!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: files.pixPayload!),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código PIX copiado.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar código PIX'),
                  ),
                if (files.invoiceUrl != null &&
                    files.invoiceUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(files.invoiceUrl!)),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir link de pagamento'),
                  ),
                ],
                if (files.bankSlipUrl != null &&
                    files.bankSlipUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(files.bankSlipUrl!)),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Abrir boleto (PDF)'),
                  ),
                ],
                if (files.asaasStatus != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Status: ${files.asaasStatus}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
