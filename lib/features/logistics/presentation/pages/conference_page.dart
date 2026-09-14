import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/barcode_scan_page.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../invoicing/presentation/invoicing_pages.dart';
import '../../../purchasing/domain/entities.dart';
import '../../../purchasing/presentation/purchasing_providers.dart';
import '../../../stock/domain/entities.dart';
import '../../../stock/presentation/stock_providers.dart';

class ConferenceListPage extends ConsumerWidget {
  const ConferenceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersProvider);
    final invoices = ref.watch(invoicesProvider('IN')).valueOrNull ?? [];
    final invoiced = {
      for (final i in invoices)
        if (i.purchaseOrderId.isNotEmpty) i.purchaseOrderId: i,
    };
    final names = {
      for (final s in ref.watch(suppliersProvider).valueOrNull ?? []) s.id: s.displayName,
    };
    final shown = orders.whenData((list) => list.where((o) => o.status == 'RECEIVED').toList());
    return CrudList<PurchaseOrder>(
      value: shown,
      onRefresh: () => ref.read(purchaseOrdersProvider.notifier).reload(),
      titleOf: (o) => names[o.supplierId] ?? o.supplierId,
      subtitleOf: (o) {
        final inv = invoiced[o.id];
        final nf = inv == null ? '' : 'NF ${inv.series}-${inv.invoiceNumber} · ';
        return '$nf${statusView(o.status).label} · ${brl(o.totalAmount)}';
      },
      onTap: (o) => context.push('/logistica/conferencia/${o.id}'),
    );
  }
}

class ConferencePage extends ConsumerStatefulWidget {
  const ConferencePage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ConferencePage> createState() => _ConferencePageState();
}

class _ConferencePageState extends ConsumerState<ConferencePage> {
  final _counts = <String, double>{};
  var _busy = false;
  String _error = '';

  PurchaseOrder? get _order {
    final list = ref.read(purchaseOrdersProvider).valueOrNull ?? [];
    return list.where((o) => o.id == widget.orderId).firstOrNull;
  }

  Product? _product(String id) {
    final list = ref.read(productsProvider).valueOrNull ?? [];
    return list.where((p) => p.id == id).firstOrNull;
  }

  void _add(String productId, double qty) {
    final o = _order;
    if (o == null) return;
    if (!o.items.any((i) => i.productId == productId)) {
      setState(() => _error = 'Produto não está no pedido');
      return;
    }
    setState(() {
      _counts[productId] = (_counts[productId] ?? 0) + qty;
      _error = '';
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanPage()),
    );
    if (code == null || code.isEmpty) return;
    final t = code.trim();
    final m = RegExp(r'^(.+?)\s*[,;]\s*(\d+(?:[.,]\d+)?)\s*$').firstMatch(t);
    final q = (m?.group(1) ?? t).trim().toLowerCase();
    final qty = m == null ? 1.0 : double.tryParse(m.group(2)!.replaceAll(',', '.')) ?? 1;
    final products = ref.read(productsProvider).valueOrNull ?? [];
    final p = products.where((x) => x.barcode.toLowerCase() == q || x.sku.toLowerCase() == q).firstOrNull;
    if (p == null) {
      setState(() => _error = 'Código não encontrado');
      return;
    }
    _add(p.id, qty);
  }

  Future<void> _confirm() async {
    final o = _order;
    if (o == null) return;
    for (final it in o.items) {
      if ((_counts[it.productId] ?? 0) + 1e-9 < it.quantity) {
        setState(() => _error = 'Conferência incompleta');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await ref.read(purchaseOrdersProvider.notifier).confer(o.id);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pedido conferido'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _qty(double n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  @override
  Widget build(BuildContext context) {
    ref.watch(purchaseOrdersProvider);
    final o = _order;
    if (o == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferência'),
        actions: [
          IconButton(onPressed: _busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: erpDanger)),
          for (final it in o.items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(() {
                  final p = _product(it.productId);
                  return p == null ? it.productId : '${p.sku} — ${p.name}';
                }()),
                subtitle: Text('Pedido ${_qty(it.quantity)} · Conferido ${_qty(_counts[it.productId] ?? 0)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _busy ? null : () => _add(it.productId, 1),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: Text(_busy ? 'Salvando...' : 'Confirmar conferência'),
          ),
        ],
      ),
    );
  }
}
