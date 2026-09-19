import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../models/admin.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/empty_state.dart';
import 'admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(adminDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminDataProvider),
        ),
        data: (data) {
          final query = _query.trim().toLowerCase();
          final users = data.users.where((user) {
            if (query.isEmpty) return true;
            return user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query) ||
                (user.company?.toLowerCase().contains(query) ?? false);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome, e-mail ou empresa',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Nenhum usuário encontrado',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(adminDataProvider);
                          try {
                            await ref.read(adminDataProvider.future);
                          } catch (_) {}
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _AdminUserTile(
                            key: ValueKey(users[index].id),
                            user: users[index],
                            planName:
                                data.planById(users[index].planId)?.name ??
                                'Sem plano',
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminUserTile extends ConsumerStatefulWidget {
  const _AdminUserTile({super.key, required this.user, required this.planName});

  final AdminUser user;
  final String planName;

  @override
  ConsumerState<_AdminUserTile> createState() => _AdminUserTileState();
}

class _AdminUserTileState extends ConsumerState<_AdminUserTile> {
  bool _busy = false;

  Future<void> _toggleActive(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateProfile(userId: widget.user.id, active: value);
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

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final planName = widget.planName;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/more/admin/users/${user.id}'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name.isEmpty ? user.email : user.name,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isSuperadmin)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      user.email,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(label: planName, color: AppColors.primary),
                        _Tag(
                          label:
                              user.subscriptionStatus?.label ??
                              'Sem assinatura',
                          color: user.subscriptionStatus?.name == 'ativa'
                              ? AppColors.success
                              : AppColors.mutedForeground,
                        ),
                        _Tag(
                          label: '${user.clients} clientes',
                          color: AppColors.info,
                        ),
                        _Tag(
                          label: '${user.whatsappSent} WhatsApp',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Switch(
              value: user.active,
              onChanged: _busy ? null : _toggleActive,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

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
