import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/barcode_scan_page.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../core/scan_code.dart';
import '../../../stock/domain/product_lookup.dart';
import '../../../config/presentation/config_providers.dart';
import '../../../stock/domain/entities.dart';
import '../../../stock/presentation/stock_providers.dart';
import '../../domain/entities.dart';
import '../sales_providers.dart';
import 'picking_labels_page.dart';

class PickingPage extends ConsumerStatefulWidget {
  const PickingPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PickingPage> createState() => _PickingPageState();
}

class _PickingPageState extends ConsumerState<PickingPage> {
  SalesOrder? _order;
  var _warehouseId = '';
  var _busy = false;
  var _volumes = 1;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o =
          (await ref.read(salesRepositoryProvider).getOrder(widget.orderId))
              .getOrThrow();
      final def = ref.read(defaultWarehouseProvider).valueOrNull ?? '';
      if (mounted) {
        setState(() {
          _order = o;
          if (o.volumeCount > 0) _volumes = o.volumeCount;
          if (_warehouseId.isEmpty) {
            _warehouseId = o.warehouseId.isNotEmpty ? o.warehouseId : def;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  double _picked(String productId) => (_order?.picks ?? [])
      .where((p) => p.productId == productId)
      .fold(0.0, (n, p) => n + p.quantity);

  Product? _product(String id) {
    final list = ref.read(productsProvider).valueOrNull ?? [];
    return list.where((p) => p.id == id).firstOrNull;
  }

  /// True se a separação foi registrada; em falha, o motivo fica em [_error].
  Future<bool> _pick(String productId, double qty) async {
    if (_busy || qty <= 0) return false;
    if (_warehouseId.isEmpty) {
      setState(() => _error = 'Selecione o almoxarifado');
      return false;
    }
    final bals = ref.read(balancesProvider).valueOrNull ?? [];
    var stock = 0.0;
    var reserved = 0.0;
    for (final b in bals) {
      if (b.productId == productId && b.warehouseId == _warehouseId) {
        stock += b.available;
        reserved += b.reserved;
      }
    }
    final mine = (_order?.items ?? [])
        .where((i) => i.productId == productId)
        .fold(0.0, (n, i) => n + i.quantity);
    stock = stock - reserved + mine;
    if (_picked(productId) + qty > stock + 1e-9) {
      setState(() => _error = 'Estoque insuficiente no almoxarifado (disp. $stock)');
      return false;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final updated =
          (await ref
                  .read(salesRepositoryProvider)
                  .scanPick(
                    widget.orderId,
                    productId: productId,
                    warehouseId: _warehouseId,
                    quantity: qty,
                  ))
              .getOrThrow();
      if (!mounted) return false;
      setState(() {
        _order = updated;
        _error = '';
        _busy = false;
      });
      ref.read(salesOrdersProvider.notifier).reload();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
      return false;
    }
  }

  bool _itemsDone() {
    final o = _order;
    if (o == null || o.items.isEmpty) return false;
    return o.items.every((it) => _picked(it.productId) + 1e-9 >= it.quantity);
  }

  Future<void> _finish() async {
    if (_busy || !_itemsDone()) return;
    if (_volumes < 1) {
      setState(() => _error = 'Informe a quantidade de volumes');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final updated = (await ref.read(salesRepositoryProvider).completePicking(
            widget.orderId,
            volumeCount: _volumes,
          ))
          .getOrThrow();
      if (!mounted) return;
      setState(() {
        _order = updated;
        _busy = false;
      });
      await ref.read(salesOrdersProvider.notifier).reload();
      final names = {
        for (final c in ref.read(customersProvider).valueOrNull ?? [])
          c.id: c.displayName,
      };
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PickingLabelsPage(
            order: updated,
            customerName: names[updated.customerId] ?? updated.customerId,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _scanWarehouse() async {
    final code = await scanBarcode(context);
    if (!mounted || code == null) return;
    final q = code.trim().toLowerCase();
    final warehouses = ref.read(warehousesProvider).valueOrNull ?? [];
    final wh = warehouses
        .where((w) => w.code.toLowerCase() == q || w.name.toLowerCase() == q)
        .firstOrNull;
    if (wh == null) {
      setState(() => _error = 'Almoxarifado não encontrado');
      return;
    }
    setState(() {
      _warehouseId = wh.id;
      _error = '';
    });
  }

  /// Trata uma leitura da câmera (modo contínuo) e devolve o resultado para a faixa sobre a câmera.
  Future<ScanFeedback> _onScanned(String raw) async {
    // Separação: só vale SKU/código (sem ",qtd") ou a etiqueta de pesagem, que já traz o peso.
    final scan = decodeWeightBarcode(raw) ?? parseScanCode(raw, allowQuantity: false);
    if (scan == null || _order == null) return const ScanFeedback.error('Código inválido');
    final product = findProductByCode(ref.read(productsProvider).valueOrNull ?? [], scan.code);
    if (product == null) {
      setState(() => _error = 'Código não encontrado');
      return ScanFeedback.error('Código não encontrado: ${scan.code}');
    }
    if (await _pick(product.id, scan.quantity)) {
      return ScanFeedback.ok('${product.name}: ${_picked(product.id)} separado(s)');
    }
    return ScanFeedback.error(_error.isEmpty ? 'Não foi possível registrar' : _error);
  }

  Future<void> _qtyModal(OrderLine it) async {
    final remaining = it.quantity - _picked(it.productId);
    if (remaining <= 0) {
      setState(() => _error = 'Item já separado');
      return;
    }
    final p = _product(it.productId);
    final uom = (p?.saleUom.isNotEmpty == true)
        ? p!.saleUom
        : (p?.stockUom ?? '');
    final qty = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QtyDialog(
        title: p == null ? it.productId : '${p.sku} — ${p.name}',
        uom: uom,
        ordered: it.quantity,
        picked: _picked(it.productId),
      ),
    );
    if (!mounted || qty == null) return;
    await _pick(it.productId, qty);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? [];
    final order = _order;
    final wh = warehouses.where((w) => w.id == _warehouseId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Separação')),
      body: order == null
          ? Center(
              child: _error.isEmpty
                  ? const CircularProgressIndicator()
                  : Text(_error, style: const TextStyle(color: erpDanger)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  [
                    if (order.pickingNumber > 0) 'Separação ${sepNo(order.pickingNumber)}',
                    order.status,
                  ].join(' · '),
                  style: const TextStyle(color: erpMuted),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_error.isNotEmpty)
                  Text(_error, style: const TextStyle(color: erpDanger)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Autocomplete<Warehouse>(
                        key: ValueKey(_warehouseId),
                        initialValue: TextEditingValue(
                          text: wh == null ? '' : '${wh.code} — ${wh.name}',
                        ),
                        displayStringForOption: (w) => '${w.code} — ${w.name}',
                        optionsBuilder: (v) {
                          final q = v.text.trim().toLowerCase();
                          if (q.isEmpty) return warehouses;
                          return warehouses.where(
                            (w) =>
                                w.code.toLowerCase().contains(q) ||
                                w.name.toLowerCase().contains(q),
                          );
                        },
                        onSelected: (w) => setState(() {
                          _warehouseId = w.id;
                          _error = '';
                        }),
                        fieldViewBuilder:
                            (context, controller, focus, onSubmit) {
                              return TextField(
                                controller: controller,
                                focusNode: focus,
                                onSubmitted: (_) => onSubmit(),
                                decoration: const InputDecoration(
                                  labelText: 'Almoxarifado',
                                ),
                              );
                            },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton.filled(
                        onPressed: _busy ? null : _scanWarehouse,
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final it in order.items)
                  _PickTile(
                    item: it,
                    product: products
                        .where((p) => p.id == it.productId)
                        .firstOrNull,
                    picked: _picked(it.productId),
                    onDoubleTap: _busy ? null : () => _qtyModal(it),
                  ),
                const SizedBox(height: 16),
                Text('Volumes / embalagens', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _busy || _volumes <= 1 ? null : () => setState(() => _volumes--),
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_volumes', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                    IconButton.filledTonal(
                      onPressed: _busy ? null : () => setState(() => _volumes++),
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Quantidade de embalagens do pedido', style: TextStyle(color: erpMuted))),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || !_itemsDone() ? null : _finish,
                  child: Text(_busy ? 'Salvando...' : 'Finalizar e gerar etiquetas'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => scanBarcodes(context, onCode: _onScanned, title: 'Separação'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_busy ? 'Bipando...' : 'Bipar com a câmera'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bipe o SKU ou o código de barras do produto (1 unidade por leitura) ou a etiqueta de pesagem. Toque duas vezes no item para informar a quantidade.',
                  style: TextStyle(color: erpMuted),
                ),
              ],
            ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.item,
    required this.product,
    required this.picked,
    this.onDoubleTap,
  });

  final OrderLine item;
  final Product? product;
  final double picked;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final ordered = item.quantity;
    final (icon, color) = picked <= 0
        ? (Icons.cancel_outlined, erpDanger)
        : picked >= ordered
        ? (Icons.check_circle, const Color(0xFF3DDC97))
        : (Icons.warning_amber_rounded, const Color(0xFFF5C451));
    final uom = (product?.saleUom.isNotEmpty == true)
        ? product!.saleUom
        : (product?.stockUom ?? '');
    final title = product == null
        ? item.productId
        : '${product!.sku} — ${product!.name}';
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          'Pedido ${ordered.toStringAsFixed(1)} · Separado ${picked.toStringAsFixed(1)}${uom.isEmpty ? '' : ' $uom'}',
        ),
      ),
    );
  }
}

class _QtyDialog extends StatefulWidget {
  const _QtyDialog({
    required this.title,
    required this.uom,
    required this.ordered,
    required this.picked,
  });

  final String title;
  final String uom;
  final double ordered;
  final double picked;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final TextEditingController _ctrl;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final remaining = widget.ordered - widget.picked;
    _ctrl = TextEditingController(text: remaining.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final qty = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Quantidade inválida');
      return;
    }
    final remaining = widget.ordered - widget.picked;
    if (qty + 1e-9 < remaining) {
      setState(() => _error = 'Quantidade abaixo do pedido');
      return;
    }
    if (widget.picked + qty > widget.ordered * 1.10) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quantidade acima'),
          content: const Text(
            'A quantidade está mais de 10% acima do pedido. Deseja confirmar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).pop(qty);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.uom.isEmpty
                  ? 'Quantidade'
                  : 'Quantidade (${widget.uom})',
            ),
            onSubmitted: (_) => _confirm(),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error, style: const TextStyle(color: erpDanger)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _confirm, child: const Text('Confirmar')),
      ],
    );
  }
}
