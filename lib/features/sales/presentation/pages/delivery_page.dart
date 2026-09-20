import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../config/domain/entities.dart';
import '../../../stock/presentation/stock_providers.dart';
import '../../domain/entities.dart';
import '../sales_providers.dart';
import 'picking_labels_page.dart';

Future<String?> askFailNote(BuildContext context, [String initial = '']) async {
  final ctrl = TextEditingController(text: initial);
  final note = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Não foi possível entregar'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Motivo'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () {
            final t = ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(ctx, t);
          },
          child: const Text('Registrar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return note;
}

class DeliveryPage extends ConsumerWidget {
  const DeliveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref
        .watch(salesOrdersProvider)
        .whenData(
          (list) => list
              .where(
                (o) =>
                    o.status == 'PICKED' ||
                    o.status == 'DELIVERED' ||
                    o.status == 'UNDELIVERED',
              )
              .toList(),
        );
    final people = {
      for (final c in ref.watch(customersProvider).valueOrNull ?? []) c.id: c,
    };
    final customers = {
      for (final e in people.entries) e.key: e.value.displayName,
    };
    final products = ref.watch(productsProvider).valueOrNull ?? [];
    return CrudList<SalesOrder>(
      value: orders,
      onRefresh: () => ref.read(salesOrdersProvider.notifier).reload(),
      emptyLabel: 'Nenhuma entrega',
      titleOf: (o) => customers[o.customerId] ?? o.customerId,
      subtitleOf: (o) => [
        if (o.pickingNumber > 0) 'Sep. ${sepNo(o.pickingNumber)}',
        if (o.volumeCount > 0) '${o.volumeCount} vol',
        statusView(o.status).label,
        brl(o.totalAmount),
      ].join(' · '),
      searchTextOf: (o) =>
          '${customers[o.customerId] ?? ''} ${sepNo(o.pickingNumber)} ${_deliveryAddress(o, people[o.customerId])}',
      filters: [
        ListFilter<SalesOrder>.byValue(
          label: 'Status',
          valueOf: (o) => o.status,
          options: [
            for (final st in const ['PICKED', 'DELIVERED', 'UNDELIVERED'])
              FilterOption(st, statusView(st).label),
          ],
        ),
      ],
      itemBuilder: (context, o) {
        return ExpansionTile(
          title: Text(customers[o.customerId] ?? o.customerId),
          subtitle: Text(
            [
              if (o.pickingNumber > 0) 'Sep. ${sepNo(o.pickingNumber)}',
              if (o.volumeCount > 0) '${o.volumeCount} vol',
              statusView(o.status).label,
              brl(o.totalAmount),
            ].join(' · '),
            style: const TextStyle(color: erpMuted),
          ),
          children: [
            ListTile(
              dense: true,
              title: const Text('Status'),
              subtitle: statusChip(o.status, extra: o.deliveryNote),
            ),
            ListTile(
              dense: true,
              title: const Text('Endereço'),
              subtitle: Text(_deliveryAddress(o, people[o.customerId])),
            ),
            for (final it in o.items)
              ListTile(
                dense: true,
                title: Text(() {
                  final matches = products.where((x) => x.id == it.productId);
                  if (matches.isEmpty) return it.productId;
                  final p = matches.first;
                  return '${p.sku} — ${p.name}';
                }()),
                subtitle: Text('${it.quantity} × ${brl(it.unitPrice)}'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (o.status == 'DELIVERED')
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: erpDanger),
                      onPressed: () async {
                        try {
                          await ref
                              .read(salesOrdersProvider.notifier)
                              .undoDeliver(o.id);
                        } catch (e) {
                          if (context.mounted) showError(context, '$e');
                        }
                      },
                      child: const Text('Cancelar entrega'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PickingLabelsPage(
                            order: o,
                            customerName:
                                customers[o.customerId] ?? o.customerId,
                            address: _deliveryAddress(o, people[o.customerId]),
                          ),
                        ),
                      ),
                      child: const Text('Etiquetas'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(salesOrdersProvider.notifier)
                              .deliver(o.id);
                        } catch (e) {
                          if (context.mounted) showError(context, '$e');
                        }
                      },
                      child: const Text('Confirmar entrega'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final note = await askFailNote(context, o.deliveryNote);
                        if (note == null || !context.mounted) return;
                        try {
                          await ref
                              .read(salesOrdersProvider.notifier)
                              .failDelivery(o.id, note);
                        } catch (e) {
                          if (context.mounted) showError(context, '$e');
                        }
                      },
                      child: const Text('Não foi possível'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _deliveryAddress(SalesOrder order, Person? customer) {
  if (order.address.label != '—') return order.address.label;
  final addrs = customer?.addresses ?? const <Address>[];
  if (addrs.isEmpty) return '—';
  return addrs.first.label;
}
