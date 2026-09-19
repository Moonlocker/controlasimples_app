import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/error_messages.dart';
import '../../models/asaas.dart';
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
  bool recurring = false,
}) {
  return showAppFormSheet(
    context,
    ChargeFormSheet(
      charge: charge,
      initialClientId: initialClientId,
      initialServiceId: initialServiceId,
      recurring: recurring,
    ),
  );
}

/// Formulário unificado de cobrança: cria uma cobrança única ou uma
/// recorrência a partir do mesmo modal (o usuário escolhe o tipo).
class ChargeFormSheet extends ConsumerStatefulWidget {
  const ChargeFormSheet({
    super.key,
    this.charge,
    this.initialClientId,
    this.initialServiceId,
    this.recurring = false,
  });

  final Charge? charge;
  final String? initialClientId;
  final String? initialServiceId;
  final bool recurring;

  @override
  ConsumerState<ChargeFormSheet> createState() => _ChargeFormSheetState();
}

class _ChargeFormSheetState extends ConsumerState<ChargeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _dueDay;

  String? _clientId;
  String? _serviceId;
  DateTime _dueDate = DateTime.now();

  // Campos de recorrência.
  bool _isRecurring = false;
  Recurrence _frequency = Recurrence.mensal;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _active = true;
  bool _autoAsaas = false;
  BillingType _billingType = BillingType.boleto;

  bool _busy = false;

  bool get _isNew => widget.charge == null;

  @override
  void initState() {
    super.initState();
    final charge = widget.charge;
    _description = TextEditingController(text: charge?.description ?? '');
    _amount = TextEditingController(
      text: CurrencyInputFormatter.fromDouble(charge?.amount ?? 0),
    );
    _dueDay = TextEditingController(text: '10');
    _clientId = charge?.clientId ?? widget.initialClientId;
    _serviceId = charge?.serviceId ?? widget.initialServiceId;
    _dueDate = charge?.dueDate ?? DateTime.now();
    _isRecurring = _isNew && widget.recurring;
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
      final repository = ref.read(chargesRepositoryProvider);
      if (_isRecurring) {
        await repository.saveRecurring(
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
      } else {
        await repository.save(
          id: widget.charge?.id,
          userId: userId,
          clientId: _clientId!,
          serviceId: _serviceId,
          description: _description.text.trim(),
          amount: CurrencyInputFormatter.parse(_amount.text),
          dueDate: _dueDate,
        );
      }
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
      title: _isNew
          ? (_isRecurring ? 'Nova recorrência' : 'Nova cobrança')
          : 'Editar cobrança',
      subtitle: _isNew ? 'Escolha se a cobrança é única ou recorrente.' : null,
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        if (_isNew) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                label: Text('Única'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.autorenew, size: 18),
                label: Text('Recorrente'),
              ),
            ],
            selected: {_isRecurring},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _isRecurring = value.first),
          ),
          const SizedBox(height: 16),
        ],
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
        if (_isRecurring)
          ..._recurringFields()
        else
          DateField(
            label: 'Vencimento',
            value: _dueDate,
            onChanged: (value) => setState(() => _dueDate = value ?? _dueDate),
          ),
      ],
    );
  }

  List<Widget> _recurringFields() {
    return [
      DropdownButtonFormField<Recurrence>(
        initialValue: _frequency,
        decoration: const InputDecoration(labelText: 'Frequência'),
        items: [
          for (final frequency in Recurrence.values)
            DropdownMenuItem(value: frequency, child: Text(frequency.label)),
        ],
        onChanged: (value) => setState(() => _frequency = value ?? _frequency),
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
        onChanged: (value) => setState(() => _startDate = value ?? _startDate),
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
        subtitle: const Text('Executado pelo sistema quando configurado.'),
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
    ];
  }
}
