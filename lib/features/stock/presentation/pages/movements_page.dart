import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../domain/entities.dart';
import '../stock_providers.dart';
import 'movement_form.dart';

/// Kardex — lista + lançamento de movimento manual (entrada/saída) ou transferência.
class MovementsPage extends ConsumerWidget {
  const MovementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(movementsProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[];
    String productLabel(String id) {
      final p = products.where((x) => x.id == id).firstOrNull;
      return p == null ? id : '${p.sku} — ${p.name}';
    }

    String warehouseLabel(String id) {
      final w = warehouses.where((x) => x.id == id).firstOrNull;
      return w == null ? id : w.name;
    }

    return CrudList<StockMovement>(
      value: items,
      onRefresh: () => ref.read(movementsProvider.notifier).reload(),
      onCreate: () => pushForm(context, const MovementForm()),
      titleOf: (m) => productLabel(m.productId),
      subtitleOf: (m) =>
          '${m.typeLabel} · ${_fmtQty(m.quantity)} · ${warehouseLabel(m.warehouseId)}\n${fmtDt(m.createdAt)} · ${m.originLabel}',
      isThreeLine: true,
      searchTextOf: (m) => '${productLabel(m.productId)} ${m.typeLabel} ${warehouseLabel(m.warehouseId)}',
      filters: [
        ListFilter<StockMovement>.byValue(label: 'Tipo', valueOf: (m) => m.movementType),
        ListFilter<StockMovement>.byValue(
          label: 'Almoxarifado',
          valueOf: (m) => m.warehouseId,
          labelOf: warehouseLabel,
        ),
      ],
    );
  }
}

String _fmtQty(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();
