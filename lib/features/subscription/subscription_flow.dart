import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/error_messages.dart';
import '../../models/asaas.dart';
import '../../models/plan.dart';
import '../../repositories/subscription_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../charges/payment_files_sheet.dart';

/// Fluxo único de assinatura/troca de plano, reutilizado pelo onboarding e
/// pelas configurações. O plano gratuito é ativado pelo endpoint oficial de
/// assinatura (a escrita direta em `subscriptions` é bloqueada por gatilhos).
///
/// Retorna `true` quando a assinatura foi criada/ativada com sucesso.
Future<bool> subscribeToPlanFlow(
  BuildContext context,
  WidgetRef ref,
  Plan plan, {
  String? successMessage,
}) async {
  try {
    if (plan.price <= 0) {
      await ref
          .read(subscriptionRepositoryProvider)
          .subscribe(
            planId: plan.id,
            document:
                ref.read(workspaceProvider).value?.profile?.document ?? '',
          );
      ref.invalidate(workspaceProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage ?? 'Plano ${plan.name} ativado.'),
          ),
        );
      }
      return true;
    }

    final result =
        await showAppFormSheetResult<({String document, BillingType billing})>(
          context,
          SubscribePlanFormSheet(plan: plan),
        );
    if (result == null) return false;

    final response = await ref
        .read(subscriptionRepositoryProvider)
        .subscribe(
          planId: plan.id,
          document: result.document,
          billingType: result.billing,
        );
    ref.invalidate(workspaceProvider);
    if (!context.mounted) return true;

    final hasFiles =
        (response.pixPayload != null && response.pixPayload!.isNotEmpty) ||
        (response.pixQrCode != null && response.pixQrCode!.isNotEmpty) ||
        (response.bankSlipUrl != null && response.bankSlipUrl!.isNotEmpty);
    if (hasFiles) {
      await showPaymentFilesSheet(
        context,
        AsaasPaymentFiles(
          emitted: true,
          billingType: result.billing.wire,
          asaasStatus: response.status,
          invoiceUrl: response.invoiceUrl,
          bankSlipUrl: response.bankSlipUrl,
          pixPayload: response.pixPayload,
          pixQrCode: response.pixQrCode,
        ),
        title: 'Assinatura ${plan.name}',
      );
    } else if (response.invoiceUrl != null) {
      await launchUrl(Uri.parse(response.invoiceUrl!));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Assinatura atualizada.')));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
    return false;
  }
}

/// Formulário de assinatura de um plano pago (CPF/CNPJ + forma de pagamento).
class SubscribePlanFormSheet extends ConsumerStatefulWidget {
  const SubscribePlanFormSheet({super.key, required this.plan});

  final Plan plan;

  @override
  ConsumerState<SubscribePlanFormSheet> createState() =>
      _SubscribePlanFormSheetState();
}

class _SubscribePlanFormSheetState
    extends ConsumerState<SubscribePlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _document = TextEditingController();
  BillingType _billing = BillingType.pix;

  @override
  void initState() {
    super.initState();
    _document.text = ref.read(workspaceProvider).value?.profile?.document ?? '';
  }

  @override
  void dispose() {
    _document.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context)
        .pop((document: _document.text.trim(), billing: _billing));
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Assinar ${widget.plan.name}',
      subtitle: '${brl(widget.plan.price)} por mês.',
      formKey: _formKey,
      saveLabel: 'Continuar',
      onSave: () async => _submit(),
      children: [
        TextFormField(
          controller: _document,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'CPF/CNPJ do titular'),
          validator: (value) {
            final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.length != 11 && digits.length != 14) {
              return 'Informe um CPF ou CNPJ válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<BillingType>(
          initialValue: _billing,
          decoration: const InputDecoration(labelText: 'Forma de pagamento'),
          items: [
            for (final type in BillingType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
          ],
          onChanged: (value) => setState(() => _billing = value ?? _billing),
        ),
      ],
    );
  }
}
