import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/quote.dart';
import '../../repositories/quotes_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'business_form_sheet.dart';
import 'quote_pdf.dart';
import 'quotes_providers.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesProvider);
    final workspace = ref.watch(workspaceProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamentos'),
        actions: [
          IconButton(
            tooltip: 'Personalizar (logo/empresa)',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => showBusinessFormSheet(context, ref),
          ),
          IconButton(
            tooltip: 'Novo orçamento',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/more/quotes/new'),
          ),
        ],
      ),
      body: quotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(quotesProvider),
        ),
        data: (quotes) {
          if (quotes.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'Nenhum orçamento',
              description:
                  'Crie o primeiro orçamento e envie em PDF para o cliente.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(quotesProvider);
              try {
                await ref.read(quotesProvider.future);
              } catch (_) {}
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: quotes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return _QuoteTile(
                  quote: quote,
                  clientName: workspace?.clientName(quote.clientId) ?? '—',
                  onTap: () => context.push('/more/quotes/${quote.id}'),
                  onPdf: () => previewQuotePdf(context, ref, quote),
                  onChanged: () => ref.invalidate(quotesProvider),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _QuoteTile extends ConsumerWidget {
  const _QuoteTile({
    required this.quote,
    required this.clientName,
    required this.onTap,
    required this.onPdf,
    required this.onChanged,
  });

  final Quote quote;
  final String clientName;
  final VoidCallback onTap;
  final VoidCallback onPdf;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${quote.number} · ${quote.title}',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  brl(quote.total),
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                  onSelected: (value) async {
                    final repository = ref.read(quotesRepositoryProvider);
                    if (value.startsWith('status:')) {
                      await repository.setStatus(
                        quote.id,
                        QuoteStatus.fromWire(value.substring(7)),
                      );
                      onChanged();
                    } else if (value == 'pdf') {
                      onPdf();
                    } else if (value == 'duplicate') {
                      context.push('/more/quotes/new', extra: quote);
                    } else if (value == 'delete') {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Excluir orçamento',
                        message: 'Esta ação não pode ser desfeita.',
                        confirmLabel: 'Excluir',
                        destructive: true,
                      );
                      if (!confirmed) return;
                      await repository.delete(quote.id);
                      onChanged();
                    }
                  },
                  itemBuilder: (context) => [
                    for (final status in QuoteStatus.values)
                      PopupMenuItem(
                        value: 'status:${status.wire}',
                        child: Text(
                          'Marcar como ${status.label.toLowerCase()}',
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'pdf', child: Text('Gerar PDF')),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicar'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              clientName,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusPill(
                  label: quote.status.label,
                  tone: quoteStatusTone(quote.status),
                  icon: quoteStatusIcon(quote.status),
                  compact: true,
                ),
                const Spacer(),
                Text(
                  formatDate(quote.issuedOn),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
