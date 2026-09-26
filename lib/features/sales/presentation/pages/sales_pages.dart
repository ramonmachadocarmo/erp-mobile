import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/address_form.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../../app/widgets/person_form.dart';
import '../../../config/domain/entities.dart';
import '../../../stock/domain/entities.dart';
import '../../../stock/presentation/stock_providers.dart';
import '../../domain/entities.dart';
import '../../domain/kit_swap.dart' as kit_swap;
import '../sales_providers.dart';

double stockAvail(List<Balance> bals, String productId) {
  var n = 0.0;
  for (final b in bals) {
    if (b.productId == productId) n += b.available - b.reserved;
  }
  return n;
}

double stockOnHand(List<Balance> bals, String productId) {
  var n = 0.0;
  for (final b in bals) {
    if (b.productId == productId) n += b.available;
  }
  return n;
}

bool orderStockShort(SalesOrder o, List<Balance> bals) {
  return o.items.any(
    (it) => it.quantity > stockOnHand(bals, it.productId) + 1e-9,
  );
}

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(customersProvider);
    return CrudList<Person>(
      value: items,
      onRefresh: () => ref.read(customersProvider.notifier).reload(),
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
          title: 'Novo cliente',
          onSave: (p) => ref.read(customersProvider.notifier).save(p),
        ),
      ),
      onEdit: (p) => pushForm(
        context,
        PersonForm(
          title: 'Editar cliente',
          person: p,
          onSave: (n) => ref.read(customersProvider.notifier).save(n),
        ),
      ),
    );
  }
}

const _orderStatuses = [
  'PENDING_RESERVATION',
  'APPROVED',
  'PICKING',
  'PICKED',
  'DELIVERED',
  'UNDELIVERED',
  'INVOICED',
  'CANCELLED',
];

String paymentStatusLabel(String s) => s == 'PAID' ? 'Pago' : 'Pendente';

String _paymentOf(SalesOrder o) =>
    o.paymentStatus.isEmpty ? 'PENDING' : o.paymentStatus;

// "Pendente entrega" (filtro padrão da listagem) = tudo antes de Entregue: o pedido ainda passa
// por aqui até ser roteirizado e entregue — Entregue, Faturado e Cancelado já saíram do fluxo.
// Mesmo critério do filtro padrão da listagem web (Orders.tsx).
const _pendingDeliveryFilter = 'PENDENTE_ENTREGA';
const _pendingDeliveryStatuses = {
  'PENDING_RESERVATION',
  'APPROVED',
  'PICKING',
  'PICKED',
  'UNDELIVERED',
};

String _fmtDeliveryDate(String d) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(d);
  return m == null ? '—' : '${m[3]}/${m[2]}/${m[1]}';
}

class SalesOrdersPage extends ConsumerWidget {
  const SalesOrdersPage({super.key, this.forPicking = false, this.pdv = false});

  final bool forPicking;

  /// PDV counter sale: payment collected on the spot, address optional.
  final bool pdv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(salesOrdersProvider);
    final shown = forPicking
        ? orders.whenData(
            (list) => list
                .where(
                  (o) =>
                      o.status == 'APPROVED' ||
                      o.status == 'PICKING' ||
                      o.status == 'PICKED',
                )
                .toList(),
          )
        : orders;
    final customers = {
      for (final c in ref.watch(customersProvider).valueOrNull ?? [])
        c.id: c.displayName,
    };
    final bals = ref.watch(balancesProvider).valueOrNull ?? [];
    return CrudList<SalesOrder>(
      value: shown,
      onRefresh: () async {
        await Future.wait([
          ref.read(salesOrdersProvider.notifier).reload(),
          ref.read(balancesProvider.notifier).reload(),
        ]);
      },
      titleOf: (o) => customers[o.customerId] ?? o.customerId,
      subtitleOf: (o) => forPicking
          ? '${o.pickingNumber > 0 ? 'Sep. ${sepNo(o.pickingNumber)} · ' : ''}${statusView(o.status).label} · ${brl(o.totalAmount)}\nPedido ${fmtDt(o.createdAt)} · Separação ${fmtDt(o.pickedAt)}'
          : '${statusView(o.status).label} · ${paymentStatusLabel(o.paymentStatus)}${orderStockShort(o, bals) ? ' · Estoque insuficiente' : ''} · ${brl(o.totalAmount)}'
              '${o.deliveryDate.isEmpty ? '' : ' · Entrega ${_fmtDeliveryDate(o.deliveryDate)}'}',
      isThreeLine: forPicking,
      searchTextOf: (o) =>
          '${customers[o.customerId] ?? ''} ${orderNo(o.id)} ${sepNo(o.pickingNumber)} ${statusView(o.status).label}',
      // The separation list is already narrowed to a few statuses.
      filters: forPicking
          ? const []
          : [
              ListFilter<SalesOrder>.custom(
                label: 'Status',
                options: [
                  const FilterOption(_pendingDeliveryFilter, 'Pendente entrega'),
                  for (final st in _orderStatuses)
                    FilterOption(st, statusView(st).label),
                ],
                test: (o, v) => v == _pendingDeliveryFilter
                    ? _pendingDeliveryStatuses.contains(o.status)
                    : o.status == v,
              ),
              ListFilter<SalesOrder>.byValue(
                label: 'Pagamento',
                valueOf: _paymentOf,
                options: const [
                  FilterOption('PAID', 'Pago'),
                  FilterOption('PENDING', 'Pendente'),
                ],
              ),
              ListFilter<SalesOrder>.custom(
                label: 'Entrega',
                options: [
                  const FilterOption('SEM_DATA', 'Sem data'),
                  for (final d in {for (final o in orders.valueOrNull ?? const []) if (o.deliveryDate.isNotEmpty) o.deliveryDate}.toList()..sort())
                    FilterOption(d, _fmtDeliveryDate(d)),
                ],
                test: (o, v) => v == 'SEM_DATA' ? o.deliveryDate.isEmpty : o.deliveryDate == v,
              ),
            ],
      // Filtro padrão: só os pedidos que ainda não saíram do fluxo de entrega (mesmo critério
      // do web, Orders.tsx) — "Todos" nos outros filtros e em qualquer tela de separação.
      initialFilters: forPicking ? const {} : const {0: _pendingDeliveryFilter},
      onCreate: forPicking
          ? null
          : () => pushForm(context, _OrderForm(pdv: pdv)),
      onTap: forPicking
          ? (o) => context.push('/logistica/separacao/${o.id}')
          : null,
      onDoubleTap: forPicking
          ? (o) async {
              if (o.status != 'PICKING' && o.status != 'PICKED') return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Desfazer separação'),
                  content: const Text(
                    'Os itens bipados serão removidos. Continuar?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Desfazer'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await ref.read(salesOrdersProvider.notifier).undoPicking(o.id);
              }
            }
          : null,
      extraActions: (o) => [
        if (o.status == 'APPROVED' || o.status == 'PENDING_RESERVATION')
          const PopupMenuItem(value: 'cancel', child: Text('Cancelar')),
        if (o.status == 'APPROVED' || o.status == 'PICKING')
          const PopupMenuItem(value: 'pick', child: Text('Separar')),
        if (o.status == 'PICKING' || o.status == 'PICKED')
          const PopupMenuItem(value: 'undo', child: Text('Desfazer')),
        // Igual ao web (Orders.tsx): sempre oferecido, o backend que recusa se ja faturado
        // (INVOICED) — exclui de vez, ao contrario de "Cancelar" que mantem o registro.
        if (o.status != 'INVOICED')
          const PopupMenuItem(value: 'delete', child: Text('Excluir')),
      ],
      onAction: (o, action) async {
        if (action == 'cancel') {
          ref.read(salesOrdersProvider.notifier).cancel(o.id);
        }
        if (action == 'pick') context.push('/logistica/separacao/${o.id}');
        if (action == 'undo') {
          ref.read(salesOrdersProvider.notifier).undoPicking(o.id);
        }
        if (action == 'delete') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Excluir pedido'),
              content: const Text('Esta ação não pode ser desfeita. Continuar?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            ref.read(salesOrdersProvider.notifier).delete(o.id);
          }
        }
      },
    );
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm({this.pdv = false});

  final bool pdv;

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  final _form = GlobalKey<FormState>();
  var _customerId = '';
  var _methodId = '';
  var _termId = '';
  var _address = const Address();
  var _deliveryDate = '';
  final _items = <OrderLine>[];
  var _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(salesLookupsProvider));
  }

  void _pickCustomer(Person? c) {
    setState(() {
      _customerId = c?.id ?? '';
      // A single registered address is the obvious choice.
      _address = c != null && c.addresses.length == 1
          ? c.addresses.first
          : const Address();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bals = ref.watch(balancesProvider).valueOrNull ?? [];
    final lookups = ref.watch(salesLookupsProvider).valueOrNull;
    final products = lookups?.products ?? [];
    final customers = lookups?.customers ?? const <Person>[];
    final customer = customers.where((c) => c.id == _customerId).firstOrNull;
    final addresses = customer?.addresses ?? const <Address>[];
    final selectedAddr =
        addresses
            .where((a) => a.id == _address.id && a.id.isNotEmpty)
            .firstOrNull ??
        addresses
            .where(
              (a) => a.alias == _address.alias && _address.alias.isNotEmpty,
            )
            .firstOrNull;
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.pdv ? 'Nova venda' : 'Novo pedido',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpAutocompleteAdd<Person>(
              onAdd: () => _newCustomer(customers),
              field: ErpAutocomplete<Person>(
                label: 'Cliente',
                options: customers,
                selected: customer,
                display: (c) => c.displayName,
                searchText: (c) => '${c.displayName} ${c.document}',
                onSelected: _pickCustomer,
                onCleared: () => _pickCustomer(null),
              ),
            ),
            ErpAutocompleteAdd<Address>(
              onAdd: _customerId.isEmpty ? null : () => _newAddress(customer!),
              field: ErpAutocomplete<Address>(
                label: 'Endereço',
                enabled: _customerId.isNotEmpty,
                options: addresses,
                selected: selectedAddr,
                display: (a) => a.label,
                searchText: (a) => '${a.alias} ${a.label}',
                onSelected: (a) => setState(() => _address = a),
                onCleared: () => setState(() => _address = const Address()),
              ),
            ),
            if (!widget.pdv)
              ErpDateField(
                label: 'Data de entrega',
                value: _deliveryDate,
                required: true,
                firstDate: DateTime.now(),
                onChanged: (v) => setState(() => _deliveryDate = v),
              ),
            ErpDropdown<String>(
              label: 'Forma',
              value: _methodId.isEmpty ? null : _methodId,
              items: (lookups?.methods ?? [])
                  .map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _methodId = v ?? ''),
            ),
            ErpDropdown<String>(
              label: 'Condição',
              value: _termId.isEmpty ? null : _termId,
              items: (lookups?.terms ?? [])
                  .map(
                    (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _termId = v ?? ''),
            ),
            LineItemsBar(
              count: _items.length,
              onAdd: () => _addItem(products, bals),
              onOpen: () => pushForm(
                context,
                LineItemsPage<OrderLine>(
                  items: _items,
                  titleOf: (i) {
                    final p = products
                        .where((x) => x.id == i.productId)
                        .firstOrNull;
                    return p == null ? i.productId : '${p.sku} — ${p.name}';
                  },
                  subtitleOf: (i) => '${i.quantity} × ${brl(i.unitPrice)}',
                  onDelete: (i) => setState(() => _items.removeAt(i)),
                ),
              ),
            ),
            _KitSwapSection(
              items: _items,
              onChanged: () => setState(() {}),
              assemblies: ref.watch(assembliesProvider).valueOrNull ?? const [],
              products: products,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem(List<_Product> products, List<Balance> bals) async {
    final line = await showModalBottomSheet<OrderLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(products: products, bals: bals, items: _items),
    );
    if (line != null && mounted) setState(() => _items.add(line));
  }

  Future<void> _newCustomer(List<Person> current) async {
    final before = {for (final c in current) c.id};
    await pushForm(
      context,
      PersonForm(
        title: 'Novo cliente',
        onSave: (p) => ref.read(customersProvider.notifier).save(p),
      ),
    );
    if (!mounted) return;
    ref.invalidate(salesLookupsProvider);
    final fresh = await ref.read(salesLookupsProvider.future);
    final created = fresh.customers
        .where((c) => !before.contains(c.id))
        .firstOrNull;
    if (created != null && mounted) _pickCustomer(created);
  }

  Future<void> _newAddress(Person customer) async {
    final created = await showAddressDialog(context);
    if (created == null || !mounted) return;
    try {
      await ref
          .read(customersProvider.notifier)
          .save(
            Person(
              id: customer.id,
              kind: customer.kind,
              document: customer.document,
              name: customer.name,
              phone: customer.phone,
              companyName: customer.companyName,
              responsibleName: customer.responsibleName,
              birthDate: customer.birthDate,
              gender: customer.gender,
              addresses: [...customer.addresses, created],
            ),
          );
      ref.invalidate(salesLookupsProvider);
      if (!mounted) return;
      setState(() => _address = created);
    } catch (e) {
      if (mounted) showError(context, '$e');
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!widget.pdv && _address.alias.isEmpty && _address.street.isEmpty) {
      showError(context, 'Selecione o endereço');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(salesOrdersProvider.notifier)
          .create(
            SalesOrder(
              id: '',
              customerId: _customerId,
              warehouseId: '',
              paymentMethodId: _methodId,
              paymentTermId: _termId,
              status: '',
              totalAmount: 0,
              items: List.of(_items),
              address: _address,
              paymentStatus: widget.pdv ? 'PAID' : '',
              deliveryDate: widget.pdv ? '' : _deliveryDate,
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

/// "Itens das cestas": troca um item da receita de um kit por outro sem mudar o preço da
/// cesta — mesma regra de equivalência de valor (+15% no máximo) do web
/// (kitSwap.ts/KitSubstitutions.tsx), ver lib/features/sales/domain/kit_swap.dart. [items] é
/// mutado por índice (mesmo padrão do resto do formulário, ex. LineItemsPage.onDelete) e
/// [onChanged] dispara o setState do pai.
class _KitSwapSection extends StatefulWidget {
  const _KitSwapSection({
    required this.items,
    required this.onChanged,
    required this.assemblies,
    required this.products,
  });

  final List<OrderLine> items;
  final VoidCallback onChanged;
  final List<Assembly> assemblies;
  final List<_Product> products;

  @override
  State<_KitSwapSection> createState() => _KitSwapSectionState();
}

class _KitSwapSectionState extends State<_KitSwapSection> {
  String? _error;

  _Product? _prod(String id) => widget.products.where((p) => p.id == id).firstOrNull;

  /// Componentes efetivos de uma linha de kit: os próprios (se já customizada) ou a receita
  /// padrão (quantidade do item × quantidade de cestas da linha).
  List<OrderItemComponent> _effective(OrderLine line, Assembly assembly) {
    if (line.components != null && line.components!.isNotEmpty) return line.components!;
    return [
      for (final ai in assembly.items)
        OrderItemComponent(productId: ai.productId, quantity: ai.quantity * line.quantity),
    ];
  }

  /// Valor que a receita original previa para esse slot (quantidade da receita × cestas × preço
  /// de venda) — o orçamento contra o qual toda troca nesse slot é medida, então trocas
  /// repetidas na mesma linha nunca acumulam desvio de arredondamento.
  double _slotBase(OrderLine line, Assembly assembly, int compIndex) {
    if (compIndex >= assembly.items.length) return 0;
    final ai = assembly.items[compIndex];
    return ai.quantity * line.quantity * (_prod(ai.productId)?.salePrice ?? 0);
  }

  void _replaceLine(int lineIndex, List<OrderItemComponent> comps) {
    final cur = widget.items[lineIndex];
    widget.items[lineIndex] = OrderLine(
      productId: cur.productId,
      quantity: cur.quantity,
      unitPrice: cur.unitPrice,
      components: comps,
    );
    widget.onChanged();
  }

  void _resetLine(int lineIndex) {
    setState(() => _error = null);
    _replaceLine(lineIndex, const []);
  }

  Future<void> _swap(int lineIndex, OrderLine line, Assembly assembly, int compIndex) async {
    final comps = List<OrderItemComponent>.from(_effective(line, assembly));
    final picked = await showDialog<_Product>(
      context: context,
      builder: (_) => _ProductPickerDialog(products: widget.products),
    );
    if (picked == null || !mounted) return;
    final original = compIndex < assembly.items.length ? assembly.items[compIndex] : null;
    // Voltar pro próprio produto da receita restaura a quantidade da receita.
    if (original != null && original.productId == picked.id) {
      comps[compIndex] = OrderItemComponent(
        productId: picked.id,
        quantity: double.parse((original.quantity * line.quantity).toStringAsFixed(4)),
      );
      setState(() => _error = null);
      _replaceLine(lineIndex, comps);
      return;
    }
    final target = _slotBase(line, assembly, compIndex);
    final eq = kit_swap.equivalentQuantity(target, picked.salePrice, kit_swap.qtyStep(picked.saleUom));
    if (!eq.ok) {
      setState(() => _error = '${picked.sku} — ${picked.name}: ${eq.reason}');
      return;
    }
    setState(() => _error = null);
    comps[compIndex] = OrderItemComponent(productId: picked.id, quantity: eq.quantity);
    _replaceLine(lineIndex, comps);
  }

  void _updateQty(int lineIndex, OrderLine line, Assembly assembly, int compIndex, double qty) {
    final comps = List<OrderItemComponent>.from(_effective(line, assembly));
    final price = _prod(comps[compIndex].productId)?.salePrice ?? 0;
    final base = _slotBase(line, assembly, compIndex);
    if (!kit_swap.withinPremium(qty, price, base)) {
      final pct = (kit_swap.maxPremium * 100).round();
      setState(() => _error = 'Quantidade acima do permitido: o item pode custar no máximo $pct% a mais que o item original da cesta.');
      return;
    }
    setState(() => _error = null);
    comps[compIndex] = OrderItemComponent(productId: comps[compIndex].productId, quantity: qty);
    _replaceLine(lineIndex, comps);
  }

  @override
  Widget build(BuildContext context) {
    final assemblyByProduct = {
      for (final a in widget.assemblies)
        if (a.productId.isNotEmpty) a.productId: a,
    };
    final kitLineIndexes = [
      for (var i = 0; i < widget.items.length; i++)
        if (assemblyByProduct.containsKey(widget.items[i].productId)) i,
    ];
    if (kitLineIndexes.isEmpty) return const SizedBox.shrink();
    final pct = (kit_swap.maxPremium * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Itens das cestas', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Troque um item da receita por outro sem alterar o preço da cesta — a quantidade '
                'do substituto é calculada pelo valor equivalente de venda, e o item novo pode '
                'custar no máximo $pct% a mais que o item trocado.',
                style: const TextStyle(color: erpMuted, fontSize: 12),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: erpDanger)),
              ],
              for (final lineIndex in kitLineIndexes)
                _kitLineCard(lineIndex, widget.items[lineIndex], assemblyByProduct[widget.items[lineIndex].productId]!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kitLineCard(int lineIndex, OrderLine line, Assembly assembly) {
    final comps = _effective(line, assembly);
    final customized = line.components != null && line.components!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${assembly.code} — ${assembly.name} × ${line.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (customized)
                TextButton(
                  onPressed: () => _resetLine(lineIndex),
                  child: const Text('Restaurar'),
                ),
            ],
          ),
          for (var ci = 0; ci < comps.length; ci++)
            _componentRow(lineIndex, line, assembly, ci, comps[ci]),
        ],
      ),
    );
  }

  Widget _componentRow(int lineIndex, OrderLine line, Assembly assembly, int compIndex, OrderItemComponent comp) {
    final p = _prod(comp.productId);
    final price = p?.salePrice ?? 0;
    final qtyController = TextEditingController(text: _fmtQty(comp.quantity));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _swap(lineIndex, line, assembly, compIndex),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Item', isDense: true),
                child: Text(p == null ? comp.productId : '${p.sku} — ${p.name}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              key: ValueKey('$lineIndex-$compIndex-${comp.quantity}'),
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Qtd', isDense: true, suffixText: p == null || p.saleUom.isEmpty ? null : p.saleUom),
              onFieldSubmitted: (v) => _updateQty(lineIndex, line, assembly, compIndex, parseNum(v, comp.quantity)),
              onTapOutside: (_) => _updateQty(lineIndex, line, assembly, compIndex, parseNum(qtyController.text, comp.quantity)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              price > 0 ? brl(comp.quantity * price) : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(color: erpMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtQty(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({required this.products});

  final List<_Product> products;

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(_query.trim());
    final shown = q.isEmpty
        ? widget.products
        : widget.products.where((p) => normalizeSearch('${p.sku} ${p.name}').contains(q)).toList();
    return AlertDialog(
      title: const Text('Trocar item'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Buscar produto', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: shown.isEmpty
                  ? const Center(child: Text('Nenhum produto', style: TextStyle(color: erpMuted)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final p = shown[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(p.sku),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }
}

typedef _Product = ({
  String id,
  String sku,
  String name,
  String barcode,
  String saleUom,
  double salePrice,
});

/// Bottom sheet that collects one order line (product, quantity, price).
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.products,
    required this.bals,
    required this.items,
  });

  final List<_Product> products;
  final List<Balance> bals;
  final List<OrderLine> items;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  _Product? _product;
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qty.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  String _fmtPrice(double n) {
    if (n <= 0) return '';
    if (n == n.roundToDouble()) return '${n.toInt()}';
    return n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final short =
        p != null &&
        parseNum(_qty.text, 1) +
                widget.items
                    .where((i) => i.productId == p.id)
                    .fold(0.0, (n, i) => n + i.quantity) >
            stockAvail(widget.bals, p.id) + 1e-9;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Adicionar item',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ErpAutocomplete<_Product>(
              label: 'Produto',
              options: widget.products,
              selected: p,
              display: (x) => '${x.sku} — ${x.name}',
              searchText: (x) => '${x.sku} ${x.name} ${x.barcode}',
              onSelected: (x) => setState(() {
                _product = x;
                _price.text = _fmtPrice(x.salePrice);
              }),
              onCleared: () => setState(() {
                _product = null;
                _price.text = '';
              }),
            ),
            QtyPriceFields(qty: _qty, price: _price),
            if (short)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Estoque insuficiente (disp. ${stockAvail(widget.bals, p.id)})',
                  style: const TextStyle(color: erpDanger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: p == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      OrderLine(
                        productId: p.id,
                        quantity: parseNum(_qty.text, 1),
                        unitPrice: parseNum(_price.text),
                      ),
                    ),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}
