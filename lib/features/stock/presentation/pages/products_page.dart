import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../config/domain/entities.dart';
import '../../domain/entities.dart';
import '../stock_providers.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    return CrudList<Product>(
      value: products,
      onRefresh: () => ref.read(productsProvider.notifier).reload(),
      titleOf: (p) => p.name,
      subtitleOf: (p) => '${p.sku} · ${p.kindLabel} · ${brl(p.salePrice)}',
      onCreate: () => pushForm(context, const ProductFormPage()),
      onEdit: (p) => pushForm(context, ProductFormPage(product: p)),
      onDelete: (p) => ref.read(productsProvider.notifier).remove(p.id),
    );
  }
}

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _barcode = TextEditingController(text: widget.product?.barcode ?? '');
  late final _ncm = TextEditingController(text: widget.product?.ncm ?? '');
  late final _factor = TextEditingController(
    text: '${widget.product == null || widget.product!.conversions.isEmpty ? 1 : widget.product!.conversions.first.factor}',
  );
  late final _weight = TextEditingController(text: widget.product == null ? '' : '${widget.product!.weightKg}');
  late final _volume = TextEditingController(text: widget.product == null ? '' : '${widget.product!.volumeM3}');
  late var _kind = widget.product?.kind ?? 'FINAL';
  late var _purchase = widget.product?.purchaseUom ?? '';
  late var _sale = widget.product?.saleUom ?? '';
  late var _categoryId = widget.product?.categoryId ?? '';
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _ncm.dispose();
    _factor.dispose();
    _weight.dispose();
    _volume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(stockUnitsProvider).valueOrNull ?? const <Unit>[];
    final cats = flattenCategories(ref.watch(categoriesProvider).valueOrNull ?? []);
    if (_purchase.isEmpty && units.isNotEmpty) _purchase = units.first.code;
    if (_sale.isEmpty && units.isNotEmpty) _sale = units.first.code;

    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.product == null ? 'Novo produto' : 'Editar produto',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpField('Nome', _name, required: true),
            ErpField('Barras', _barcode),
            ErpField('NCM', _ncm),
            ErpDropdown<String>(
              label: 'Tipo',
              value: _kind,
              items: const [
                DropdownMenuItem(value: 'FINAL', child: Text('Final')),
                DropdownMenuItem(value: 'SUPPORT', child: Text('Apoio')),
                DropdownMenuItem(value: 'FIXED_ASSET', child: Text('Ativo fixo')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'FINAL'),
            ),
            ErpDropdown<String>(
              label: 'Categoria',
              value: _categoryId.isEmpty ? null : _categoryId,
              items: [
                const DropdownMenuItem(value: '', child: Text('—')),
                ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => _categoryId = v ?? ''),
            ),
            ErpDropdown<String>(
              label: 'UoM compra',
              value: _purchase.isEmpty ? null : _purchase,
              items: units
                  .map((u) => DropdownMenuItem(value: u.code, child: Text('${u.code} — ${u.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _purchase = v ?? ''),
            ),
            ErpDropdown<String>(
              label: 'UoM venda/estoque',
              value: _sale.isEmpty ? null : _sale,
              items: units
                  .map((u) => DropdownMenuItem(value: u.code, child: Text('${u.code} — ${u.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _sale = v ?? ''),
            ),
            ErpField('Peso kg / un. venda', _weight, keyboard: TextInputType.number),
            ErpField('Volume m³ / un. venda', _volume, keyboard: TextInputType.number),
            if (_purchase.isNotEmpty && _sale.isNotEmpty && _purchase != _sale)
              ErpField('1 $_purchase = ? $_sale', _factor, keyboard: TextInputType.number, required: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final conversions = _purchase != _sale
          ? [
              UomConversion(
                fromUom: _purchase,
                toUom: _sale,
                factor: double.tryParse(_factor.text.replaceAll(',', '.')) ?? 0,
              ),
            ]
          : <UomConversion>[];
      await ref.read(productsProvider.notifier).save(
            Product(
              id: widget.product?.id ?? '',
              sku: widget.product?.sku ?? '',
              name: _name.text.trim(),
              barcode: _barcode.text.trim(),
              ncm: _ncm.text.trim(),
              categoryId: _categoryId,
              kind: _kind,
              purchaseUom: _purchase,
              saleUom: _sale,
              stockUom: _sale,
              weightKg: double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0,
              volumeM3: double.tryParse(_volume.text.replaceAll(',', '.')) ?? 0,
              conversions: conversions,
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
