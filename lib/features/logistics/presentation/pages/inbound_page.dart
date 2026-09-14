import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../invoicing/presentation/invoicing_pages.dart';
import '../../../purchasing/domain/entities.dart';
import '../../../purchasing/presentation/pages/purchasing_pages.dart';
import '../../../purchasing/presentation/purchasing_providers.dart';

class InboundPage extends ConsumerWidget {
  const InboundPage({super.key});

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
    final shown = orders.whenData(
      (list) => list.where((o) => invoiced.containsKey(o.id) && o.status == 'APPROVED').toList(),
    );
    return CrudList<PurchaseOrder>(
      value: shown,
      onRefresh: () async {
        await ref.read(purchaseOrdersProvider.notifier).reload();
        await ref.read(invoicesProvider('IN').notifier).reload();
      },
      titleOf: (o) => names[o.supplierId] ?? o.supplierId,
      subtitleOf: (o) {
        final inv = invoiced[o.id];
        final nf = inv == null ? '' : 'NF ${inv.series}-${inv.invoiceNumber} · ';
        return '$nf${statusView(o.status).label} · ${brl(o.totalAmount)}';
      },
      extraActions: (_) => [const PopupMenuItem(value: 'receive', child: Text('Receber'))],
      onAction: (o, action) {
        if (action == 'receive') pushForm(context, ReceiveOrderForm(order: o));
      },
      onTap: (o) => pushForm(context, ReceiveOrderForm(order: o)),
    );
  }
}
