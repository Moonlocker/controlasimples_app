import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/mask_formatter.dart';
import '../../core/utils/error_messages.dart';
import '../../models/notification_preferences.dart';
import '../../models/plan.dart';
import '../../models/profile.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/subscription_repository.dart';
import '../../repositories/whatsapp_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../services/local_notifications.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/plan_access.dart';
import '../auth/auth_providers.dart';
import '../auth/biometric_providers.dart';
import '../notifications/notification_delivery.dart';
import '../quotes/business_form_sheet.dart';
import '../quotes/quotes_providers.dart';
import '../subscription/subscription_flow.dart';
import 'payment_providers_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configurações'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Conta'),
              Tab(text: 'Plano'),
              Tab(text: 'Pagamentos'),
              Tab(text: 'Avisos'),
              Tab(text: 'Dados'),
            ],
          ),
        ),
        body: workspaceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(workspaceProvider),
          ),
          data: (workspace) {
            return TabBarView(
              children: [
                _TabList(
                  children: [
                    _AccountSection(profile: workspace.profile),
                    const SizedBox(height: 16),
                    const _BusinessSection(),
                    const SizedBox(height: 16),
                    const _BiometricSection(),
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
                      onPressed: () =>
                          ref.read(authRepositoryProvider).signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sair'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const _TabList(children: [_SubscriptionSection()]),
                const _TabList(children: [PaymentProvidersSection()]),
                const _TabList(
                  children: [
                    _WhatsappSection(),
                    SizedBox(height: 16),
                    _NotificationsSection(),
                    SizedBox(height: 16),
                    _DeviceNotificationsSection(),
                  ],
                ),
                const _TabList(children: [_DataSection()]),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lista rolável padrão de uma aba de Configurações.
class _TabList extends StatelessWidget {
  const _TabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: children,
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Conta',
      action: TextButton(
        onPressed: () => showAppFormSheet(context, const _ProfileFormSheet()),
        child: const Text('Editar'),
      ),
      children: [
        _InfoRow(label: 'Nome', value: profile?.name ?? '—'),
        _InfoRow(label: 'E-mail', value: profile?.email ?? '—'),
        _InfoRow(label: 'Empresa', value: profile?.company ?? '—'),
        _InfoRow(label: 'Telefone', value: profile?.phone ?? '—'),
        _InfoRow(label: 'CPF/CNPJ', value: profile?.document ?? '—'),
      ],
    );
  }
}

class _BiometricSection extends ConsumerWidget {
  const _BiometricSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(biometricEnabledProvider);
    final supportAsync = ref.watch(biometricSupportProvider);
    final supported = supportAsync.value ?? false;
    final enabled = enabledAsync.value ?? false;
    final busy = enabledAsync.isLoading || supportAsync.isLoading;

    return _Section(
      title: 'Acesso ao app',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: (!supported || busy)
              ? null
              : (value) async {
                  if (value) {
                    await context.push<bool>('/biometric-setup');
                  } else {
                    await ref
                        .read(biometricEnabledProvider.notifier)
                        .setEnabled(false);
                  }
                },
          secondary: const Icon(Icons.fingerprint, color: AppColors.primary),
          title: const Text('Entrar com biometria'),
          subtitle: Text(
            supported
                ? 'Use a digital, o reconhecimento facial ou a senha do celular para entrar.'
                : 'Indisponível neste aparelho. Cadastre uma biometria ou uma senha de bloqueio.',
          ),
        ),
      ],
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
        onPressed: () => showBusinessFormSheet(context, ref),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PlanLockBadge(size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'As notificações por WhatsApp não estão disponíveis no seu plano atual. Faça upgrade para usá-las.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ],
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
    final canUse = ref.watch(workspaceProvider).value?.canUseWhatsapp ?? true;
    if (!canUse) {
      return _Section(
        title: 'Notificações automáticas',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PlanLockBadge(size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'As notificações automáticas não estão disponíveis no seu plano atual. Faça upgrade para usá-las.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
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

class _DeviceNotificationsSection extends ConsumerWidget {
  const _DeviceNotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(localNotificationPreferencesProvider);
    return async.when(
      loading: () => const _Section(
        title: 'Avisos no celular',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => _Section(
        title: 'Avisos no celular',
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
      data: (preferences) {
        final notifier = ref.read(
          localNotificationPreferencesProvider.notifier,
        );
        return _Section(
          title: 'Avisos no celular',
          children: [
            Text(
              'Receba no aparelho quando um pagamento entrar (inclusive pelo '
              'gateway), quando uma cobrança atrasar ou estiver perto de vencer.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: preferences.enabled,
              onChanged: (value) {
                notifier.save(preferences.copyWith(enabled: value));
                if (value) LocalNotifications.instance.ensurePermission();
              },
              title: const Text('Ativar avisos no celular'),
            ),
            if (preferences.enabled) ...[
              const Divider(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.payments,
                onChanged: (value) =>
                    notifier.save(preferences.copyWith(payments: value)),
                title: const Text('Pagamentos recebidos'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.overdue,
                onChanged: (value) =>
                    notifier.save(preferences.copyWith(overdue: value)),
                title: const Text('Cobranças atrasadas'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.upcoming,
                onChanged: (value) =>
                    notifier.save(preferences.copyWith(upcoming: value)),
                title: const Text('Vencimentos próximos'),
              ),
            ],
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
