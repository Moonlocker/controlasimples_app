import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../models/charge.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/date_field.dart';
import '../../widgets/money_field.dart';
import '../auth/auth_providers.dart';

Future<void> showChargeForm(
  BuildContext context, {
  Charge? charge,
  String? initialClientId,
  String? initialServiceId,
}) {
  return showAppFormSheet(
    context,
    ChargeFormSheet(
      charge: charge,
      initialClientId: initialClientId,
      initialServiceId: initialServiceId,
    ),
  );
}

class ChargeFormSheet extends ConsumerStatefulWidget {
  const ChargeFormSheet({
    super.key,
    this.charge,
    this.initialClientId,
    this.initialServiceId,
  });

  final Charge? charge;
  final String? initialClientId;
  final String? initialServiceId;

  @override
  ConsumerState<ChargeFormSheet> createState() => _ChargeFormSheetState();
}

class _ChargeFormSheetState extends ConsumerState<ChargeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;

  String? _clientId;
  String? _serviceId;
  DateTime _dueDate = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final charge = widget.charge;
    _description = TextEditingController(text: charge?.description ?? '');
    _amount = TextEditingController(
      text: CurrencyInputFormatter.fromDouble(charge?.amount ?? 0),
    );
    _clientId = charge?.clientId ?? widget.initialClientId;
    _serviceId = charge?.serviceId ?? widget.initialServiceId;
    _dueDate = charge?.dueDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _clientId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(chargesRepositoryProvider)
          .save(
            id: widget.charge?.id,
            userId: userId,
            clientId: _clientId!,
            serviceId: _serviceId,
            description: _description.text.trim(),
            amount: CurrencyInputFormatter.parse(_amount.text),
            dueDate: _dueDate,
          );
      ref.invalidate(workspaceProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar. ${friendlyError(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider).value;
    final clients = workspace?.clients ?? const [];
    final services = (workspace?.services ?? const [])
        .where((service) => _clientId == null || service.clientId == _clientId)
        .toList();

    return AppFormSheet(
      title: widget.charge == null ? 'Nova cobrança' : 'Editar cobrança',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _clientId,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: [
            for (final client in clients)
              DropdownMenuItem(value: client.id, child: Text(client.name)),
          ],
          onChanged: (value) => setState(() {
            _clientId = value;
            _serviceId = null;
          }),
          validator: (value) => value == null ? 'Selecione o cliente' : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: _serviceId,
          decoration: const InputDecoration(labelText: 'Serviço (opcional)'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Sem serviço vinculado'),
            ),
            for (final service in services)
              DropdownMenuItem(value: service.id, child: Text(service.name)),
          ],
          onChanged: (value) => setState(() => _serviceId = value),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _description,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Descrição'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Informe a descrição'
              : null,
        ),
        const SizedBox(height: 14),
        MoneyField(controller: _amount),
        const SizedBox(height: 14),
        DateField(
          label: 'Vencimento',
          value: _dueDate,
          onChanged: (value) => setState(() => _dueDate = value ?? _dueDate),
        ),
      ],
    );
  }
}
