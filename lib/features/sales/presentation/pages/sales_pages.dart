import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../../app/widgets/person_form.dart';
import '../../../config/domain/entities.dart';
import '../../../stock/domain/entities.dart';
import '../../../config/presentation/config_providers.dart';
import '../../../stock/presentation/stock_providers.dart';
import '../../domain/entities.dart';
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
          : '${statusView(o.status).label} · ${paymentStatusLabel(o.paymentStatus)}${orderStockShort(o, bals) ? ' · Estoque insuficiente' : ''} · ${brl(o.totalAmount)}',
      isThreeLine: forPicking,
      searchTextOf: (o) =>
          '${customers[o.customerId] ?? ''} ${orderNo(o.id)} ${sepNo(o.pickingNumber)} ${statusView(o.status).label}',
      // The separation list is already narrowed to a few statuses.
      filters: forPicking
          ? const []
          : [
              ListFilter<SalesOrder>.byValue(
                label: 'Status',
                valueOf: (o) => o.status,
                options: [
                  for (final st in _orderStatuses)
                    FilterOption(st, statusView(st).label),
                ],
              ),
              ListFilter<SalesOrder>.byValue(
                label: 'Pagamento',
                valueOf: _paymentOf,
                options: const [
                  FilterOption('PAID', 'Pago'),
                  FilterOption('PENDING', 'Pendente'),
                ],
              ),
            ],
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
      ],
      onAction: (o, action) {
        if (action == 'cancel') {
          ref.read(salesOrdersProvider.notifier).cancel(o.id);
        }
        if (action == 'pick') context.push('/logistica/separacao/${o.id}');
        if (action == 'undo') {
          ref.read(salesOrdersProvider.notifier).undoPicking(o.id);
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
    final created = await showDialog<Address>(
      context: context,
      builder: (_) => const _AddressDialog(),
    );
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

class _AddressDialog extends ConsumerStatefulWidget {
  const _AddressDialog();

  @override
  ConsumerState<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends ConsumerState<_AddressDialog> {
  final _numberFocus = FocusNode();
  var _searching = false;

  final _alias = TextEditingController();
  final _zip = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();

  @override
  void dispose() {
    _alias.dispose();
    _zip.dispose();
    _street.dispose();
    _number.dispose();
    _complement.dispose();
    _district.dispose();
    _city.dispose();
    _state.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  Future<void> _searchCep() async {
    if (_searching) return;
    final digits = _zip.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      showError(context, 'Informe um CEP com 8 dígitos');
      return;
    }
    setState(() => _searching = true);
    final result = await ref.read(configRepositoryProvider).lookupCep(digits);
    if (!mounted) return;
    setState(() => _searching = false);
    result.when(
      ok: (a) {
        // Keep whatever the user already typed when the lookup has no value.
        String pick(String found, TextEditingController c) =>
            found.isNotEmpty ? found : c.text;
        _zip.text = pick(a.zip, _zip);
        _street.text = pick(a.street, _street);
        _complement.text = pick(a.complement, _complement);
        _district.text = pick(a.district, _district);
        _city.text = pick(a.city, _city);
        _state.text = pick(a.state, _state);
        _numberFocus.requestFocus();
      },
      err: (f) => showError(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo endereço'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _alias,
              decoration: const InputDecoration(labelText: 'Alias'),
              autofocus: true,
            ),
            TextField(
              controller: _zip,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchCep(),
              onChanged: (v) {
                if (v.replaceAll(RegExp(r'\D'), '').length == 8) _searchCep();
              },
              decoration: InputDecoration(
                labelText: 'CEP',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar CEP',
                        onPressed: _searchCep,
                      ),
              ),
            ),
            TextField(
              controller: _street,
              decoration: const InputDecoration(labelText: 'Logradouro'),
            ),
            TextField(
              controller: _number,
              focusNode: _numberFocus,
              decoration: const InputDecoration(labelText: 'Número'),
            ),
            TextField(
              controller: _complement,
              decoration: const InputDecoration(labelText: 'Complemento'),
            ),
            TextField(
              controller: _district,
              decoration: const InputDecoration(labelText: 'Bairro'),
            ),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Cidade'),
            ),
            TextField(
              controller: _state,
              decoration: const InputDecoration(labelText: 'UF'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final a = Address(
              alias: _alias.text.trim(),
              zip: _zip.text.trim(),
              street: _street.text.trim(),
              number: _number.text.trim(),
              complement: _complement.text.trim(),
              district: _district.text.trim(),
              city: _city.text.trim(),
              state: _state.text.trim().toUpperCase(),
            );
            if (a.alias.isEmpty && a.street.isEmpty) return;
            Navigator.pop(context, a);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

typedef _Product = ({
  String id,
  String sku,
  String name,
  String barcode,
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
