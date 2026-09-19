import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/mask_formatter.dart';
import '../../models/user_business.dart';
import '../../repositories/quotes_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../auth/auth_providers.dart';
import 'quotes_providers.dart';

/// Abre o formulário de identidade do prestador (logo, empresa e dados usados
/// nos orçamentos). Lê a versão atual salva e grava ao confirmar.
Future<void> showBusinessFormSheet(BuildContext context, WidgetRef ref) async {
  final business = await ref.read(businessProvider.future);
  if (!context.mounted) return;
  return showAppFormSheet(context, BusinessFormSheet(business: business));
}

class BusinessFormSheet extends ConsumerStatefulWidget {
  const BusinessFormSheet({super.key, this.business});

  final UserBusiness? business;

  @override
  ConsumerState<BusinessFormSheet> createState() => _BusinessFormSheetState();
}

class _BusinessFormSheetState extends ConsumerState<BusinessFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _company;
  late final TextEditingController _document;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _paymentInfo;
  late final TextEditingController _extraNote;
  String? _logo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final business = widget.business;
    _company = TextEditingController(text: business?.company ?? '');
    _document = TextEditingController(text: business?.document ?? '');
    _email = TextEditingController(text: business?.email ?? '');
    _phone = TextEditingController(text: business?.phone ?? '');
    _address = TextEditingController(text: business?.address ?? '');
    _paymentInfo = TextEditingController(text: business?.paymentInfo ?? '');
    _extraNote = TextEditingController(text: business?.extraNote ?? '');
    _logo = business?.logo;
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/png';
      setState(() => _logo = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível carregar a imagem: ${friendlyError(error)}',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _company.dispose();
    _document.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _paymentInfo.dispose();
    _extraNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(quotesRepositoryProvider)
          .saveBusiness(
            userId: userId,
            logo: _logo,
            company: _company.text.trim(),
            document: _document.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            paymentInfo: _paymentInfo.text.trim(),
            extraNote: _extraNote.text.trim(),
          );
      ref.invalidate(businessProvider);
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
      title: 'Identidade do prestador',
      subtitle: 'Logo e dados usados nos seus orçamentos.',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _logo == null
                  ? const Icon(
                      Icons.image_outlined,
                      color: AppColors.mutedForeground,
                    )
                  : Image.memory(
                      base64Decode(_logo!.split(',').last),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.mutedForeground,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Escolher logo'),
                  ),
                  if (_logo != null)
                    TextButton(
                      onPressed: () => setState(() => _logo = null),
                      child: const Text('Remover logo'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _company,
          decoration: const InputDecoration(labelText: 'Empresa'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _document,
          keyboardType: TextInputType.number,
          inputFormatters: [MaskTextInputFormatter(cpfCnpjMask)],
          decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [MaskTextInputFormatter(phoneMask)],
          decoration: const InputDecoration(labelText: 'Telefone'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'Endereço'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _paymentInfo,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Formas de pagamento'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _extraNote,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Observação padrão'),
        ),
      ],
    );
  }
}
