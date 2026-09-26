import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/form_kit.dart';
import '../stock_providers.dart';

const _directions = {
  'IN': 'Entrada',
  'OUT': 'Saída',
  'TRANSFER': 'Transferência entre almoxarifados',
};

const _subtypes = {
  'IN': {'PURCHASE': 'Compra'},
  'OUT': {'SALE': 'Venda', 'LOSS': 'Perda'},
};

/// Lançamento de movimento de estoque (entrada/saída com subtipo, ou transferência) —
/// mesmo form da web em Saldos ("Movimentar") e Movimentos. Saldo não é editado direto,
/// só via movimento (kardex). Aberto a partir de um saldo, já vem com produto e
/// almoxarifado preenchidos.
class MovementForm extends ConsumerStatefulWidget {
  const MovementForm({super.key, this.productId = '', this.warehouseId = ''});

  final String productId;
  final String warehouseId;

  @override
  ConsumerState<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends ConsumerState<MovementForm> {
  final _form = GlobalKey<FormState>();
  late var _productId = widget.productId;
  late var _fromId = widget.warehouseId;
  var _direction = '';
  var _subtype = '';
  var _toId = '';
  final _qty = TextEditingController();
  var _saving = false;

  bool get _isTransfer => _direction == 'TRANSFER';

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = (ref.watch(productsProvider).valueOrNull ?? [])
        .where((p) => p.kind != 'FIXED_ASSET')
        .toList();
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? [];
    return Form(
      key: _form,
      child: FormScaffold(
        title: 'Movimentar estoque',
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
            ErpDropdown<String>(
              label: 'Tipo',
              value: _direction.isEmpty ? null : _direction,
              items: _directions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() {
                _direction = v ?? '';
                _subtype = '';
                _toId = '';
              }),
            ),
            if (_direction.isNotEmpty && !_isTransfer)
              ErpDropdown<String>(
                label: 'Subtipo',
                value: _subtype.isEmpty ? null : _subtype,
                items: (_subtypes[_direction] ?? const {})
                    .entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _subtype = v ?? ''),
              ),
            ErpDropdown<String>(
              label: _isTransfer ? 'Almoxarifado de origem' : 'Almoxarifado',
              value: _fromId.isEmpty ? null : _fromId,
              items: warehouses
                  .map((w) => DropdownMenuItem(value: w.id, child: Text('${w.code} — ${w.name}')))
                  .toList(),
              onChanged: (v) => setState(() {
                _fromId = v ?? '';
                if (_toId == _fromId) _toId = '';
              }),
            ),
            if (_isTransfer)
              ErpDropdown<String>(
                label: 'Almoxarifado de destino',
                value: _toId.isEmpty ? null : _toId,
                items: warehouses
                    .where((w) => w.id != _fromId)
                    .map((w) => DropdownMenuItem(value: w.id, child: Text('${w.code} — ${w.name}')))
                    .toList(),
                onChanged: (v) => setState(() => _toId = v ?? ''),
              ),
            ErpField('Qtd (un. venda)', _qty,
                keyboard: const TextInputType.numberWithOptions(decimal: true), required: true),
          ],
        ),
      ),
    );
  }

  String? _missing() {
    if (_productId.isEmpty) return 'Selecione o produto.';
    if (_direction.isEmpty) return 'Selecione o tipo.';
    if (!_isTransfer && _subtype.isEmpty) return 'Selecione o subtipo.';
    if (_fromId.isEmpty) return 'Selecione o almoxarifado.';
    if (_isTransfer && _toId.isEmpty) return 'Selecione o almoxarifado de destino.';
    if (parseNum(_qty.text) <= 0) return 'Quantidade deve ser maior que zero.';
    return null;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final missing = _missing();
    if (missing != null) {
      showError(context, missing);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(movementsProvider.notifier).launch(
            productId: _productId,
            direction: _direction,
            subtype: _subtype,
            fromWarehouseId: _fromId,
            toWarehouseId: _toId,
            quantity: parseNum(_qty.text),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
