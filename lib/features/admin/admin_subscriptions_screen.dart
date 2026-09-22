import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/payment_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../models/platform_billing.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/empty_state.dart';
import 'admin_providers.dart';

const _cycles = [
  ('MONTHLY', 'Mensal'),
  ('QUARTERLY', 'Trimestral'),
  ('SEMIANNUAL', 'Semestral'),
  ('YEARLY', 'Anual'),
];

const _billingTypes = [
  ('CREDIT_CARD', 'Cartão de crédito'),
  ('PIX', 'Pix'),
  ('BOLETO', 'Boleto'),
  ('UNDEFINED', 'Cliente escolhe no gateway'),
];

String _label(List<(String, String)> values, String? wire) {
  for (final value in values) {
    if (value.$1 == wire) return value.$2;
  }
  return '—';
}

String _statusLabel(String status) => switch (status) {
  'ativa' => 'Ativa',
  'trial' => 'Em teste',
  'cancelada' => 'Cancelada',
  'inadimplente' => 'Pagamento pendente',
  _ => status,
};

class AdminSubscriptionsScreen extends ConsumerWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(adminPlatformBillingConfigProvider);
    final subsAsync = ref.watch(adminPlatformSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assinaturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar modelo de assinatura',
            onPressed: () =>
                showAppFormSheet(context, const _PlatformBillingFormSheet()),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminPlatformBillingConfigProvider),
        ),
        data: (config) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminPlatformBillingConfigProvider);
            ref.invalidate(adminPlatformSubscriptionsProvider);
            try {
              await ref.read(adminPlatformSubscriptionsProvider.future);
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _ConfigCard(config: config),
              const SizedBox(height: 20),
              Text(
                'Assinaturas dos usuários',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              subsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  'Não foi possível carregar: ${friendlyError(error)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (subscriptions) {
                  if (subscriptions.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Nenhuma assinatura',
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < subscriptions.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _SubscriptionTile(subscription: subscriptions[i]),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.config});

  final PlatformBillingConfig config;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = paymentProviderCatalog(config.provider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Modelo de assinatura',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (config.enabled ? AppColors.success : AppColors.muted)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  config.enabled ? 'Ativo' : 'Desativado',
                  style: textTheme.labelSmall?.copyWith(
                    color: config.enabled
                        ? AppColors.success
                        : AppColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(context, 'Gateway', provider?.label ?? config.provider),
          _row(
            context,
            'Ambiente',
            config.providerEnvironment == 'production' ? 'Produção' : 'Sandbox',
          ),
          _row(
            context,
            'Credencial',
            config.hasAccessToken
                ? (config.maskedAccessToken ?? 'Configurada')
                : 'Não configurada',
          ),
          _row(context, 'Ciclo padrão', _label(_cycles, config.billingCycle)),
          _row(
            context,
            'Forma padrão',
            _label(_billingTypes, config.defaultBillingType),
          ),
          _row(context, 'Dias de teste', '${config.trialDays}'),
          if (!config.supportsSubscription)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este gateway não suporta assinaturas recorrentes.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            )
          else if (!config.supportsCard)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este gateway não cobra cartão recorrente. Use boleto/pix ou outro gateway.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
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

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.subscription});

  final PlatformSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      title: Text(
        subscription.name.isEmpty ? subscription.email : subscription.name,
      ),
      subtitle: Text(
        '${subscription.planName ?? 'Sem plano'} · '
        '${_label(_cycles, subscription.cycle)} · '
        '${_label(_billingTypes, subscription.billingType)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _statusLabel(subscription.status),
            style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subscription.invoiceUrl != null)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(subscription.invoiceUrl!)),
              child: Text(
                'Fatura',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlatformBillingFormSheet extends ConsumerStatefulWidget {
  const _PlatformBillingFormSheet();

  @override
  ConsumerState<_PlatformBillingFormSheet> createState() =>
      _PlatformBillingFormSheetState();
}

class _PlatformBillingFormSheetState
    extends ConsumerState<_PlatformBillingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _secret = TextEditingController();
  final _trialDays = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  bool _enabled = true;
  String _provider = 'asaas';
  String _environment = 'sandbox';
  String _cycle = 'MONTHLY';
  String _billingType = 'CREDIT_CARD';
  bool _allowOther = true;
  String? _result;
  bool _resultOk = false;

  @override
  void dispose() {
    _token.dispose();
    _secret.dispose();
    _trialDays.dispose();
    super.dispose();
  }

  void _hydrate(PlatformBillingConfig config) {
    if (_loaded) return;
    _enabled = config.enabled;
    _provider = config.provider;
    _environment = config.providerEnvironment;
    _cycle = config.billingCycle;
    _billingType = config.defaultBillingType;
    _allowOther = config.allowOtherBillingTypes;
    _trialDays.text = '${config.trialDays}';
    _loaded = true;
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .testPlatformBilling(
            provider: _provider,
            providerEnvironment: _environment,
            providerAccessToken: _token.text.trim().isEmpty
                ? null
                : _token.text.trim(),
          );
      if (mounted) {
        setState(() {
          _result = result.message.isEmpty ? 'Testado.' : result.message;
          _resultOk = result.ok;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _result = friendlyError(error);
          _resultOk = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .savePlatformBillingConfig(
            enabled: _enabled,
            provider: _provider,
            providerEnvironment: _environment,
            providerAccessToken: _token.text.trim().isEmpty
                ? null
                : _token.text.trim(),
            providerWebhookSecret: _secret.text.trim().isEmpty
                ? null
                : _secret.text.trim(),
            billingCycle: _cycle,
            defaultBillingType: _billingType,
            allowOtherBillingTypes: _allowOther,
            trialDays: int.tryParse(_trialDays.text.trim()) ?? 0,
          );
      ref.invalidate(adminPlatformBillingConfigProvider);
      if (mounted) Navigator.of(context).pop();
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
    final configAsync = ref.watch(adminPlatformBillingConfigProvider);
    final config = configAsync.value;
    if (config != null) _hydrate(config);

    final entry = paymentProviderCatalog(_provider);

    return AppFormSheet(
      title: 'Modelo de assinatura',
      subtitle: 'Gateway, ciclo e forma de pagamento das assinaturas.',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
          title: const Text('Assinaturas ativas'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(labelText: 'Gateway de cobrança'),
          items: [
            for (final provider in paymentProviders)
              DropdownMenuItem(value: provider.id, child: Text(provider.label)),
          ],
          onChanged: (value) => setState(() => _provider = value ?? _provider),
        ),
        const SizedBox(height: 14),
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
          controller: _token,
          obscureText: true,
          decoration: InputDecoration(
            labelText: entry?.accessTokenLabel ?? 'Credencial do gateway',
            hintText:
                config?.maskedAccessToken ?? entry?.accessTokenPlaceholder,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _secret,
          obscureText: true,
          decoration: InputDecoration(
            labelText: entry?.webhookSecretLabel ?? 'Segredo do webhook',
            hintText: config?.hasWebhookSecret == true
                ? 'Configurado'
                : 'Opcional',
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _cycle,
          decoration: const InputDecoration(labelText: 'Ciclo padrão'),
          items: [
            for (final cycle in _cycles)
              DropdownMenuItem(value: cycle.$1, child: Text(cycle.$2)),
          ],
          onChanged: (value) => setState(() => _cycle = value ?? _cycle),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _billingType,
          decoration: const InputDecoration(labelText: 'Forma padrão'),
          items: [
            for (final type in _billingTypes)
              DropdownMenuItem(value: type.$1, child: Text(type.$2)),
          ],
          onChanged: (value) =>
              setState(() => _billingType = value ?? _billingType),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _trialDays,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Dias de teste (novos usuários)',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _allowOther,
          onChanged: (value) => setState(() => _allowOther = value),
          title: const Text('Permitir outras formas de pagamento'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _test,
            icon: const Icon(Icons.wifi_tethering, size: 18),
            label: const Text('Testar conexão'),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 10),
          Text(
            _result!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _resultOk ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}
