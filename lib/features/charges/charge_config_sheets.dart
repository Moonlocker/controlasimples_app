import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../models/asaas.dart';
import '../../models/notification_preferences.dart';
import '../../repositories/asaas_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/asaas_setup_guide.dart';

/// Abre a configuração da integração Asaas do usuário.
Future<void> showAsaasConfigSheet(BuildContext context) {
  return showAppFormSheet(context, const _AsaasConfigSheet());
}

class _AsaasConfigSheet extends ConsumerWidget {
  const _AsaasConfigSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUse = ref.watch(workspaceProvider).value?.canUseAsaas ?? true;
    if (!canUse) {
      return const _SimpleSheet(
        title: 'Integração Asaas',
        child: Text(
          'A integração Asaas não está disponível no seu plano atual. '
          'Faça upgrade para emitir cobranças.',
        ),
      );
    }
    final configAsync = ref.watch(asaasConfigProvider);
    return configAsync.when(
      loading: () => const _SimpleSheet(
        title: 'Integração Asaas',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _SimpleSheet(
        title: 'Integração Asaas',
        child: Text('Não foi possível carregar: ${friendlyError(error)}'),
      ),
      data: (config) => _AsaasConfigForm(config: config),
    );
  }
}

class _AsaasConfigForm extends ConsumerStatefulWidget {
  const _AsaasConfigForm({required this.config});

  final AsaasConfig config;

  @override
  ConsumerState<_AsaasConfigForm> createState() => _AsaasConfigFormState();
}

class _AsaasConfigFormState extends ConsumerState<_AsaasConfigForm> {
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
        AsaasSetupGuide(videoUrl: widget.config.tutorialVideoUrl),
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

/// Abre as preferências de notificações automáticas (WhatsApp) do cliente.
Future<void> showNotificationPreferencesSheet(BuildContext context) {
  return showAppFormSheet(context, const _NotificationPreferencesSheet());
}

class _NotificationPreferencesSheet extends ConsumerStatefulWidget {
  const _NotificationPreferencesSheet();

  @override
  ConsumerState<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends ConsumerState<_NotificationPreferencesSheet> {
  NotificationPreferences? _form;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(notificationSettingsProvider.future).then((settings) {
      if (mounted) setState(() => _form = settings.preferences);
    });
  }

  NotificationPreferences _syncEnabled(NotificationPreferences value) {
    return value.copyWith(
      whatsappEnabled:
          value.reminderBeforeEnabled ||
          value.onDueEnabled ||
          value.overdueEnabled,
    );
  }

  void _update(NotificationPreferences value) {
    setState(() => _form = _syncEnabled(value));
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
      loading: () => const _SimpleSheet(
        title: 'Notificações automáticas',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _SimpleSheet(
        title: 'Notificações automáticas',
        child: Text('Não foi possível carregar: ${friendlyError(error)}'),
      ),
      data: (settings) {
        final form = _form ?? settings.preferences;
        final limits = settings.limits;
        return AppFormSheet(
          title: 'Notificações automáticas',
          subtitle:
              'Avisos enviados ao cliente pelo WhatsApp oficial da plataforma.',
          formKey: GlobalKey<FormState>(),
          busy: _busy,
          saveLabel: 'Salvar preferências',
          onSave: _save,
          children: [
            if (!limits.integrationEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'O envio pelo WhatsApp oficial está temporariamente indisponível.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: form.reminderBeforeEnabled,
              onChanged: (value) =>
                  _update(form.copyWith(reminderBeforeEnabled: value)),
              title: const Text('Antes do vencimento'),
              subtitle: Text(
                'Avisa até ${form.reminderBeforeDays} dia(s) antes (máx. ${limits.maxReminderDaysBefore}).',
              ),
            ),
            if (limits.maxReminderDaysBefore > 1)
              Slider(
                value: form.reminderBeforeDays
                    .clamp(1, limits.maxReminderDaysBefore)
                    .toDouble(),
                min: 1,
                max: limits.maxReminderDaysBefore.toDouble(),
                divisions: limits.maxReminderDaysBefore - 1,
                label: '${form.reminderBeforeDays} dia(s)',
                onChanged: form.reminderBeforeEnabled
                    ? (value) => _update(
                        form.copyWith(reminderBeforeDays: value.round()),
                      )
                    : null,
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
              subtitle: Text(
                'Relembra até ${form.overdueDays} dia(s) depois (máx. ${limits.maxOverdueDays}).',
              ),
            ),
            if (limits.maxOverdueDays > 1)
              Slider(
                value: form.overdueDays
                    .clamp(1, limits.maxOverdueDays)
                    .toDouble(),
                min: 1,
                max: limits.maxOverdueDays.toDouble(),
                divisions: limits.maxOverdueDays - 1,
                label: '${form.overdueDays} dia(s)',
                onChanged: form.overdueEnabled
                    ? (value) =>
                          _update(form.copyWith(overdueDays: value.round()))
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _SimpleSheet extends StatelessWidget {
  const _SimpleSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: title,
      formKey: GlobalKey<FormState>(),
      onSave: () async => Navigator.of(context).pop(),
      saveLabel: 'Fechar',
      children: [child],
    );
  }
}
