import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import 'admin_providers.dart';

class AdminWhatsappScreen extends ConsumerWidget {
  const AdminWhatsappScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('WhatsApp'),
          actions: [
            IconButton(
              tooltip: 'Nova mensagem',
              icon: const Icon(Icons.send_outlined),
              onPressed: () => showAppFormSheet(context, const _SendWhatsappSheet()),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Conversas'),
              Tab(text: 'Histórico'),
              Tab(text: 'Consumo'),
              Tab(text: 'Configuração'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ConversationsTab(),
            _HistoryTab(),
            _UsageTab(),
            _ConfigTab(),
          ],
        ),
      ),
    );
  }
}

class _SendWhatsappSheet extends ConsumerStatefulWidget {
  const _SendWhatsappSheet({this.initialPhone, this.initialUserId});

  final String? initialPhone;
  final String? initialUserId;

  @override
  ConsumerState<_SendWhatsappSheet> createState() => _SendWhatsappSheetState();
}

class _SendWhatsappSheetState extends ConsumerState<_SendWhatsappSheet> {
  final _formKey = GlobalKey<FormState>();
  final _to = TextEditingController();
  final _body = TextEditingController();
  final _buttonUrl = TextEditingController();
  final _params = List.generate(4, (_) => TextEditingController());
  String? _userId;
  bool _template = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _to.text = widget.initialPhone ?? '';
    _userId = widget.initialUserId;
  }

  @override
  void dispose() {
    _to.dispose();
    _body.dispose();
    _buttonUrl.dispose();
    for (final controller in _params) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_userId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).sendWhatsappAdmin(
            to: _to.text.trim(),
            userId: _userId!,
            mode: _template ? 'modelo' : 'texto',
            body: _body.text.trim(),
            params: _params.map((controller) => controller.text.trim()).toList(),
            buttonUrl: _buttonUrl.text.trim().isEmpty ? null : _buttonUrl.text.trim(),
          );
      ref.invalidate(adminMessagesProvider(null));
      ref.invalidate(adminMessagesProvider(_userId));
      ref.invalidate(adminWhatsappOverviewProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem enviada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminDataProvider).value?.users ?? const [];
    final selectedUser =
        users.any((user) => user.id == _userId) ? _userId : null;
    return AppFormSheet(
      title: 'Nova mensagem',
      formKey: _formKey,
      busy: _busy,
      saveLabel: 'Enviar',
      onSave: _save,
      children: [
        TextFormField(
          controller: _to,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Telefone (com DDD)'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Informe o telefone' : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedUser,
          decoration: const InputDecoration(labelText: 'Conta responsável'),
          items: [
            for (final user in users)
              DropdownMenuItem(
                value: user.id,
                child: Text(user.name.isEmpty ? user.email : user.name),
              ),
          ],
          onChanged: (value) => setState(() => _userId = value),
          validator: (value) => value == null ? 'Selecione a conta' : null,
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Texto')),
            ButtonSegment(value: true, label: Text('Modelo')),
          ],
          selected: {_template},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => _template = value.first),
        ),
        const SizedBox(height: 14),
        if (!_template)
          TextFormField(
            controller: _body,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mensagem'),
            validator: (value) => _template || (value != null && value.trim().isNotEmpty)
                ? null
                : 'Escreva a mensagem',
          )
        else ...[
          for (var i = 0; i < _params.length; i++) ...[
            TextFormField(
              controller: _params[i],
              decoration: InputDecoration(labelText: _paramLabels[i]),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _buttonUrl,
            decoration: const InputDecoration(labelText: 'URL do botão (opcional)'),
          ),
        ],
      ],
    );
  }

  static const List<String> _paramLabels = [
    'Cliente (1)',
    'Descrição (2)',
    'Valor (3)',
    'Vencimento (4)',
  ];
}

class _Conversation {
  _Conversation({required this.phone, required this.messages, this.userId});

  final String phone;
  final List<WhatsappMessage> messages;
  final String? userId;

  WhatsappMessage get last => messages.first;
}

List<_Conversation> _groupConversations(List<WhatsappMessage> messages) {
  final map = <String, List<WhatsappMessage>>{};
  for (final message in messages) {
    final phone = (message.toPhone ?? message.fromPhone ?? '').trim();
    if (phone.isEmpty) continue;
    map.putIfAbsent(phone, () => []).add(message);
  }
  final result = map.entries.map((entry) {
    String? userId;
    for (final message in entry.value) {
      if (message.userId != null) {
        userId = message.userId;
        break;
      }
    }
    return _Conversation(phone: entry.key, messages: entry.value, userId: userId);
  }).toList();
  result.sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));
  return result;
}

class _ConversationsTab extends ConsumerWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(adminMessagesProvider(null));
    final users = ref.watch(adminDataProvider).value?.users ?? const [];

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(adminMessagesProvider(null)),
      ),
      data: (messages) {
        final conversations = _groupConversations(messages);
        if (conversations.isEmpty) {
          return const EmptyState(icon: Icons.forum_outlined, title: 'Nenhuma conversa');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            String accountName = '';
            for (final user in users) {
              if (user.id == conversation.userId) {
                accountName = user.name.isEmpty ? user.email : user.name;
                break;
              }
            }
            return _ConversationTile(
              conversation: conversation,
              accountName: accountName,
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.accountName});

  final _Conversation conversation;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    final last = conversation.last;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ConversationSheet(
          conversation: conversation,
          accountName: accountName,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                    conversation.phone,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatDate(last.createdAt),
                  style: textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
            if (accountName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Conta: $accountName',
                style: textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              last.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSheet extends StatelessWidget {
  const _ConversationSheet({required this.conversation, required this.accountName});

  final _Conversation conversation;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    final ordered = conversation.messages.reversed.toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.phone,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (accountName.isNotEmpty)
                        Text(
                          'Conta: $accountName',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ordered.length,
              itemBuilder: (context, index) => _ConversationBubble(message: ordered[index]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: () => showAppFormSheet(
                  context,
                  _SendWhatsappSheet(
                    initialPhone: conversation.phone,
                    initialUserId: conversation.userId,
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Responder'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({required this.message});

  final WhatsappMessage message;

  @override
  Widget build(BuildContext context) {
    final inbound = message.direction == 'entrada';
    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: inbound ? AppColors.muted : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              inbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(message.body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              '${formatDate(message.createdAt)} · ${message.status}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(adminWhatsappOverviewProvider);
    final messagesAsync = ref.watch(adminMessagesProvider(null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        overviewAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) => Text('$error'),
          data: (overview) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatCard(label: 'Enviadas no mês', value: '${overview.sentTotal}',
                  tone: AppColors.success),
              StatCard(label: 'Falhas', value: '${overview.failedTotal}', tone: AppColors.danger),
              StatCard(label: 'Usuários ativos', value: '${overview.users.where((u) => u.sent > 0).length}',
                  tone: AppColors.info),
              StatCard(label: 'Custo estimado', value: brl(overview.costCents / 100),
                  tone: AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Mensagens recentes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: (messagesAsync.value ?? const []).isEmpty
                  ? null
                  : () => _exportCsv(context, messagesAsync.value!),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Exportar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        messagesAsync.when(
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('$error'),
          data: (messages) => messages.isEmpty
              ? const EmptyState(icon: Icons.chat_outlined, title: 'Nenhuma mensagem')
              : Column(
                  children: [
                    for (final message in messages)
                      _MessageTile(message: message),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, List<WhatsappMessage> messages) async {
    final buffer = StringBuffer('Data;Direcao;Telefone;Conta;Status;Tipo;Custo;Erro;Mensagem\n');
    for (final message in messages) {
      buffer.writeln([
        message.createdAt.toIso8601String(),
        message.direction,
        message.toPhone ?? message.fromPhone ?? '',
        message.userId ?? '',
        message.status,
        message.kind ?? '',
        (message.costCents / 100).toStringAsFixed(2).replaceAll('.', ','),
        (message.error ?? '').replaceAll('\n', ' ').replaceAll(';', ','),
        message.body.replaceAll('\n', ' ').replaceAll(';', ','),
      ].join(';'));
    }
    final file = XFile.fromData(
      utf8.encode(buffer.toString()),
      name: 'whatsapp.csv',
      mimeType: 'text/csv',
    );
    try {
      await SharePlus.instance.share(
        ShareParams(files: [file], subject: 'Histórico WhatsApp'),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final WhatsappMessage message;

  @override
  Widget build(BuildContext context) {
    final success = message.status == 'enviado';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.direction == 'entrada' ? Icons.call_received : Icons.call_made,
                size: 14,
                color: message.direction == 'entrada' ? AppColors.info : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message.toPhone ?? message.fromPhone ?? '—',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                message.status,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: success ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            message.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text(
            '${formatDate(message.createdAt)} · ${message.kind ?? ''}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _UsageTab extends ConsumerWidget {
  const _UsageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(adminWhatsappOverviewProvider);
    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(adminWhatsappOverviewProvider),
      ),
      data: (overview) {
        if (overview.users.isEmpty) {
          return const EmptyState(icon: Icons.people_outline, title: 'Nenhuma conta');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: overview.users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _UsageTile(row: overview.users[index]),
        );
      },
    );
  }
}

class _UsageTile extends ConsumerWidget {
  const _UsageTile({required this.row});

  final WhatsappOverviewRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = row.quota == 0 ? 0.0 : (row.sent / row.quota).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
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
                  row.name.isEmpty ? row.email : row.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => _editQuota(context, ref),
                child: const Text('Editar cota'),
              ),
            ],
          ),
          Text(
            '${row.sent} de ${row.quota} mensagens'
            '${row.override == null ? '' : ' · cota personalizada: ${row.override}'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.muted,
              color: progress >= 1 ? AppColors.danger : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editQuota(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: row.override?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cota de ${row.name.isEmpty ? row.email : row.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mensagens por mês',
            hintText: 'Deixe vazio para usar o padrão do plano',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .setWhatsappQuota(row.userId, value.isEmpty ? null : int.tryParse(value));
      ref.invalidate(adminWhatsappOverviewProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ConfigTab extends ConsumerWidget {
  const _ConfigTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(adminWhatsappConfigProvider);
    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView(
        error: error,
        onRetry: () => ref.invalidate(adminWhatsappConfigProvider),
      ),
      data: (config) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SectionCard(
            title: 'Configuração',
            action: TextButton(
              onPressed: () =>
                  showAppFormSheet(context, _WhatsappConfigFormSheet(config: config)),
              child: const Text('Editar'),
            ),
            child: Column(
              children: [
                _row('Situação', config.enabled ? 'Ativado' : 'Desativado'),
                _row('Phone Number ID', config.phoneNumberId ?? '—'),
                _row('Conta comercial', config.businessAccountId ?? '—'),
                _row('Token', config.maskedToken ?? (config.hasToken ? 'Configurado' : '—')),
                _row('Template', '${config.templateName} (${config.templateLanguage})'),
                _row('Cota padrão', '${config.defaultMonthlyQuota}'),
                _row('Custo por mensagem', brl(config.costPerMessageCents / 100)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _WhatsappTestButton(),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _WhatsappTestButton extends ConsumerStatefulWidget {
  const _WhatsappTestButton();

  @override
  ConsumerState<_WhatsappTestButton> createState() => _WhatsappTestButtonState();
}

class _WhatsappTestButtonState extends ConsumerState<_WhatsappTestButton> {
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
                final result = await ref.read(adminRepositoryProvider).testWhatsappAdmin();
                messenger.showSnackBar(
                  SnackBar(content: Text(result.message.isEmpty ? 'Testado.' : result.message)),
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

class _WhatsappConfigFormSheet extends ConsumerStatefulWidget {
  const _WhatsappConfigFormSheet({required this.config});

  final WhatsappAdminConfig config;

  @override
  ConsumerState<_WhatsappConfigFormSheet> createState() => _WhatsappConfigFormSheetState();
}

class _WhatsappConfigFormSheetState extends ConsumerState<_WhatsappConfigFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberId = TextEditingController();
  final _businessAccountId = TextEditingController();
  final _accessToken = TextEditingController();
  final _verifyToken = TextEditingController();
  final _apiVersion = TextEditingController();
  final _templateName = TextEditingController();
  final _templateLanguage = TextEditingController();
  final _defaultQuota = TextEditingController();
  final _costPerMessage = TextEditingController();
  late bool _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _enabled = config.enabled;
    _phoneNumberId.text = config.phoneNumberId ?? '';
    _businessAccountId.text = config.businessAccountId ?? '';
    _apiVersion.text = config.apiVersion;
    _templateName.text = config.templateName;
    _templateLanguage.text = config.templateLanguage;
    _defaultQuota.text = config.defaultMonthlyQuota.toString();
    _costPerMessage.text = config.costPerMessageCents.toString();
  }

  @override
  void dispose() {
    _phoneNumberId.dispose();
    _businessAccountId.dispose();
    _accessToken.dispose();
    _verifyToken.dispose();
    _apiVersion.dispose();
    _templateName.dispose();
    _templateLanguage.dispose();
    _defaultQuota.dispose();
    _costPerMessage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).saveWhatsappAdminConfig(
            enabled: _enabled,
            phoneNumberId: _phoneNumberId.text.trim(),
            businessAccountId: _businessAccountId.text.trim(),
            accessToken: _accessToken.text.trim().isEmpty ? null : _accessToken.text.trim(),
            verifyToken: _verifyToken.text.trim().isEmpty ? null : _verifyToken.text.trim(),
            apiVersion: _apiVersion.text.trim(),
            templateName: _templateName.text.trim(),
            templateLanguage: _templateLanguage.text.trim(),
            defaultMonthlyQuota: int.tryParse(_defaultQuota.text.trim()) ?? 0,
            costPerMessageCents: int.tryParse(_costPerMessage.text.trim()) ?? 0,
          );
      ref.invalidate(adminWhatsappConfigProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Configuração do WhatsApp',
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
        TextFormField(
          controller: _phoneNumberId,
          decoration: const InputDecoration(labelText: 'Phone Number ID'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _businessAccountId,
          decoration: const InputDecoration(labelText: 'WhatsApp Business Account ID'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _accessToken,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Access token',
            hintText: widget.config.hasToken ? 'Deixe vazio para manter' : null,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _verifyToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Verify token'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _apiVersion,
          decoration: const InputDecoration(labelText: 'Versão da API'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _templateName,
          decoration: const InputDecoration(labelText: 'Nome do template'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _templateLanguage,
          decoration: const InputDecoration(labelText: 'Idioma do template'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _defaultQuota,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cota padrão/mês'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _costPerMessage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Custo (centavos)'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
