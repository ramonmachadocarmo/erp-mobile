import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../stock_providers.dart';
import 'movement_form.dart';

class BalancesPage extends ConsumerWidget {
  const BalancesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesProvider);
    final products = {for (final p in ref.watch(productsProvider).valueOrNull ?? []) p.id: p};
    final warehouses = {for (final w in ref.watch(warehousesProvider).valueOrNull ?? []) w.id: w};
    return CrudList<Balance>(
      value: balances,
      onRefresh: () => ref.read(balancesProvider.notifier).reload(),
      titleOf: (b) => products[b.productId]?.name ?? b.productId,
      searchTextOf: (b) =>
          '${products[b.productId]?.name ?? ''} ${products[b.productId]?.sku ?? ''} ${warehouses[b.warehouseId]?.name ?? ''}',
      filters: [
        ListFilter<Balance>.byValue(
          label: 'Almoxarifado',
          valueOf: (b) => b.warehouseId,
          options: [
            for (final w in warehouses.values) FilterOption(w.id, w.name),
          ],
        ),
      ],
      subtitleOf: (b) {
        final p = products[b.productId];
        final um = p?.stockUom.isNotEmpty == true ? p!.stockUom : (p?.saleUom ?? '');
        final um2 = (p != null && p.purchaseUom.isNotEmpty && p.purchaseUom != um) ? p.purchaseUom : '';
        final extra = um2.isEmpty ? '' : ' · $um2';
        return '${warehouses[b.warehouseId]?.name ?? b.warehouseId} · $um$extra · disp. ${b.available} · res. ${b.reserved}';
      },
      // Saldo não é editado direto — só via movimento (kardex), igual à web.
      onCreate: () => pushForm(context, const MovementForm()),
      onEdit: (b) => pushForm(context, MovementForm(productId: b.productId, warehouseId: b.warehouseId)),
    );
  }
}

class PricesPage extends ConsumerWidget {
  const PricesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(salePricesProvider);
    return CrudList<SalePrice>(
      value: prices,
      onRefresh: () => ref.read(salePricesProvider.notifier).reload(),
      titleOf: (p) => p.sku,
      subtitleOf: (p) => '${brl(p.previousPrice)} → ${brl(p.newPrice)}',
      onCreate: () => pushForm(context, const _PriceForm()),
    );
  }
}

class _PriceForm extends ConsumerStatefulWidget {
  const _PriceForm();

  @override
  ConsumerState<_PriceForm> createState() => _PriceFormState();
}

class _PriceFormState extends ConsumerState<_PriceForm> {
  final _form = GlobalKey<FormState>();
  var _productId = '';
  final _price = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    return Form(
      key: _form,
      child: FormScaffold(
        title: 'Novo preço de venda',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpDropdown<String>(
              label: 'Produto',
              value: _productId.isEmpty ? null : _productId,
              items: products
                  .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _productId = v ?? ''),
            ),
            ErpField('Novo preço', _price, keyboard: TextInputType.number, required: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(salePricesProvider.notifier).create(
            _productId,
            double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
