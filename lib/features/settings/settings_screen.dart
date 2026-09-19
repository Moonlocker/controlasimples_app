import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/mask_formatter.dart';
import '../../core/utils/error_messages.dart';
import '../../models/asaas.dart';
import '../../models/notification_preferences.dart';
import '../../models/plan.dart';
import '../../models/user_business.dart';
import '../../repositories/asaas_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/quotes_repository.dart';
import '../../repositories/subscription_repository.dart';
import '../../repositories/whatsapp_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/async_error_view.dart';
import '../auth/auth_providers.dart';
import '../quotes/quotes_providers.dart';
import '../subscription/subscription_flow.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: workspaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(workspaceProvider),
        ),
        data: (workspace) {
          final profile = workspace.profile;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Section(
                title: 'Conta',
                action: TextButton(
                  onPressed: () =>
                      showAppFormSheet(context, const _ProfileFormSheet()),
                  child: const Text('Editar'),
                ),
                children: [
                  _InfoRow(label: 'Nome', value: profile?.name ?? '—'),
                  _InfoRow(label: 'E-mail', value: profile?.email ?? '—'),
                  _InfoRow(label: 'Empresa', value: profile?.company ?? '—'),
                  _InfoRow(label: 'Telefone', value: profile?.phone ?? '—'),
                  _InfoRow(label: 'CPF/CNPJ', value: profile?.document ?? '—'),
                ],
              ),
              const SizedBox(height: 16),
              const _SubscriptionSection(),
              const SizedBox(height: 16),
              const _AsaasSection(),
              const SizedBox(height: 16),
              const _WhatsappSection(),
              const SizedBox(height: 16),
              const _NotificationsSection(),
              const SizedBox(height: 16),
              const _BusinessSection(),
              const SizedBox(height: 16),
              const _DataSection(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _ChangePasswordDialog(),
                ),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Alterar senha'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BusinessSection extends ConsumerWidget {
  const _BusinessSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProvider).value;
    return _Section(
      title: 'Dados para orçamentos',
      action: TextButton(
        onPressed: () =>
            showAppFormSheet(context, _BusinessFormSheet(business: business)),
        child: const Text('Editar'),
      ),
      children: [
        _InfoRow(label: 'Empresa', value: business?.company ?? '—'),
        _InfoRow(label: 'CPF/CNPJ', value: business?.document ?? '—'),
        _InfoRow(label: 'Telefone', value: business?.phone ?? '—'),
        _InfoRow(label: 'Pagamento', value: business?.paymentInfo ?? '—'),
      ],
    );
  }
}

class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _busy = false;

  Future<void> _export() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseProvider);
      final results = await Future.wait<List<dynamic>>([
        client.from('clients').select().eq('user_id', userId),
        client.from('projects').select().eq('user_id', userId),
        client.from('charges').select().eq('user_id', userId),
        client.from('recurring_charges').select().eq('user_id', userId),
        client.from('payments').select().eq('user_id', userId),
        client.from('quotes').select().eq('user_id', userId),
        client.from('user_business').select().eq('user_id', userId),
        client.from('profiles').select().eq('id', userId),
        client.from('subscriptions').select().eq('user_id', userId),
      ]);
      final backup = <String, dynamic>{
        'exportedAt': DateTime.now().toIso8601String(),
        'clients': results[0],
        'projects': results[1],
        'charges': results[2],
        'recurring_charges': results[3],
        'payments': results[4],
        'quotes': results[5],
        'user_business': results[6],
        'profiles': results[7],
        'subscriptions': results[8],
      };
      final content = const JsonEncoder.withIndent('  ').convert(backup);
      final file = XFile.fromData(
        utf8.encode(content),
        name: 'controla-simples-backup.json',
        mimeType: 'application/json',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], subject: 'Backup Controla Simples'),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Seus dados',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.download_outlined,
            color: AppColors.primary,
          ),
          title: const Text('Exportar backup (JSON)'),
          subtitle: const Text('Baixe uma cópia completa dos seus dados.'),
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.chevron_right,
                  color: AppColors.mutedForeground,
                ),
          onTap: _busy ? null : _export,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFormSheet extends ConsumerStatefulWidget {
  const _ProfileFormSheet();

  @override
  ConsumerState<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends ConsumerState<_ProfileFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _document = TextEditingController();
  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _phone.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(
            userId: userId,
            name: _name.text.trim(),
            company: _company.text.trim(),
            phone: _phone.text.trim(),
            document: _document.text.trim(),
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
    final profile = ref.watch(workspaceProvider).value?.profile;
    if (!_loaded && profile != null) {
      _name.text = profile.name;
      _company.text = profile.company ?? '';
      _phone.text = profile.phone ?? '';
      _document.text = profile.document ?? '';
      _loaded = true;
    }

    return AppFormSheet(
      title: 'Editar perfil',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nome'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _company,
          decoration: const InputDecoration(labelText: 'Empresa'),
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
          controller: _document,
          keyboardType: TextInputType.number,
          inputFormatters: [MaskTextInputFormatter(cpfCnpjMask)],
          decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
        ),
      ],
    );
  }
}

class _BusinessFormSheet extends ConsumerStatefulWidget {
  const _BusinessFormSheet({this.business});

  final UserBusiness? business;

  @override
  ConsumerState<_BusinessFormSheet> createState() => _BusinessFormSheetState();
}

class _BusinessFormSheetState extends ConsumerState<_BusinessFormSheet> {
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
      title: 'Dados para orçamentos',
      subtitle: 'Aparecem no PDF enviado ao cliente.',
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

class _SubscriptionSection extends ConsumerWidget {
  const _SubscriptionSection();

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar assinatura'),
        content: const Text(
          'A cobrança recorrente será interrompida e sua conta voltará ao plano gratuito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(subscriptionRepositoryProvider).cancel();
      ref.invalidate(workspaceProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assinatura cancelada.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider).value;
    if (workspace == null) return const SizedBox.shrink();
    final currentPlan = workspace.plan;
    final subscription = workspace.subscription;
    final canCancel =
        subscription != null &&
        (currentPlan?.price ?? 0) > 0 &&
        subscription.status != SubscriptionStatus.cancelada;

    return _Section(
      title: 'Assinatura',
      children: [
        _InfoRow(label: 'Plano', value: currentPlan?.name ?? 'Sem plano'),
        _InfoRow(label: 'Situação', value: subscription?.status.label ?? '—'),
        if (subscription?.currentPeriodEnd != null)
          _InfoRow(
            label: 'Válido até',
            value: formatDate(subscription!.currentPeriodEnd!),
          ),
        if (subscription?.asaasInvoiceUrl != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(subscription!.asaasInvoiceUrl!)),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir fatura'),
            ),
          ),
        if (canCancel)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextButton(
              onPressed: () => _cancel(context, ref),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancelar assinatura'),
            ),
          ),
        const Divider(height: 20),
        for (final plan in workspace.plans) ...[
          _PlanCard(
            plan: plan,
            current: plan.id == currentPlan?.id,
            onTap: () => subscribeToPlanFlow(context, ref, plan),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.onTap,
  });

  final Plan plan;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: current ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: current
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: plan.highlighted ? AppColors.primary : AppColors.border,
            width: plan.highlighted ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  plan.price <= 0 ? 'Grátis' : '${brl(plan.price)}/mês',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final feature in plan.features)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(feature, style: textTheme.labelSmall),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (current)
              Text(
                'Plano atual',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                'Toque para assinar',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AsaasSection extends ConsumerWidget {
  const _AsaasSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUse = ref.watch(workspaceProvider).value?.canUseAsaas ?? true;
    if (!canUse) {
      return _Section(
        title: 'Asaas',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'A integração Asaas não está disponível no seu plano atual. Faça upgrade para emitir cobranças.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
        ],
      );
    }
    final configAsync = ref.watch(asaasConfigProvider);
    return configAsync.when(
      loading: () => const _Section(
        title: 'Asaas',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => _Section(
        title: 'Asaas',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Não foi possível carregar: ${friendlyError(error)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      data: (config) => _Section(
        title: 'Asaas',
        action: TextButton(
          onPressed: () =>
              showAppFormSheet(context, _AsaasConfigSheet(config: config)),
          child: const Text('Configurar'),
        ),
        children: [
          _InfoRow(
            label: 'Situação',
            value: config.enabled ? 'Ativado' : 'Desativado',
          ),
          _InfoRow(
            label: 'Ambiente',
            value: config.isProduction ? 'Produção' : 'Sandbox',
          ),
          _InfoRow(
            label: 'Chave',
            value:
                config.maskedKey ??
                (config.hasKey ? 'Configurada' : 'Não configurada'),
          ),
        ],
      ),
    );
  }
}

class _AsaasConfigSheet extends ConsumerStatefulWidget {
  const _AsaasConfigSheet({required this.config});

  final AsaasConfig config;

  @override
  ConsumerState<_AsaasConfigSheet> createState() => _AsaasConfigSheetState();
}

class _AsaasConfigSheetState extends ConsumerState<_AsaasConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  final _apiKey = TextEditingController();
  late bool _enabled;
  late String _environment;
  bool _busy = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _environment = widget.config.environment;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(asaasRepositoryProvider)
          .saveConfig(
            enabled: _enabled,
            environment: _environment,
            apiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
          );
      ref.invalidate(asaasConfigProvider);
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

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final result = await ref.read(asaasRepositoryProvider).testConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isEmpty ? 'Testado.' : result.message),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Integração Asaas',
      subtitle: 'Use a sua chave de API para emitir cobranças na sua conta.',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
          title: const Text('Ativar emissão de cobranças'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _environment,
          decoration: const InputDecoration(labelText: 'Ambiente'),
          items: const [
            DropdownMenuItem(value: 'sandbox', child: Text('Sandbox (testes)')),
            DropdownMenuItem(value: 'production', child: Text('Produção')),
          ],
          onChanged: (value) =>
              setState(() => _environment = value ?? _environment),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _apiKey,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Chave de API',
            hintText: widget.config.hasKey
                ? 'Deixe vazio para manter a atual'
                : 'Sua chave Asaas',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering),
          label: const Text('Testar conexão'),
        ),
      ],
    );
  }
}

class _WhatsappSection extends ConsumerWidget {
  const _WhatsappSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUse = ref.watch(workspaceProvider).value?.canUseWhatsapp ?? true;
    if (!canUse) {
      return _Section(
        title: 'WhatsApp',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'As notificações por WhatsApp não estão disponíveis no seu plano atual. Faça upgrade para usá-las.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
        ],
      );
    }
    final usageAsync = ref.watch(whatsappUsageProvider);
    return usageAsync.when(
      loading: () => const _Section(
        title: 'WhatsApp',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => _Section(
        title: 'WhatsApp',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Não foi possível carregar: ${friendlyError(error)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      data: (usage) {
        final progress = usage.quota == 0
            ? 0.0
            : (usage.sent / usage.quota).clamp(0.0, 1.0);
        return _Section(
          title: 'WhatsApp',
          children: [
            _InfoRow(
              label: 'Situação',
              value: usage.enabled ? 'Ativado' : 'Desativado',
            ),
            _InfoRow(
              label: 'Enviadas no mês',
              value: '${usage.sent} de ${usage.quota}',
            ),
            _InfoRow(label: 'Restantes', value: '${usage.remaining}'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.muted,
                color: usage.remaining < 5
                    ? AppColors.danger
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível alterar a senha. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar senha'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
              validator: (value) =>
                  (value ?? '').length < 6 ? 'Mínimo de 6 caracteres' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
              validator: (value) => value != _passwordController.text
                  ? 'As senhas não conferem'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Notificações automáticas pelo WhatsApp oficial da plataforma.
class _NotificationsSection extends ConsumerStatefulWidget {
  const _NotificationsSection();

  @override
  ConsumerState<_NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<_NotificationsSection> {
  NotificationPreferences? _form;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(notificationSettingsProvider.future).then((settings) {
      if (mounted) setState(() => _form = settings.preferences);
    });
  }

  void _update(NotificationPreferences value) {
    setState(() => _form = _syncEnabled(value));
  }

  /// O envio automático fica ativo quando ao menos uma ocasião é escolhida.
  NotificationPreferences _syncEnabled(NotificationPreferences value) {
    return value.copyWith(
      whatsappEnabled:
          value.reminderBeforeEnabled ||
          value.onDueEnabled ||
          value.overdueEnabled,
    );
  }

  Future<void> _save() async {
    final form = _form;
    if (form == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .savePreferences(_syncEnabled(form));
      ref.invalidate(notificationSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências de notificação salvas.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationSettingsProvider);
    return async.when(
      loading: () => const _Section(
        title: 'Notificações automáticas',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => _Section(
        title: 'Notificações automáticas',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Não foi possível carregar: ${friendlyError(error)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      data: (settings) {
        final form = _form ?? settings.preferences;
        final limits = settings.limits;
        return _Section(
          title: 'Notificações automáticas',
          children: [
            Text(
              'Avisos enviados pelo número oficial da Controla Simples. Para '
              'evitar spam e controlar o custo, o superadmin define os prazos '
              'máximos e você escolhe as ocasiões.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 8),
            if (!limits.integrationEnabled)
              Text(
                'O envio pelo WhatsApp oficial está temporariamente indisponível.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.warning),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.reminderBeforeEnabled,
              onChanged: (value) =>
                  _update(form.copyWith(reminderBeforeEnabled: value)),
              title: const Text('Antes do vencimento'),
            ),
            _CounterRow(
              label: 'Dias antes (máx. ${limits.maxReminderDaysBefore})',
              value: form.reminderBeforeDays.clamp(
                1,
                limits.maxReminderDaysBefore,
              ),
              min: 1,
              max: limits.maxReminderDaysBefore,
              onChanged: (value) =>
                  _update(form.copyWith(reminderBeforeDays: value)),
            ),
            const Divider(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.onDueEnabled,
              onChanged: (value) => _update(form.copyWith(onDueEnabled: value)),
              title: const Text('No dia do vencimento'),
            ),
            const Divider(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.overdueEnabled,
              onChanged: (value) =>
                  _update(form.copyWith(overdueEnabled: value)),
              title: const Text('Após o vencimento'),
            ),
            _CounterRow(
              label: 'Dias após (máx. ${limits.maxOverdueDays})',
              value: form.overdueDays.clamp(1, limits.maxOverdueDays),
              min: 1,
              max: limits.maxOverdueDays,
              onChanged: (value) => _update(form.copyWith(overdueDays: value)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar preferências'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Diminuir',
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Aumentar',
          ),
        ],
      ),
    );
  }
}
