import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../../app/widgets/person_form.dart';
import '../../../config/domain/entities.dart';
import '../../../stock/domain/entities.dart';
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
  return o.items.any((it) => it.quantity > stockOnHand(bals, it.productId) + 1e-9);
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

class SalesOrdersPage extends ConsumerWidget {
  const SalesOrdersPage({super.key, this.forPicking = false});

  final bool forPicking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(salesOrdersProvider);
    final shown = forPicking
        ? orders.whenData(
            (list) => list
                .where((o) => o.status == 'APPROVED' || o.status == 'PICKING' || o.status == 'PICKED')
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
          : '${statusView(o.status).label}${orderStockShort(o, bals) ? ' · Estoque insuficiente' : ''} · ${brl(o.totalAmount)}',
      isThreeLine: forPicking,
      onCreate: forPicking ? null : () => pushForm(context, const _OrderForm()),
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
        if (action == 'undo') ref.read(salesOrdersProvider.notifier).undoPicking(o.id);
      },
    );
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  const _OrderForm();

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
  var _productId = '';
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  var _draftKey = 0;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _qty.addListener(() => setState(() {}));
    Future.microtask(() => ref.invalidate(salesLookupsProvider));
  }

  String _fmtPrice(double n) {
    if (n <= 0) return '';
    if (n == n.roundToDouble()) return '${n.toInt()}';
    return n.toStringAsFixed(2);
  }

  void _fillPrice(
    List<
      ({String id, String sku, String name, String barcode, double salePrice})
    >
    products,
    String? id,
  ) {
    final p = products.where((x) => x.id == id).firstOrNull;
    _price.text = p == null ? '' : _fmtPrice(p.salePrice);
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bals = ref.watch(balancesProvider).valueOrNull ?? [];
    final lookups = ref.watch(salesLookupsProvider).valueOrNull;
    final products = lookups?.products ?? [];
    final customer = (lookups?.customers ?? [])
        .where((c) => c.id == _customerId)
        .firstOrNull;
    final addresses = customer?.addresses ?? const <Address>[];
    final selectedAddr =
        addresses
            .where((a) => a.id == _address.id && a.id.isNotEmpty)
            .firstOrNull ??
        (addresses
            .where(
              (a) => a.alias == _address.alias && _address.alias.isNotEmpty,
            )
            .firstOrNull);
    ref.listen(salesLookupsProvider, (_, next) {
      final list = next.valueOrNull?.products ?? [];
      if (_productId.isNotEmpty) _fillPrice(list, _productId);
    });
    return Form(
      key: _form,
      child: FormScaffold(
        title: 'Novo pedido',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpDropdown<String>(
              label: 'Cliente',
              value: _customerId.isEmpty ? null : _customerId,
              items: (lookups?.customers ?? [])
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _customerId = v ?? '';
                _address = const Address();
                final c = (lookups?.customers ?? [])
                    .where((x) => x.id == _customerId)
                    .firstOrNull;
                if (c != null && c.addresses.length == 1) {
                  _address = c.addresses.first;
                }
              }),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<Address>(
                    key: ValueKey('${_customerId}_${_address.alias}'),
                    initialValue: TextEditingValue(
                      text: selectedAddr == null ? '' : selectedAddr.label,
                    ),
                    displayStringForOption: (a) => a.label,
                    optionsBuilder: (v) {
                      final q = v.text.trim().toLowerCase();
                      if (q.isEmpty) return addresses;
                      return addresses.where(
                        (a) =>
                            a.alias.toLowerCase().contains(q) ||
                            a.label.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (a) => setState(() => _address = a),
                    fieldViewBuilder: (context, controller, focus, onSubmit) {
                      return TextField(
                        controller: controller,
                        focusNode: focus,
                        enabled: _customerId.isNotEmpty,
                        onSubmitted: (_) => onSubmit(),
                        decoration: const InputDecoration(
                          labelText: 'Endereço',
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filled(
                    onPressed: _customerId.isEmpty
                        ? null
                        : () => _newAddress(customer!),
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
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
            KeyedSubtree(
              key: ValueKey(_draftKey),
              child: Column(
                children: [
                  ErpDropdown<String>(
                    label: 'Produto',
                    value: _productId.isEmpty ? null : _productId,
                    items: products
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.sku} — ${p.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _productId = v ?? '';
                        _fillPrice(products, v);
                      });
                    },
                  ),
                  QtyPriceFields(qty: _qty, price: _price),
                  if (_productId.isNotEmpty &&
                      parseNum(_qty.text, 1) +
                              _items
                                  .where((i) => i.productId == _productId)
                                  .fold(0.0, (n, i) => n + i.quantity) >
                          stockAvail(bals, _productId) + 1e-9)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Estoque insuficiente (disp. ${stockAvail(bals, _productId)})',
                        style: const TextStyle(color: erpDanger, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            LineItemsBar(
              count: _items.length,
              onAdd: _add,
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

  void _add() {
    if (_productId.isEmpty) return;
    setState(() {
      _items.add(
        OrderLine(
          productId: _productId,
          quantity: parseNum(_qty.text, 1),
          unitPrice: parseNum(_price.text),
        ),
      );
      _productId = '';
      _qty.text = '1';
      _price.text = '';
      _draftKey++;
    });
  }

  Future<void> _newAddress(Person customer) async {
    final created = await showDialog<Address>(
      context: context,
      builder: (_) => const _AddressDialog(),
    );
    if (created == null || !mounted) return;
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
    await ref.read(customersProvider.notifier).reload();
    ref.invalidate(salesLookupsProvider);
    if (!mounted) return;
    setState(() => _address = created);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_address.alias.isEmpty && _address.street.isEmpty) {
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

class _AddressDialog extends StatefulWidget {
  const _AddressDialog();

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
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
    super.dispose();
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
              decoration: const InputDecoration(labelText: 'CEP'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _street,
              decoration: const InputDecoration(labelText: 'Logradouro'),
            ),
            TextField(
              controller: _number,
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
