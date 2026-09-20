import 'package:flutter/material.dart';

import '../theme.dart';
import 'form_kit.dart';

class FilterOption {
  const FilterOption(this.value, this.label);

  final String value;
  final String label;
}

/// One dropdown filter of a [CrudList], declared per screen.
///
/// - [ListFilter.byValue] compares a field of the item with the picked value.
///   Omit `options` to derive them from the loaded items (distinct values).
/// - [ListFilter.custom] takes a test function, for computed conditions.
class ListFilter<T> {
  const ListFilter._(
    this.label,
    this._options,
    this._valueOf,
    this._test, [
    this._labelOf,
  ]);

  factory ListFilter.byValue({
    required String label,
    required String Function(T item) valueOf,
    List<FilterOption>? options,
    String Function(String value)? labelOf,
  }) => ListFilter._(label, options, valueOf, null, labelOf);

  factory ListFilter.custom({
    required String label,
    required List<FilterOption> options,
    required bool Function(T item, String value) test,
  }) => ListFilter._(label, options, null, test);

  final String label;
  final List<FilterOption>? _options;
  final String Function(T item)? _valueOf;
  final bool Function(T item, String value)? _test;
  final String Function(String value)? _labelOf;

  List<FilterOption> optionsFor(List<T> items) {
    if (_options != null) return _options;
    final values = {
      for (final i in items) _valueOf!(i),
    }..remove('');
    final sorted = values.toList()..sort();
    return [for (final v in sorted) FilterOption(v, _labelOf?.call(v) ?? v)];
  }

  bool matches(T item, String value) =>
      _test != null ? _test(item, value) : _valueOf!(item) == value;
}

/// Lower-cases and strips Portuguese accents so "Açúcar" matches "acucar".
String normalizeSearch(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final out = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    out.write(i < 0 ? c : to[i]);
  }
  return out.toString();
}

/// Search box plus the dropdown filters of a list.
class ListFilterBar<T> extends StatelessWidget {
  const ListFilterBar({
    super.key,
    required this.controller,
    required this.onQuery,
    required this.filters,
    required this.items,
    required this.selected,
    required this.onFilter,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final List<ListFilter<T>> filters;
  final List<T> items;

  /// Picked value per filter index; missing means "Todos".
  final Map<int, String> selected;
  final void Function(int index, String value) onFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar',
              prefixIcon: const Icon(Icons.search, color: erpMuted),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpar',
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < filters.length; i++) ...[
                    SizedBox(
                      width: 160,
                      child: ErpDropdown<String>(
                        label: filters[i].label,
                        value: selected[i] ?? '',
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Todos')),
                          for (final o in filters[i].optionsFor(items))
                            DropdownMenuItem(value: o.value, child: Text(o.label)),
                        ],
                        onChanged: (v) => onFilter(i, v ?? ''),
                      ),
                    ),
                    if (i < filters.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
