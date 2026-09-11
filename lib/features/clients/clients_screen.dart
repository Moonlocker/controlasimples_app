import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/derive.dart';
import '../../core/utils/formatters.dart';
import '../../models/client.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';
import 'client_form_sheet.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(workspaceProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClientForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo cliente'),
      ),
      body: SafeArea(
        child: workspaceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(workspaceProvider),
          ),
          data: (workspace) {
            final query = _query.trim().toLowerCase();
            final clients = workspace.clients
                .where((client) => query.isEmpty || client.name.toLowerCase().contains(query))
                .toList();
            final pendingByClient = _pendingByClient(workspace);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ScreenHeader(
                        title: 'Clientes',
                        description: 'Contatos e situação financeira de cada cliente.',
                        leading: BrandBadge(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar cliente',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: clients.isEmpty
                      ? EmptyState(
                          icon: Icons.people_outline,
                          title: query.isEmpty ? 'Nenhum cliente cadastrado' : 'Nada encontrado',
                          description: query.isEmpty
                              ? 'Cadastre o primeiro cliente para começar.'
                              : 'Tente buscar por outro nome.',
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(workspaceProvider);
                            try {
                              await ref.read(workspaceProvider.future);
                            } catch (_) {}
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: clients.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final client = clients[index];
                              return _ClientTile(
                                client: client,
                                pending: pendingByClient[client.id] ?? 0,
                                onTap: () => context.push('/clients/${client.id}'),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, double> _pendingByClient(Workspace workspace) {
    final map = <String, double>{};
    for (final view in chargeViews(workspace)) {
      if (view.status == ChargeStatus.pendente || view.status == ChargeStatus.atrasado) {
        map.update(view.clientId, (value) => value + view.amount, ifAbsent: () => view.amount);
      }
    }
    return map;
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.pending, required this.onTap});

  final Client client;
  final double pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                initials(client.name),
                style: textTheme.labelLarge?.copyWith(
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          client.name,
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!client.active) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Inativo',
                            style: textTheme.labelSmall
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    client.phone ?? client.email ?? 'Sem contato',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  brl(pending),
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'em aberto',
                  style: textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
