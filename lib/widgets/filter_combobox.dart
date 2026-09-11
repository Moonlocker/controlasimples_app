import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class FilterOption<T> {
  const FilterOption({required this.value, required this.label, this.subtitle});

  final T value;
  final String label;
  final String? subtitle;
}

/// Botão compacto que abre uma lista pesquisável de opções (combobox de filtro).
class FilterCombobox<T> extends StatelessWidget {
  const FilterCombobox({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint = 'Selecionar',
    this.allLabel = 'Todos',
    this.icon = Icons.filter_list,
    this.width,
  });

  final List<FilterOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String hint;
  final String allLabel;
  final IconData icon;
  final double? width;

  String get _label {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return hint;
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_ComboboxResult<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ComboboxSheet<T>(
        options: options,
        value: value,
        allLabel: allLabel,
        hint: hint,
      ),
    );
    if (result != null) onChanged(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = value != null;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.mutedForeground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.foreground : AppColors.mutedForeground,
                      ),
                ),
              ),
              const Icon(Icons.expand_more, size: 18, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboboxResult<T> {
  const _ComboboxResult(this.value);

  final T? value;
}

class _ComboboxSheet<T> extends StatefulWidget {
  const _ComboboxSheet({
    required this.options,
    required this.value,
    required this.allLabel,
    required this.hint,
  });

  final List<FilterOption<T>> options;
  final T? value;
  final String allLabel;
  final String hint;

  @override
  State<_ComboboxSheet<T>> createState() => _ComboboxSheetState<T>();
}

class _ComboboxSheetState<T> extends State<_ComboboxSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.options
        .where((option) =>
            query.isEmpty ||
            option.label.toLowerCase().contains(query) ||
            (option.subtitle?.toLowerCase().contains(query) ?? false))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text(
                widget.hint,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.clear_all, color: AppColors.mutedForeground),
                    title: Text(widget.allLabel),
                    selected: widget.value == null,
                    onTap: () => Navigator.of(context).pop(_ComboboxResult<T>(null)),
                  ),
                  const Divider(height: 1),
                  for (final option in filtered)
                    ListTile(
                      title: Text(option.label),
                      subtitle: option.subtitle == null ? null : Text(option.subtitle!),
                      selected: option.value == widget.value,
                      trailing: option.value == widget.value
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () =>
                          Navigator.of(context).pop(_ComboboxResult<T>(option.value)),
                    ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Nada encontrado')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
