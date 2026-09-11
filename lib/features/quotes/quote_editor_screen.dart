import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../models/quote.dart';
import '../../repositories/quotes_repository.dart';
import '../../repositories/workspace_providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/date_field.dart';
import '../../widgets/money_field.dart';
import '../auth/auth_providers.dart';
import 'quote_pdf.dart';
import 'quotes_providers.dart';

class QuoteEditorScreen extends ConsumerStatefulWidget {
  const QuoteEditorScreen({super.key, this.quoteId, this.duplicateFrom});

  final String? quoteId;
  final Quote? duplicateFrom;

  @override
  ConsumerState<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends ConsumerState<QuoteEditorScreen> {
  final _title = TextEditingController();
  final _number = TextEditingController();
  final _note = TextEditingController();
  final _discount = TextEditingController();

  final List<_ItemDraft> _items = [];
  String? _clientId;
  DateTime _issuedOn = DateTime.now();
  DateTime? _validUntil;
  QuoteStatus _status = QuoteStatus.rascunho;
  String _layout = 'moderno';
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _number.dispose();
    _note.dispose();
    _discount.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _initNew(int count) {
    final source = widget.duplicateFrom;
    _title.text = source?.title ?? 'Orçamento';
    _number.text = 'ORÇ-${(count + 1).toString().padLeft(4, '0')}';
    if (source != null) {
      _note.text = source.note ?? '';
      _discount.text = CurrencyInputFormatter.fromDouble(source.discount);
      _clientId = source.clientId;
      _validUntil = source.validUntil;
      _status = QuoteStatus.rascunho;
      _layout = source.layout;
      for (final item in source.items) {
        _items.add(_ItemDraft(description: item.description, qty: item.qty, price: item.price));
      }
    }
    if (_items.isEmpty) _items.add(_ItemDraft());
    _initialized = true;
  }

  void _load(Quote quote) {
    _title.text = quote.title;
    _number.text = quote.number;
    _note.text = quote.note ?? '';
    _discount.text = CurrencyInputFormatter.fromDouble(quote.discount);
    _clientId = quote.clientId;
    _issuedOn = quote.issuedOn;
    _validUntil = quote.validUntil;
    _status = quote.status;
    _layout = quote.layout;
    _items.clear();
    if (quote.items.isEmpty) {
      _items.add(_ItemDraft());
    } else {
      for (final item in quote.items) {
        _items.add(_ItemDraft(description: item.description, qty: item.qty, price: item.price));
      }
    }
    _initialized = true;
  }

  double get _subtotal => _items.fold(0, (total, item) => total + item.toItem().total);
  double get _discountValue => CurrencyInputFormatter.parse(_discount.text);
  double get _total => _subtotal - _discountValue;

  Quote _buildQuote() {
    return Quote(
      id: widget.quoteId ?? '',
      userId: '',
      clientId: _clientId ?? '',
      number: _number.text.trim(),
      title: _title.text.trim().isEmpty ? 'Orçamento' : _title.text.trim(),
      issuedOn: _issuedOn,
      validUntil: _validUntil,
      status: _status,
      layout: _layout,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      items: _items.map((item) => item.toItem()).where((item) => item.description.isNotEmpty).toList(),
      subtotal: _subtotal,
      discount: _discountValue,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o cliente do orçamento.')),
      );
      return;
    }
    final items =
        _items.map((item) => item.toItem()).where((item) => item.description.isNotEmpty).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um item.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(quotesRepositoryProvider).save(
            id: widget.quoteId,
            userId: userId,
            clientId: _clientId!,
            number: _number.text.trim(),
            title: _title.text.trim().isEmpty ? 'Orçamento' : _title.text.trim(),
            issuedOn: _issuedOn,
            validUntil: _validUntil,
            status: _status,
            layout: _layout,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            items: items,
            subtotal: _subtotal,
            discount: _discountValue,
          );
      ref.invalidate(quotesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesProvider);

    if (widget.quoteId == null) {
      if (!_initialized) _initNew(quotesAsync.value?.length ?? 0);
      return _form(context);
    }

    return quotesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AsyncErrorView(error: error, onRetry: () => ref.invalidate(quotesProvider)),
      ),
      data: (quotes) {
        if (!_initialized) {
          Quote? found;
          for (final quote in quotes) {
            if (quote.id == widget.quoteId) {
              found = quote;
              break;
            }
          }
          if (found == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Orçamento não encontrado')),
            );
          }
          _load(found);
        }
        return _form(context);
      },
    );
  }

  Widget _form(BuildContext context) {
    final clients = ref.watch(workspaceProvider).value?.clients ?? const [];
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quoteId == null ? 'Novo orçamento' : 'Editar orçamento'),
        actions: [
          IconButton(
            tooltip: 'Gerar PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => previewQuotePdf(context, ref, _buildQuote()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _clientId,
            decoration: const InputDecoration(labelText: 'Cliente'),
            items: [
              for (final client in clients)
                DropdownMenuItem(value: client.id, child: Text(client.name)),
            ],
            onChanged: (value) => setState(() => _clientId = value),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Número'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<QuoteStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Situação'),
                  items: [
                    for (final status in QuoteStatus.values)
                      DropdownMenuItem(value: status, child: Text(status.label)),
                  ],
                  onChanged: (value) => setState(() => _status = value ?? _status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DateField(
                  label: 'Emissão',
                  value: _issuedOn,
                  onChanged: (value) => setState(() => _issuedOn = value ?? _issuedOn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(
                  label: 'Validade',
                  value: _validUntil,
                  clearable: true,
                  onChanged: (value) => setState(() => _validUntil = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Modelo do PDF',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'moderno', label: Text('Moderno')),
                  ButtonSegment(value: 'classico', label: Text('Clássico')),
                ],
                selected: {_layout},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _layout = value.first),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Itens',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemDraft())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          for (var i = 0; i < _items.length; i++)
            _ItemEditor(
              key: ValueKey(_items[i]),
              draft: _items[i],
              canRemove: _items.length > 1,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _items.removeAt(i).dispose()),
            ),
          const SizedBox(height: 16),
          MoneyField(controller: _discount, label: 'Desconto', onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _totalRow(context, 'Subtotal', _subtotal),
                _totalRow(context, 'Desconto', -_discountValue),
                const Divider(height: 20),
                _totalRow(context, 'Total', _total, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar orçamento'),
          ),
        ),
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, double value, {bool bold = false}) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: bold ? AppColors.foreground : AppColors.mutedForeground,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value == 0 ? 'R\$ 0,00' : CurrencyInputFormatter.fromDouble(value), style: style),
        ],
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft({String description = '', double qty = 1, double price = 0})
      : descriptionController = TextEditingController(text: description),
        qtyController = TextEditingController(text: _formatQty(qty)),
        priceController = TextEditingController(text: CurrencyInputFormatter.fromDouble(price));

  final TextEditingController descriptionController;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }

  QuoteItem toItem() {
    return QuoteItem(
      description: descriptionController.text.trim(),
      qty: double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 1,
      price: CurrencyInputFormatter.parse(priceController.text),
    );
  }

  void dispose() {
    descriptionController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    super.key,
    required this.draft,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _ItemDraft draft;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: draft.descriptionController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Descrição do item'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: draft.qtyController,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qtd'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MoneyField(
                  controller: draft.priceController,
                  label: 'Valor unitário',
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
