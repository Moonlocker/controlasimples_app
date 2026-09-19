import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/error_messages.dart';
import '../../models/plan.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/app_form_sheet.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/money_field.dart';
import 'admin_providers.dart';

class AdminPlansScreen extends ConsumerWidget {
  const AdminPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showAppFormSheet(context, const _PlanFormSheet()),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminDataProvider),
        ),
        data: (data) {
          if (data.plans.isEmpty) {
            return const EmptyState(
              icon: Icons.workspace_premium_outlined,
              title: 'Nenhum plano',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminDataProvider);
              try {
                await ref.read(adminDataProvider.future);
              } catch (_) {}
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: data.plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = data.plans[index];
                final subscribers = data.users
                    .where((user) => user.planId == plan.id)
                    .length;
                return Container(
                  key: ValueKey(plan.id),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: plan.highlighted
                          ? AppColors.primary
                          : AppColors.border,
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
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            plan.price <= 0
                                ? 'Grátis'
                                : '${brl(plan.price)}/mês',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Switch(
                            value: plan.active,
                            onChanged: (value) async {
                              try {
                                await ref
                                    .read(adminRepositoryProvider)
                                    .setPlanActive(plan.id, value);
                                ref.invalidate(adminDataProvider);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(friendlyError(error)),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      if (plan.description.isNotEmpty)
                        Text(
                          plan.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      if (plan.features.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          plan.features.take(4).join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '$subscribers assinante(s)',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => showAppFormSheet(
                              context,
                              _PlanFormSheet(plan: plan),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            onPressed: () async {
                              final confirmed = await showConfirmDialog(
                                context,
                                title: 'Excluir plano',
                                message: 'Esta ação não pode ser desfeita.',
                                confirmLabel: 'Excluir',
                                destructive: true,
                              );
                              if (!confirmed) return;
                              try {
                                await ref
                                    .read(adminRepositoryProvider)
                                    .deletePlan(plan.id);
                                ref.invalidate(adminDataProvider);
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(friendlyError(error)),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlanFormSheet extends ConsumerStatefulWidget {
  const _PlanFormSheet({this.plan});

  final Plan? plan;

  @override
  ConsumerState<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends ConsumerState<_PlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _sortOrder;
  late final TextEditingController _maxClients;
  late final TextEditingController _maxCharges;
  late final TextEditingController _maxWhatsapp;
  late final TextEditingController _features;
  late bool _allowAsaas;
  late bool _allowWhatsapp;
  late bool _highlighted;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name = TextEditingController(text: plan?.name ?? '');
    _slug = TextEditingController(text: plan?.slug ?? '');
    _description = TextEditingController(text: plan?.description ?? '');
    _price = TextEditingController(
      text: CurrencyInputFormatter.fromDouble(plan?.price ?? 0),
    );
    _sortOrder = TextEditingController(text: (plan?.sortOrder ?? 0).toString());
    _maxClients = TextEditingController(
      text: plan?.maxClients?.toString() ?? '',
    );
    _maxCharges = TextEditingController(
      text: plan?.maxChargesMonth?.toString() ?? '',
    );
    _maxWhatsapp = TextEditingController(
      text: plan?.maxWhatsappMonth?.toString() ?? '',
    );
    _features = TextEditingController(text: plan?.features.join('\n') ?? '');
    _allowAsaas = plan?.allowAsaasIntegration ?? true;
    _allowWhatsapp = plan?.allowWhatsappNotifications ?? true;
    _highlighted = plan?.highlighted ?? false;
    _active = plan?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _price.dispose();
    _sortOrder.dispose();
    _maxClients.dispose();
    _maxCharges.dispose();
    _maxWhatsapp.dispose();
    _features.dispose();
    super.dispose();
  }

  int? _parseOptional(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .savePlan(
            id: widget.plan?.id,
            name: _name.text.trim(),
            slug: _slug.text.trim(),
            description: _description.text.trim(),
            priceCents: (CurrencyInputFormatter.parse(_price.text) * 100)
                .round(),
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            maxClients: _parseOptional(_maxClients.text),
            maxChargesMonth: _parseOptional(_maxCharges.text),
            maxWhatsappMonth: _parseOptional(_maxWhatsapp.text),
            allowAsaasIntegration: _allowAsaas,
            allowWhatsappNotifications: _allowWhatsapp,
            features: _features.text
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty)
                .toList(),
            highlighted: _highlighted,
            active: _active,
          );
      ref.invalidate(adminDataProvider);
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
    return AppFormSheet(
      title: widget.plan == null ? 'Novo plano' : 'Editar plano',
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
          controller: _slug,
          decoration: const InputDecoration(labelText: 'Slug'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Informe o slug' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _description,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Descrição'),
        ),
        const SizedBox(height: 14),
        MoneyField(controller: _price, label: 'Preço mensal'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _maxClients,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Máx. clientes'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _maxCharges,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Máx. cobranças/mês',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _maxWhatsapp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Máx. WhatsApp/mês',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ordem'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _features,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Recursos (um por linha)',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _allowAsaas,
          onChanged: (value) => setState(() => _allowAsaas = value),
          title: const Text('Permitir integração Asaas'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _allowWhatsapp,
          onChanged: (value) => setState(() => _allowWhatsapp = value),
          title: const Text('Permitir notificações WhatsApp'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _highlighted,
          onChanged: (value) => setState(() => _highlighted = value),
          title: const Text('Destacado'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (value) => setState(() => _active = value),
          title: const Text('Ativo'),
        ),
      ],
    );
  }
}
