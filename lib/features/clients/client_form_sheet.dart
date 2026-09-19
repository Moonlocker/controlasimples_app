import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/mask_formatter.dart';
import '../../core/utils/error_messages.dart';
import '../../models/client.dart';
import '../../repositories/clients_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../auth/auth_providers.dart';

Future<void> showClientForm(BuildContext context, {Client? client}) {
  return showAppFormSheet(context, ClientFormSheet(client: client));
}

class ClientFormSheet extends ConsumerStatefulWidget {
  const ClientFormSheet({super.key, this.client});

  final Client? client;

  @override
  ConsumerState<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends ConsumerState<ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _document;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?.name ?? '');
    _document = TextEditingController(text: client?.document ?? '');
    _phone = TextEditingController(text: client?.phone ?? '');
    _email = TextEditingController(text: client?.email ?? '');
    _notes = TextEditingController(text: client?.notes ?? '');
    _active = client?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(clientsRepositoryProvider)
          .save(
            id: widget.client?.id,
            userId: userId,
            name: _name.text.trim(),
            document: _document.text.trim().isEmpty
                ? null
                : _document.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            active: _active,
          );
      ref.invalidate(workspaceProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar: ${friendlyError(error)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: widget.client == null ? 'Novo cliente' : 'Editar cliente',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nome'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _document,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [MaskTextInputFormatter(cpfCnpjMask)],
          decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [MaskTextInputFormatter(phoneMask)],
          decoration: const InputDecoration(labelText: 'Telefone/WhatsApp'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Observações'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (value) => setState(() => _active = value),
          title: const Text('Cliente ativo'),
          subtitle: const Text(
            'Clientes inativos não aparecem em novos registros.',
          ),
        ),
      ],
    );
  }
}
