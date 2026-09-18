import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/asaas.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/section_card.dart';
import 'admin_providers.dart';

class AdminAsaasScreen extends ConsumerWidget {
  const AdminAsaasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(adminAsaasConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Asaas da plataforma')),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminAsaasConfigProvider),
        ),
        data: (config) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SectionCard(
              title: 'Configuração',
              action: TextButton(
                onPressed: () => showAppFormSheet(
                  context,
                  _AsaasAdminFormSheet(config: config),
                ),
                child: const Text('Editar'),
              ),
              child: Column(
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
                  _InfoRow(
                    label: 'Webhook',
                    value: config.hasWebhookToken
                        ? 'Configurado'
                        : 'Não configurado',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _AsaasTestButton(),
          ],
        ),
      ),
    );
  }
}

class _AsaasTestButton extends ConsumerStatefulWidget {
  const _AsaasTestButton();

  @override
  ConsumerState<_AsaasTestButton> createState() => _AsaasTestButtonState();
}

class _AsaasTestButtonState extends ConsumerState<_AsaasTestButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _busy = true);
              try {
                final result = await ref
                    .read(adminRepositoryProvider)
                    .testAsaasAdmin();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.message.isEmpty ? 'Testado.' : result.message,
                    ),
                  ),
                );
              } catch (error) {
                messenger.showSnackBar(SnackBar(content: Text('$error')));
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: const Icon(Icons.wifi_tethering),
      label: const Text('Testar conexão'),
    );
  }
}

class _AsaasAdminFormSheet extends ConsumerStatefulWidget {
  const _AsaasAdminFormSheet({required this.config});

  final AsaasConfig config;

  @override
  ConsumerState<_AsaasAdminFormSheet> createState() =>
      _AsaasAdminFormSheetState();
}

class _AsaasAdminFormSheetState extends ConsumerState<_AsaasAdminFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _apiKey = TextEditingController();
  final _webhookToken = TextEditingController();
  late bool _enabled;
  late String _environment;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.config.enabled;
    _environment = widget.config.environment;
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _webhookToken.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .saveAsaasAdminConfig(
            enabled: _enabled,
            environment: _environment,
            apiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
            webhookToken: _webhookToken.text.trim().isEmpty
                ? null
                : _webhookToken.text.trim(),
          );
      ref.invalidate(adminAsaasConfigProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Asaas da plataforma',
      subtitle: 'Usada para cobrar as assinaturas dos usuários.',
      formKey: _formKey,
      busy: _busy,
      onSave: _save,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
          title: const Text('Ativar integração'),
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
                ? 'Deixe vazio para manter'
                : 'Sua chave Asaas',
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _webhookToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Token do webhook'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
