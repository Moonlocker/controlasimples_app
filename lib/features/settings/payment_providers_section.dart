import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/payment_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../models/payment_provider.dart';
import '../../repositories/payments_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/payment_provider_guide.dart';
import '../../widgets/payment_provider_logo.dart';

/// Seção de configuração dos gateways de pagamento (usada em Configurações).
class PaymentProvidersSection extends ConsumerWidget {
  const PaymentProvidersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentProvidersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meios de pagamento',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Não foi possível carregar: ${friendlyError(error)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (view) => PaymentProvidersBody(view: view),
          ),
        ),
      ],
    );
  }
}

/// Abre a configuração dos gateways em um bottom sheet (atalho de Cobranças).
Future<void> showPaymentProvidersSheet(BuildContext context) {
  return showAppFormSheet(context, const _PaymentProvidersSheet());
}

class _PaymentProvidersSheet extends ConsumerStatefulWidget {
  const _PaymentProvidersSheet();

  @override
  ConsumerState<_PaymentProvidersSheet> createState() =>
      _PaymentProvidersSheetState();
}

class _PaymentProvidersSheetState
    extends ConsumerState<_PaymentProvidersSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentProvidersProvider);
    return AppFormSheet(
      title: 'Meios de pagamento',
      subtitle: 'Ative o gateway que emite as cobranças dos seus clientes.',
      formKey: _formKey,
      onSave: () async => Navigator.of(context).pop(),
      saveLabel: 'Fechar',
      children: [
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Text('Não foi possível carregar: ${friendlyError(error)}'),
          data: (view) => PaymentProvidersBody(view: view),
        ),
      ],
    );
  }
}

/// Lista de gateways com expansão controlada: apenas um fica aberto por vez
/// para que as credenciais de gateways diferentes não se misturem.
class PaymentProvidersBody extends StatefulWidget {
  const PaymentProvidersBody({super.key, required this.view});

  final PaymentProvidersView view;

  @override
  State<PaymentProvidersBody> createState() => _PaymentProvidersBodyState();
}

class _PaymentProvidersBodyState extends State<PaymentProvidersBody> {
  String? _openId;

  @override
  void initState() {
    super.initState();
    _openId = widget.view.activeProvider;
  }

  @override
  void didUpdateWidget(covariant PaymentProvidersBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_openId == null && widget.view.activeProvider != null) {
      _openId = widget.view.activeProvider;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in widget.view.providers) ...[
          _ProviderCard(
            provider: provider,
            open: _openId == provider.id,
            onToggle: () => setState(
              () => _openId = _openId == provider.id ? null : provider.id,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProviderCard extends ConsumerStatefulWidget {
  const _ProviderCard({
    required this.provider,
    required this.open,
    required this.onToggle,
  });

  final PaymentProviderConfig provider;
  final bool open;
  final VoidCallback onToggle;

  @override
  ConsumerState<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<_ProviderCard> {
  final _token = TextEditingController();
  final _secret = TextEditingController();
  late bool _enabled;
  late String _environment;
  bool _busy = false;
  bool _testing = false;
  String? _result;
  bool _resultOk = false;

  PaymentProviderConfig get _config => widget.provider;

  @override
  void initState() {
    super.initState();
    _enabled = _config.enabled;
    _environment = _config.environment;
  }

  @override
  void didUpdateWidget(covariant _ProviderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.enabled != _config.enabled) {
      _enabled = _config.enabled;
    }
    if (oldWidget.provider.environment != _config.environment) {
      _environment = _config.environment;
    }
  }

  @override
  void dispose() {
    _token.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .saveProvider(
            provider: _config.id,
            enabled: _enabled,
            environment: _environment,
            accessToken: _token.text.trim().isEmpty ? null : _token.text.trim(),
            webhookSecret: _secret.text.trim().isEmpty
                ? null
                : _secret.text.trim(),
          );
      _token.clear();
      _secret.clear();
      ref.invalidate(paymentProvidersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuração do ${_config.label} salva.')),
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

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final result = await ref
          .read(paymentsRepositoryProvider)
          .testProvider(
            provider: _config.id,
            environment: _environment,
            accessToken: _token.text.trim().isEmpty ? null : _token.text.trim(),
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
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _activate() async {
    setState(() => _busy = true);
    try {
      await ref.read(paymentsRepositoryProvider).activateProvider(_config.id);
      ref.invalidate(paymentProvidersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Agora as cobranças serão emitidas pelo ${_config.label}.',
            ),
          ),
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
    final textTheme = Theme.of(context).textTheme;
    final entry = paymentProviderCatalog(_config.id);
    final webhookUrl = entry == null
        ? ''
        : '${AppConfig.apiBaseUrl}${entry.webhookPath}';
    final statusText = _config.active
        ? 'Gateway usado nas cobranças.'
        : _config.configured
        ? 'Pronto para usar.'
        : 'Ative e informe as credenciais.';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _config.active ? AppColors.primary : AppColors.border,
          width: _config.active ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  PaymentProviderLogo(provider: _config.id, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _config.label,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_config.active) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Em uso',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          statusText,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: _enabled,
                    onChanged: (value) {
                      setState(() => _enabled = value);
                      if (value && !widget.open) widget.onToggle();
                    },
                  ),
                  Icon(
                    widget.open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          if (widget.open && entry != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_enabled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'O gateway está desativado. Ligue o botão acima para usá-lo nas cobranças.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  PaymentProviderGuide(
                    providerId: _config.id,
                    webhookUrl: webhookUrl,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _environment,
                    decoration: const InputDecoration(labelText: 'Ambiente'),
                    items: const [
                      DropdownMenuItem(
                        value: 'sandbox',
                        child: Text('Teste / Sandbox'),
                      ),
                      DropdownMenuItem(
                        value: 'production',
                        child: Text('Produção'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _environment = value ?? _environment),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _token,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: entry.accessTokenLabel,
                      hintText:
                          _config.maskedAccessToken ??
                          entry.accessTokenPlaceholder,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secret,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: entry.webhookSecretLabel,
                      hintText: _config.hasWebhookSecret
                          ? 'Configurado'
                          : entry.webhookSecretHint,
                      helperText: entry.webhookSecretHint,
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Salvar configuração'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _testing ? null : _test,
                        icon: const Icon(Icons.wifi_tethering, size: 18),
                        label: const Text('Testar conexão'),
                      ),
                      if (_config.configured && !_config.active)
                        OutlinedButton(
                          onPressed: _busy ? null : _activate,
                          child: const Text('Usar este gateway'),
                        ),
                    ],
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _result!,
                      style: textTheme.bodySmall?.copyWith(
                        color: _resultOk ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
