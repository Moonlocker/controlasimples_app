import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../models/asaas.dart';
import '../../models/recurring_charge.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/date_field.dart';
import '../../widgets/money_field.dart';
import '../auth/auth_providers.dart';

Future<void> showRecurringForm(
  BuildContext context, {
  RecurringCharge? recurring,
  String? initialClientId,
  String? initialServiceId,
}) {
  return showAppFormSheet(
    context,
    RecurringFormSheet(
      recurring: recurring,
      initialClientId: initialClientId,
      initialServiceId: initialServiceId,
    ),
  );
}

class RecurringFormSheet extends ConsumerStatefulWidget {
  const RecurringFormSheet({
    super.key,
    this.recurring,
    this.initialClientId,
    this.initialServiceId,
  });

  final RecurringCharge? recurring;
  final String? initialClientId;
  final String? initialServiceId;

  @override
  ConsumerState<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _dueDay;

  String? _clientId;
  String? _serviceId;
  Recurrence _frequency = Recurrence.mensal;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _active = true;
  bool _autoAsaas = false;
  BillingType _billingType = BillingType.boleto;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final recurring = widget.recurring;
    _description = TextEditingController(text: recurring?.description ?? '');
    _amount = TextEditingController(
      text: CurrencyInputFormatter.fromDouble(recurring?.amount ?? 0),
    );
    _dueDay = TextEditingController(text: (recurring?.dueDay ?? 10).toString());
    _clientId = recurring?.clientId ?? widget.initialClientId;
    _serviceId = recurring?.serviceId ?? widget.initialServiceId;
    _frequency = recurring?.frequency ?? Recurrence.mensal;
    _startDate = recurring?.startDate ?? DateTime.now();
    _endDate = recurring?.endDate;
    _active = recurring?.active ?? true;
    _autoAsaas = recurring?.autoAsaas ?? false;
    _billingType = BillingType.values.firstWhere(
      (type) => type.wire == recurring?.asaasBillingType,
      orElse: () => BillingType.boleto,
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _dueDay.dispose();
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
          .saveRecurring(
            id: widget.recurring?.id,
            userId: userId,
            clientId: _clientId!,
            serviceId: _serviceId,
            description: _description.text.trim(),
            amount: CurrencyInputFormatter.parse(_amount.text),
            frequency: _frequency,
            dueDay: int.tryParse(_dueDay.text) ?? 10,
            startDate: _startDate,
            endDate: _endDate,
            active: _active,
            autoAsaas: _autoAsaas,
            asaasBillingType: _billingType.wire,
          );
      ref.invalidate(workspaceProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
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
      title: widget.recurring == null
          ? 'Nova recorrência'
          : 'Editar recorrência',
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
        DropdownButtonFormField<Recurrence>(
          initialValue: _frequency,
          decoration: const InputDecoration(labelText: 'Frequência'),
          items: [
            for (final frequency in Recurrence.values)
              DropdownMenuItem(value: frequency, child: Text(frequency.label)),
          ],
          onChanged: (value) =>
              setState(() => _frequency = value ?? _frequency),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _dueDay,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Dia do vencimento (1 a 28)',
          ),
          validator: (value) {
            final day = int.tryParse(value ?? '');
            if (day == null || day < 1 || day > 28) {
              return 'Informe um dia entre 1 e 28';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        DateField(
          label: 'Início',
          value: _startDate,
          onChanged: (value) =>
              setState(() => _startDate = value ?? _startDate),
        ),
        const SizedBox(height: 14),
        DateField(
          label: 'Fim (opcional)',
          value: _endDate,
          clearable: true,
          onChanged: (value) => setState(() => _endDate = value),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (value) => setState(() => _active = value),
          title: const Text('Recorrência ativa'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _autoAsaas,
          onChanged: (value) => setState(() => _autoAsaas = value),
          title: const Text('Emitir no Asaas automaticamente'),
          subtitle: const Text(
            'Executado pelo sistema web quando configurado.',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<BillingType>(
          initialValue: _billingType,
          decoration: const InputDecoration(
            labelText: 'Forma de pagamento no Asaas',
          ),
          items: [
            for (final type in BillingType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
          ],
          onChanged: (value) =>
              setState(() => _billingType = value ?? _billingType),
        ),
      ],
    );
  }
}
