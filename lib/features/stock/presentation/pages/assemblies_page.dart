import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../stock_providers.dart';

class AssembliesPage extends ConsumerWidget {
  const AssembliesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(assembliesProvider);
    return CrudList<Assembly>(
      value: items,
      onRefresh: () => ref.read(assembliesProvider.notifier).reload(),
      titleOf: (a) => a.name,
      subtitleOf: (a) => '${a.code} · custo ${brl(a.cost)} · sugerido ${brl(a.suggestedPrice)}',
      onCreate: () => pushForm(context, const _AssemblyForm()),
      onEdit: (a) => pushForm(context, _AssemblyForm(assembly: a)),
    );
  }
}

class _AssemblyForm extends ConsumerStatefulWidget {
  const _AssemblyForm({this.assembly});

  final Assembly? assembly;

  @override
  ConsumerState<_AssemblyForm> createState() => _AssemblyFormState();
}

class _AssemblyFormState extends ConsumerState<_AssemblyForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.assembly?.code ?? '');
  late final _name = TextEditingController(text: widget.assembly?.name ?? '');
  late final _margin = TextEditingController(text: '${widget.assembly?.marginPercent ?? 0}');
  late var _productId = widget.assembly?.productId ?? '';
  late final _items = List<AssemblyItem>.from(widget.assembly?.items ?? const []);
  var _itemProductId = '';
  var _role = 'COMPONENT';
  final _qty = TextEditingController(text: '1');
  var _draftKey = 0;
  var _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _margin.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.assembly == null ? 'Nova montagem' : 'Editar montagem',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpField('Código', _code, required: true),
            ErpField('Nome', _name, required: true),
            ErpDropdown<String>(
              label: 'Produto final',
              value: _productId.isEmpty ? null : _productId,
              items: [
                const DropdownMenuItem(value: '', child: Text('—')),
                ...products
                    .where((p) => p.kind == 'FINAL')
                    .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}'))),
              ],
              onChanged: (v) => setState(() => _productId = v ?? ''),
            ),
            ErpField('Margem %', _margin, keyboard: TextInputType.number),
            KeyedSubtree(
              key: ValueKey(_draftKey),
              child: Column(
                children: [
                  ErpDropdown<String>(
                    label: 'Item',
                    value: _itemProductId.isEmpty ? null : _itemProductId,
                    items: products
                        .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}')))
                        .toList(),
                    onChanged: (v) => setState(() => _itemProductId = v ?? ''),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qtd'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _role,
                          items: const [
                            DropdownMenuItem(value: 'COMPONENT', child: Text('Componente')),
                            DropdownMenuItem(value: 'SUPPORT', child: Text('Apoio')),
                          ],
                          onChanged: (v) => setState(() => _role = v ?? 'COMPONENT'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            LineItemsBar(
              count: _items.length,
              onAdd: _add,
              onOpen: () => pushForm(
                context,
                LineItemsPage<AssemblyItem>(
                  items: _items,
                  titleOf: (i) {
                    final p = products.where((x) => x.id == i.productId).firstOrNull;
                    return p == null ? i.productId : '${p.sku} — ${p.name}';
                  },
                  subtitleOf: (i) =>
                      '${i.quantity} · ${i.role == 'SUPPORT' ? 'Apoio' : 'Componente'}',
                  onDelete: (i) => setState(() => _items.removeAt(i)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _add() {
    if (_itemProductId.isEmpty) return;
    setState(() {
      _items.add(
        AssemblyItem(
          productId: _itemProductId,
          quantity: parseNum(_qty.text, 1),
          role: _role,
        ),
      );
      _itemProductId = '';
      _qty.text = '1';
      _role = 'COMPONENT';
      _draftKey++;
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(assembliesProvider.notifier).save(
            Assembly(
              id: widget.assembly?.id ?? '',
              code: _code.text.trim(),
              name: _name.text.trim(),
              productId: _productId,
              marginPercent: parseNum(_margin.text),
              items: List.of(_items),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
