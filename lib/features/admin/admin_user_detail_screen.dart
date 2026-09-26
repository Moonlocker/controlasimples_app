import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/error_messages.dart';
import '../../models/admin.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';

class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuário')),
      body: dataAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminDataProvider),
        ),
        data: (data) {
          AdminUser? user;
          for (final candidate in data.users) {
            if (candidate.id == userId) user = candidate;
          }
          if (user == null) {
            return const EmptyState(title: 'Usuário não encontrado');
          }
          final currentUserId = ref.watch(currentUserIdProvider);
          return _UserDetail(
            data: data,
            user: user,
            isSelf: currentUserId == user.id,
          );
        },
      ),
    );
  }
}

class _UserDetail extends ConsumerStatefulWidget {
  const _UserDetail({
    required this.data,
    required this.user,
    required this.isSelf,
  });

  final AdminData data;
  final AdminUser user;
  final bool isSelf;

  @override
  ConsumerState<_UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends ConsumerState<_UserDetail> {
  late final TextEditingController _quota;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _quota = TextEditingController(
      text: widget.user.whatsappQuotaOverride?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _UserDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.user.whatsappQuotaOverride?.toString() ?? '';
    if (oldWidget.user.whatsappQuotaOverride !=
            widget.user.whatsappQuotaOverride &&
        _quota.text != incoming) {
      _quota.text = incoming;
    }
  }

  @override
  void dispose() {
    _quota.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(adminDataProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final user = widget.user;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Excluir ${user.name.isEmpty ? user.email : user.name}?',
      message:
          'A conta e todos os registros (clientes, serviços, cobranças, '
          'pagamentos, orçamentos, mensagens e assinatura) serão removidos '
          'permanentemente. Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir definitivamente',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).deleteUser(user.id);
      ref.invalidate(adminDataProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Usuário excluído.')));
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
    final repository = ref.read(adminRepositoryProvider);
    final user = widget.user;
    final data = widget.data;
    final messagesAsync = ref.watch(adminMessagesProvider(user.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                _initials(user.name.isEmpty ? user.email : user.name),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isEmpty ? user.email : user.name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (user.isSuperadmin)
                        _Tag('Superadmin', AppColors.primary),
                      _Tag(
                        user.active ? 'Ativo' : 'Bloqueado',
                        user.active ? AppColors.success : AppColors.danger,
                      ),
                      if ((user.company ?? '').isNotEmpty)
                        _Tag(user.company!, AppColors.info),
                      if ((user.phone ?? '').isNotEmpty)
                        _Tag(user.phone!, AppColors.mutedForeground),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              label: 'Clientes',
              value: '${user.clients}',
              tone: AppColors.info,
            ),
            StatCard(
              label: 'Cobranças',
              value: '${user.charges}',
              tone: AppColors.warning,
            ),
            StatCard(
              label: 'Recebido',
              value: brl(user.received),
              tone: AppColors.success,
            ),
            StatCard(
              label: 'WhatsApp no mês',
              value: '${user.whatsappSent}',
              tone: AppColors.primary,
            ),
          ],
        ),
        if ((user.document ?? '').isNotEmpty ||
            user.createdAt != null ||
            (user.asaasInvoiceUrl ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Dados da conta',
            child: Column(
              children: [
                if ((user.document ?? '').isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('CPF/CNPJ'),
                    trailing: Text(user.document!),
                  ),
                if (user.createdAt != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Cliente desde'),
                    trailing: Text(formatDate(user.createdAt!)),
                  ),
                if ((user.asaasInvoiceUrl ?? '').isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Fatura Asaas'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () => launchUrl(Uri.parse(user.asaasInvoiceUrl!)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'Assinatura',
          child: Column(
            children: [
              DropdownButtonFormField<String?>(
                key: ValueKey('plan-${user.planId}'),
                initialValue: user.planId,
                decoration: const InputDecoration(labelText: 'Plano'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem plano')),
                  for (final plan in data.plans)
                    DropdownMenuItem(value: plan.id, child: Text(plan.name)),
                ],
                onChanged: (value) {
                  if (_busy) return;
                  _run(
                    () => repository.updateSubscription(
                      userId: user.id,
                      planId: value,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<SubscriptionStatus>(
                key: ValueKey('status-${user.subscriptionStatus}'),
                initialValue:
                    user.subscriptionStatus ?? SubscriptionStatus.trial,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: [
                  for (final status in SubscriptionStatus.values)
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: (value) {
                  if (value == null || _busy) return;
                  _run(
                    () => repository.updateSubscription(
                      userId: user.id,
                      status: value,
                    ),
                  );
                },
              ),
              if (user.currentPeriodEnd != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Válido até ${formatDate(user.currentPeriodEnd!)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ],
              if (user.asaasStatus != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Asaas: ${user.asaasStatus}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedForeground),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Acesso',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user.active,
                onChanged: (value) {
                  if (_busy) return;
                  _run(
                    () => repository.updateProfile(
                      userId: user.id,
                      active: value,
                    ),
                  );
                },
                title: const Text('Acesso liberado'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user.isSuperadmin,
                onChanged: widget.isSelf
                    ? null
                    : (value) {
                        if (_busy) return;
                        _run(() => repository.setSuperadmin(user.id, value));
                      },
                title: const Text('Superadministrador'),
                subtitle: widget.isSelf
                    ? const Text('Você não pode remover o próprio acesso.')
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Limite de WhatsApp (mês)',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quota,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cota (vazio = padrão do plano)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () {
                  if (_busy) return;
                  _run(
                    () => repository.setWhatsappQuota(
                      user.id,
                      _quota.text.trim().isEmpty
                          ? null
                          : int.tryParse(_quota.text.trim()),
                    ),
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
        if (!widget.isSelf) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Zona de perigo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Exclui o usuário e todos os registros (clientes, cobranças, '
                  'pagamentos, orçamentos, mensagens e assinatura) permanentemente.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Excluir usuário'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Mensagens recentes',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        messagesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Text(friendlyError(error)),
          data: (messages) => messages.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_outlined,
                  title: 'Nenhuma mensagem',
                )
              : Column(
                  children: [
                    for (final message in messages.take(20))
                      Container(
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
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0]).join();
  return letters.isEmpty ? '?' : letters.toUpperCase();
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
