import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/person_form.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../config/domain/entities.dart';
import '../../../config/presentation/config_providers.dart';
import '../../../stock/presentation/stock_providers.dart';
import '../../domain/entities.dart';
import '../purchasing_providers.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(suppliersProvider);
    return CrudList<Person>(
      value: items,
      onRefresh: () => ref.read(suppliersProvider.notifier).reload(),
      titleOf: (p) => p.displayName,
      subtitleOf: (p) => '${p.kind} · ${p.document} · ${p.phone}',
      filters: [
        ListFilter<Person>.byValue(
          label: 'Tipo',
          valueOf: (p) => p.kind,
          options: const [FilterOption('PF', 'Pessoa física'), FilterOption('PJ', 'Pessoa jurídica')],
        ),
      ],
      onCreate: () => pushForm(
        context,
        PersonForm(
          title: 'Novo fornecedor',
          onSave: (p) => ref.read(suppliersProvider.notifier).save(p),
        ),
      ),
      onEdit: (p) => pushForm(
        context,
        PersonForm(
          title: 'Editar fornecedor',
          person: p,
          onSave: (n) => ref.read(suppliersProvider.notifier).save(n),
        ),
      ),
    );
  }
}

class QuotesPage extends ConsumerWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(quotesProvider);
    final names = {
      for (final s in ref.watch(suppliersProvider).valueOrNull ?? []) s.id: s.displayName,
    };
    return CrudList<Quote>(
      value: quotes,
      onRefresh: () => ref.read(quotesProvider.notifier).reload(),
      titleOf: (q) => names[q.supplierId] ?? q.supplierId,
      subtitleOf: (q) => '${q.status?.name ?? ''} · ${brl(q.totalAmount ?? 0)}',
      filters: [
        ListFilter<Quote>.byValue(label: 'Status', valueOf: (q) => q.status?.name ?? ''),
      ],
      onCreate: () => pushForm(context, const _QuoteForm()),
      // Só orçamento aberto edita/exclui — convertido ou cancelado já não muda mais.
      onEdit: (q) => pushForm(context, _QuoteForm(quote: q)),
      canEdit: (q) => q.status == QuoteStatus.OPEN,
      onDelete: (q) => ref.read(quotesProvider.notifier).deleteQuote(q.id ?? ''),
      canDelete: (q) => q.status == QuoteStatus.OPEN,
      extraActions: (q) => q.status == QuoteStatus.OPEN
          ? [const PopupMenuItem(value: 'convert', child: Text('Gerar pedido'))]
          : const [],
      onAction: (q, action) {
        if (action == 'convert') pushForm(context, _ConvertForm(quoteId: q.id ?? ''));
      },
    );
  }
}

// Eixo financeiro do pedido de compra — independente do status de entrega (statusView acima).
String _paymentStatusLabel(String s) => s == 'PAID' ? 'Pago' : 'Pendente';

// Só pedido pendente de entrega (APPROVED) e ainda não pago pode ser editado/excluído — mesma
// regra do backend (purchasing-service, editable() em service.go). Um pedido pago já moveu
// dinheiro; reabra o financeiro pra PENDING antes de editar/excluir.
bool _orderEditable(PurchaseOrder o) => o.status == 'APPROVED' && o.paymentStatus != 'PAID';

class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersProvider);
    final names = {
      for (final s in ref.watch(suppliersProvider).valueOrNull ?? []) s.id: s.displayName,
    };
    return CrudList<PurchaseOrder>(
      value: orders,
      onRefresh: () => ref.read(purchaseOrdersProvider.notifier).reload(),
      titleOf: (o) => names[o.supplierId] ?? o.supplierId,
      subtitleOf: (o) => o.status == 'CANCELLED'
          ? '${statusView(o.status).label} · ${brl(o.totalAmount)}'
          : '${statusView(o.status).label} · ${_paymentStatusLabel(o.paymentStatus)} · ${brl(o.totalAmount)}',
      filters: [
        ListFilter<PurchaseOrder>.byValue(
          label: 'Status',
          valueOf: (o) => o.status,
          labelOf: (v) => statusView(v).label,
        ),
      ],
      onCreate: () => pushForm(context, const _PoForm()),
      onEdit: (o) => pushForm(context, _PoForm(order: o)),
      canEdit: _orderEditable,
      onDelete: (o) => ref.read(purchaseOrdersProvider.notifier).delete(o.id),
      canDelete: _orderEditable,
      extraActions: (o) => [
        if (o.status != 'CANCELLED')
          PopupMenuItem(
            value: 'toggle-payment',
            child: Text(o.paymentStatus == 'PAID' ? 'Marcar pendente' : 'Marcar pago'),
          ),
        // Manual: pendente entrega (APPROVED, inclusive já recebido) <-> finalizado (CONFERRED).
        // O fluxo de NF (Receber/Conferir) também move esse status. Reabrir fica indisponível
        // depois que o estoque já recebeu a mercadoria — mesma trava do backend.
        if (o.status == 'APPROVED' || o.status == 'RECEIVED')
          const PopupMenuItem(value: 'toggle-delivery', child: Text('Finalizar entrega')),
        if (o.status == 'CONFERRED' && !o.stockReceived)
          const PopupMenuItem(value: 'toggle-delivery', child: Text('Reabrir entrega')),
        if (o.status != 'RECEIVED' && o.status != 'CONFERRED' && o.status != 'CANCELLED')
          const PopupMenuItem(value: 'cancel', child: Text('Cancelar')),
      ],
      onAction: (o, action) {
        switch (action) {
          case 'cancel':
            ref.read(purchaseOrdersProvider.notifier).cancel(o.id);
          case 'toggle-payment':
            ref
                .read(purchaseOrdersProvider.notifier)
                .setPaymentStatus(o.id, o.paymentStatus == 'PAID' ? 'PENDING' : 'PAID');
          case 'toggle-delivery':
            ref
                .read(purchaseOrdersProvider.notifier)
                .setDeliveryStatus(o.id, o.status == 'CONFERRED' ? 'APPROVED' : 'CONFERRED');
        }
      },
    );
  }
}

class PurchaseHistoryPage extends ConsumerWidget {
  const PurchaseHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(purchaseHistoryProvider);
    return CrudList<PurchasePrice>(
      value: items,
      onRefresh: () => ref.read(purchaseHistoryProvider.notifier).reload(),
      titleOf: (p) => p.sku,
      subtitleOf: (p) => '${brl(p.previousPrice)} → ${brl(p.newPrice)}',
    );
  }
}

class _QuoteForm extends ConsumerStatefulWidget {
  const _QuoteForm({this.quote});

  final Quote? quote;

  @override
  ConsumerState<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends ConsumerState<_QuoteForm> {
  late var _supplierId = widget.quote?.supplierId ?? '';
  late final _items = List<QuoteLine>.from(widget.quote?.items ?? const []);
  var _productId = '';
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController(text: '0');
  late final _notes = TextEditingController(text: widget.quote?.notes ?? '');
  late final _discount = TextEditingController(text: '${widget.quote?.discountAmount ?? 0}');
  late final _delivery = TextEditingController(text: '${widget.quote?.deliveryAmount ?? 0}');
  var _draftKey = 0;
  var _saving = false;

  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + i.quantity * i.unitPrice);

  double get _total =>
      _subtotal - parseNum(_discount.text) + parseNum(_delivery.text);

  @override
  void initState() {
    super.initState();
    _discount.addListener(() => setState(() {}));
    _delivery.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _notes.dispose();
    _discount.dispose();
    _delivery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final products = ref.watch(purchaseLookupsProvider).valueOrNull?.products ?? [];
    return FormScaffold(
      title: widget.quote == null ? 'Novo orçamento' : 'Editar orçamento',
      saving: _saving,
      onSave: _save,
      child: Column(
        children: [
          ErpDropdown<String>(
            label: 'Fornecedor',
            value: _supplierId.isEmpty ? null : _supplierId,
            items: suppliers
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                .toList(),
            onChanged: (v) => setState(() => _supplierId = v ?? ''),
          ),
          ErpField('Observação', _notes),
          KeyedSubtree(
            key: ValueKey(_draftKey),
            child: Column(
              children: [
                ErpDropdown<String>(
                  label: 'Produto',
                  value: _productId.isEmpty ? null : _productId,
                  items: products
                      .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}')))
                      .toList(),
                  onChanged: (v) {
                    final p = products.where((x) => x.id == v).firstOrNull;
                    setState(() {
                      _productId = v ?? '';
                      if (p != null) _price.text = '${p.purchasePrice}';
                    });
                  },
                ),
                QtyPriceFields(qty: _qty, price: _price),
              ],
            ),
          ),
          LineItemsBar(
            count: _items.length,
            onAdd: () => _add(),
            onOpen: () => _open(products),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Desconto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _delivery,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Frete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Subtotal: ${brl(_subtotal)} · Desconto: -${brl(parseNum(_discount.text))} · '
              'Frete: +${brl(parseNum(_delivery.text))} · Total: ${brl(_total)}',
              style: const TextStyle(color: erpMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _add() {
    if (_productId.isEmpty) return;
    setState(() {
      _items.add(
        QuoteLine(
          productId: _productId,
          quantity: parseNum(_qty.text, 1),
          unitPrice: parseNum(_price.text),
        ),
      );
      _productId = '';
      _qty.text = '1';
      _price.text = '0';
      _draftKey++;
    });
  }

  void _open(List<({String id, String sku, String name, double purchasePrice})> products) {
    pushForm(
      context,
      LineItemsPage<QuoteLine>(
        items: _items,
        titleOf: (i) {
          final p = products.where((x) => x.id == i.productId).firstOrNull;
          return p == null ? i.productId : '${p.sku} — ${p.name}';
        },
        subtitleOf: (i) => '${i.quantity} × ${brl(i.unitPrice)}',
        onDelete: (i) => setState(() => _items.removeAt(i)),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final quote = Quote(
        supplierId: _supplierId,
        notes: _notes.text.trim(),
        discountAmount: parseNum(_discount.text),
        deliveryAmount: parseNum(_delivery.text),
        items: List.of(_items),
      );
      final notifier = ref.read(quotesProvider.notifier);
      final id = widget.quote?.id;
      if (id != null) {
        await notifier.updateQuote(id, quote);
      } else {
        await notifier.create(quote);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PoForm extends ConsumerStatefulWidget {
  const _PoForm({this.order});

  final PurchaseOrder? order;

  @override
  ConsumerState<_PoForm> createState() => _PoFormState();
}

class _PoFormState extends ConsumerState<_PoForm> {
  late var _supplierId = widget.order?.supplierId ?? '';
  late var _methodId = widget.order?.paymentMethodId ?? '';
  late var _termId = widget.order?.paymentTermId ?? '';
  late final _items = List<PurchaseLine>.from(widget.order?.items ?? const []);
  var _productId = '';
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController(text: '0');
  var _draftKey = 0;
  var _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final lookups = ref.watch(purchaseLookupsProvider).valueOrNull;
    final products = lookups?.products ?? [];
    return FormScaffold(
      title: widget.order == null ? 'Novo pedido de compra' : 'Editar pedido de compra',
      saving: _saving,
      onSave: _save,
      child: Column(
        children: [
          ErpDropdown<String>(
            label: 'Fornecedor',
            value: _supplierId.isEmpty ? null : _supplierId,
            items: suppliers
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                .toList(),
            onChanged: (v) => setState(() => _supplierId = v ?? ''),
          ),
          ErpDropdown<String>(
            label: 'Forma',
            value: _methodId.isEmpty ? null : _methodId,
            items: (lookups?.methods ?? [])
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                .toList(),
            onChanged: (v) => setState(() => _methodId = v ?? ''),
          ),
          ErpDropdown<String>(
            label: 'Condição',
            value: _termId.isEmpty ? null : _termId,
            items: (lookups?.terms ?? [])
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _termId = v ?? ''),
          ),
          KeyedSubtree(
            key: ValueKey(_draftKey),
            child: Column(
              children: [
                ErpDropdown<String>(
                  label: 'Produto',
                  value: _productId.isEmpty ? null : _productId,
                  items: products
                      .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}')))
                      .toList(),
                  onChanged: (v) {
                    final p = products.where((x) => x.id == v).firstOrNull;
                    setState(() {
                      _productId = v ?? '';
                      if (p != null) _price.text = '${p.purchasePrice}';
                    });
                  },
                ),
                QtyPriceFields(qty: _qty, price: _price),
              ],
            ),
          ),
          LineItemsBar(
            count: _items.length,
            onAdd: _add,
            onOpen: () => pushForm(
              context,
              LineItemsPage<PurchaseLine>(
                items: _items,
                titleOf: (i) {
                  final p = products.where((x) => x.id == i.productId).firstOrNull;
                  return p == null ? i.productId : '${p.sku} — ${p.name}';
                },
                subtitleOf: (i) => '${i.quantity} × ${brl(i.unitPrice)}',
                onDelete: (i) => setState(() => _items.removeAt(i)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _add() {
    if (_productId.isEmpty) return;
    setState(() {
      _items.add(
        PurchaseLine(
          productId: _productId,
          quantity: parseNum(_qty.text, 1),
          unitPrice: parseNum(_price.text),
        ),
      );
      _productId = '';
      _qty.text = '1';
      _price.text = '0';
      _draftKey++;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final order = PurchaseOrder(
        id: '',
        supplierId: _supplierId,
        status: '',
        totalAmount: 0,
        paymentMethodId: _methodId,
        paymentTermId: _termId,
        items: List.of(_items),
      );
      final notifier = ref.read(purchaseOrdersProvider.notifier);
      if (widget.order != null) {
        await notifier.updateOrder(widget.order!.id, order);
      } else {
        await notifier.create(order);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ConvertForm extends ConsumerStatefulWidget {
  const _ConvertForm({required this.quoteId});

  final String quoteId;

  @override
  ConsumerState<_ConvertForm> createState() => _ConvertFormState();
}

class _ConvertFormState extends ConsumerState<_ConvertForm> {
  var _methodId = '';
  var _termId = '';
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(purchaseLookupsProvider).valueOrNull;
    return FormScaffold(
      title: 'Gerar pedido',
      saving: _saving,
      onSave: () async {
        setState(() => _saving = true);
        try {
          await ref.read(quotesProvider.notifier).convert(widget.quoteId, _methodId, _termId);
          if (context.mounted) Navigator.of(context).pop();
        } catch (e) {
          if (context.mounted) showError(context, '$e');
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
      child: Column(
        children: [
          ErpDropdown<String>(
            label: 'Forma',
            value: _methodId.isEmpty ? null : _methodId,
            items: (lookups?.methods ?? [])
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                .toList(),
            onChanged: (v) => setState(() => _methodId = v ?? ''),
          ),
          ErpDropdown<String>(
            label: 'Condição',
            value: _termId.isEmpty ? null : _termId,
            items: (lookups?.terms ?? [])
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _termId = v ?? ''),
          ),
        ],
      ),
    );
  }
}

class ReceiveOrderForm extends ConsumerStatefulWidget {
  const ReceiveOrderForm({super.key, required this.order});

  final PurchaseOrder order;

  @override
  ConsumerState<ReceiveOrderForm> createState() => _ReceiveOrderFormState();
}

class _ReceiveOrderFormState extends ConsumerState<ReceiveOrderForm> {
  var _warehouseId = '';
  var _saving = false;

  String _qty(double n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

  @override
  Widget build(BuildContext context) {
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? [];
    final products = ref.watch(purchaseLookupsProvider).valueOrNull?.products ?? [];
    final def = ref.watch(defaultWarehouseProvider).valueOrNull ?? '';
    final selected = _warehouseId.isEmpty ? def : _warehouseId;
    final wh = warehouses.where((w) => w.id == selected).firstOrNull;
    final whLabel = wh == null ? '—' : '${wh.code} — ${wh.name}';
    String productLabel(PurchaseLine it) {
      final p = products.where((x) => x.id == it.productId).firstOrNull;
      return p == null ? it.productId : '${p.sku} — ${p.name}';
    }
    return FormScaffold(
      title: 'Receber pedido',
      saving: _saving,
      onSave: () async {
        if (selected.isEmpty) {
          showError(context, 'Selecione o almoxarifado');
          return;
        }
        setState(() => _saving = true);
        try {
          await ref.read(purchaseOrdersProvider.notifier).receive(widget.order.id, warehouseId: selected);
          if (context.mounted) Navigator.of(context).pop();
        } catch (e) {
          if (context.mounted) showError(context, '$e');
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErpDropdown<String>(
            label: 'Almoxarifado',
            value: warehouses.any((w) => w.id == selected) ? selected : null,
            items: warehouses
                .map((w) => DropdownMenuItem(value: w.id, child: Text('${w.code} — ${w.name}')))
                .toList(),
            onChanged: (v) => setState(() => _warehouseId = v ?? ''),
          ),
          const SizedBox(height: 8),
          Text(
            'Itens que entram em $whLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final it in widget.order.items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(productLabel(it)),
                subtitle: Text('Qtd ${_qty(it.quantity)}\nAlmoxarifado: $whLabel'),
                isThreeLine: true,
              ),
            ),
          if (widget.order.items.isEmpty)
            const Text('Pedido sem itens.'),
        ],
      ),
    );
  }
}
