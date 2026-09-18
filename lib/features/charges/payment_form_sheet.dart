import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../models/charge.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/date_field.dart';
import '../../widgets/money_field.dart';
import '../auth/auth_providers.dart';

Future<void> showPaymentForm(BuildContext context, {required Charge charge}) {
  return showAppFormSheet(context, PaymentFormSheet(charge: charge));
}

class PaymentFormSheet extends ConsumerStatefulWidget {
  const PaymentFormSheet({super.key, required this.charge});

  final Charge charge;

  @override
  ConsumerState<PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends ConsumerState<PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  DateTime _paidAt = DateTime.now();
  PaymentMethod _method = PaymentMethod.pix;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: CurrencyInputFormatter.fromDouble(widget.charge.amount),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(chargesRepositoryProvider)
          .registerPayment(
            userId: userId,
            chargeId: widget.charge.id,
            amount: CurrencyInputFormatter.parse(_amount.text),
            paidAt: _paidAt,
            method: _method,
            receivedAt: DateTime.now(),
          );
      ref.invalidate(workspaceProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível registrar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Registrar recebimento',
      subtitle: widget.charge.description,
      formKey: _formKey,
      busy: _busy,
      saveLabel: 'Confirmar recebimento',
      onSave: _save,
      children: [
        MoneyField(controller: _amount),
        const SizedBox(height: 14),
        DateField(
          label: 'Data do recebimento',
          value: _paidAt,
          onChanged: (value) => setState(() => _paidAt = value ?? _paidAt),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<PaymentMethod>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Forma de pagamento'),
          items: [
            for (final method in PaymentMethod.values)
              DropdownMenuItem(value: method, child: Text(method.label)),
          ],
          onChanged: (value) => setState(() => _method = value ?? _method),
        ),
      ],
    );
  }
}
