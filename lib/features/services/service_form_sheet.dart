import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../models/service.dart';
import '../../repositories/charges_repository.dart';
import '../../repositories/services_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/date_field.dart';
import '../../widgets/money_field.dart';
import '../auth/auth_providers.dart';

Future<void> showServiceForm(
  BuildContext context, {
  Service? service,
  Service? duplicateFrom,
  String? initialClientId,
}) {
  return showAppFormSheet(
    context,
    ServiceFormSheet(
      service: service,
      duplicateFrom: duplicateFrom,
      initialClientId: initialClientId,
    ),
  );
}

class ServiceFormSheet extends ConsumerStatefulWidget {
  const ServiceFormSheet({
    super.key,
    this.service,
    this.duplicateFrom,
    this.initialClientId,
  });

  final Service? service;
  final Service? duplicateFrom;
  final String? initialClientId;

  @override
  ConsumerState<ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends ConsumerState<ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _link;
  late final TextEditingController _amount;
  late final TextEditingController _recurringAmount;
  late final TextEditingController _dueDay;

  String? _clientId;
  ServiceStatus _status = ServiceStatus.negociacao;
  ServiceBilling _billing = ServiceBilling.unico;
  Recurrence _frequency = Recurrence.mensal;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _autoAsaas = false;
  String? _recurringId;
  bool _busy = false;

  Service? get _source => widget.service ?? widget.duplicateFrom;

  @override
  void initState() {
    super.initState();
    final source = _source;
    _name = TextEditingController(text: source?.name ?? '');
    _description = TextEditingController(text: source?.description ?? '');
    _link = TextEditingController(text: source?.link ?? '');
    _amount = TextEditingController(
      text: CurrencyInputFormatter.fromDouble(source?.amount ?? 0),
    );
    _recurringAmount = TextEditingController();
    _dueDay = TextEditingController(text: '10');
    _clientId = source?.clientId ?? widget.initialClientId;
    _status = source?.status ?? ServiceStatus.negociacao;
    _billing = source?.billingType ?? ServiceBilling.unico;
    _startDate = source?.startDate ?? DateTime.now();
    _endDate = source?.endDate;

    if (widget.service != null) {
      final workspace = ref.read(workspaceProvider).value;
      final existing = workspace?.recurring
          .where((item) => item.serviceId == widget.service!.id)
          .toList();
      if (existing != null && existing.isNotEmpty) {
        final recurring = existing.first;
        _recurringId = recurring.id;
        _recurringAmount.text = CurrencyInputFormatter.fromDouble(
          recurring.amount,
        );
        _dueDay.text = recurring.dueDay.toString();
        _frequency = recurring.frequency;
        _autoAsaas = recurring.autoAsaas;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _link.dispose();
    _amount.dispose();
    _recurringAmount.dispose();
    _dueDay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _clientId == null) return;
    setState(() => _busy = true);
    try {
      final isNew = widget.service == null;
      final oneTime = _billing == ServiceBilling.recorrente
          ? 0.0
          : CurrencyInputFormatter.parse(_amount.text);
      final recurringAmount = CurrencyInputFormatter.parse(
        _recurringAmount.text,
      );

      final serviceId = await ref
          .read(servicesRepositoryProvider)
          .save(
            id: widget.service?.id,
            userId: userId,
            clientId: _clientId!,
            name: _name.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            link: _link.text.trim().isEmpty ? null : _link.text.trim(),
            amount: oneTime,
            status: _status,
            billingType: _billing,
            startDate: _startDate,
            endDate: _endDate,
          );

      final chargesRepository = ref.read(chargesRepositoryProvider);
      if (_billing == ServiceBilling.unico) {
        await ref
            .read(servicesRepositoryProvider)
            .deactivateRecurring(serviceId);
      } else if (recurringAmount > 0) {
        await chargesRepository.saveRecurring(
          id: _recurringId,
          userId: userId,
          clientId: _clientId!,
          serviceId: serviceId,
          description: _name.text.trim(),
          amount: recurringAmount,
          frequency: _frequency,
          dueDay: int.tryParse(_dueDay.text) ?? 10,
          startDate: _startDate,
          endDate: _endDate,
          active: true,
          autoAsaas: _autoAsaas,
        );
      } else {
        await ref
            .read(servicesRepositoryProvider)
            .deactivateRecurring(serviceId);
      }

      if (isNew && _billing != ServiceBilling.recorrente && oneTime > 0) {
        await ref
            .read(servicesRepositoryProvider)
            .createCharge(
              userId: userId,
              clientId: _clientId!,
              serviceId: serviceId,
              description: _name.text.trim(),
              amount: oneTime,
              dueDate: _startDate,
            );
      }

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
    final clients = ref.watch(workspaceProvider).value?.clients ?? const [];
    final isRecurring = _billing != ServiceBilling.unico;

    return AppFormSheet(
      title: widget.service == null
          ? (widget.duplicateFrom == null ? 'Novo serviço' : 'Duplicar serviço')
          : 'Editar serviço',
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
          onChanged: (value) => setState(() => _clientId = value),
          validator: (value) => value == null ? 'Selecione o cliente' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nome do serviço'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descrição'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<ServiceBilling>(
          initialValue: _billing,
          decoration: const InputDecoration(labelText: 'Forma de cobrança'),
          items: [
            for (final billing in ServiceBilling.values)
              DropdownMenuItem(value: billing, child: Text(billing.label)),
          ],
          onChanged: (value) => setState(() => _billing = value ?? _billing),
        ),
        if (!isRecurring) ...[
          const SizedBox(height: 14),
          MoneyField(controller: _amount, label: 'Valor do serviço'),
        ],
        if (isRecurring) ...[
          const SizedBox(height: 14),
          MoneyField(controller: _recurringAmount, label: 'Valor recorrente'),
          const SizedBox(height: 14),
          DropdownButtonFormField<Recurrence>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequência'),
            items: [
              for (final frequency in Recurrence.values)
                DropdownMenuItem(
                  value: frequency,
                  child: Text(frequency.label),
                ),
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
              if (!isRecurring) return null;
              final day = int.tryParse(value ?? '');
              if (day == null || day < 1 || day > 28) {
                return 'Informe um dia entre 1 e 28';
              }
              return null;
            },
          ),
          if (_billing == ServiceBilling.misto) ...[
            const SizedBox(height: 14),
            MoneyField(
              controller: _amount,
              label: 'Valor único inicial (opcional)',
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoAsaas,
            onChanged: (value) => setState(() => _autoAsaas = value),
            title: const Text('Emitir no Asaas automaticamente'),
          ),
        ],
        const SizedBox(height: 14),
        DropdownButtonFormField<ServiceStatus>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Situação'),
          items: [
            for (final status in ServiceStatus.values)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: (value) => setState(() => _status = value ?? _status),
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
          label: 'Término (opcional)',
          value: _endDate,
          clearable: true,
          onChanged: (value) => setState(() => _endDate = value),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Link (opcional)'),
        ),
      ],
    );
  }
}
