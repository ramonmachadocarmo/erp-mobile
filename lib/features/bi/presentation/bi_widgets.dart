import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/form_kit.dart';
import '../../../core/error/result.dart';
import '../domain/entities.dart';
import '../../stock/domain/entities.dart';
import '../../stock/presentation/stock_providers.dart';

const weekdays = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

String fmtQty(num n) {
  final s = n.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

String fmtPct(num n) => '${n.toStringAsFixed(1).replaceAll('.', ',')}%';

String errText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Runs a repository call, surfacing failures as a snack bar; returns true on success.
Future<bool> runAction(BuildContext context, Future<Result<void>> call) async {
  final r = await call;
  return r.when(
    ok: (_) => true,
    err: (f) {
      if (context.mounted) showError(context, f.message);
      return false;
    },
  );
}

Future<bool> confirmDialog(BuildContext context, String message, {String action = 'Confirmar'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}

/// Products keyed by id, for resolving names/units from ids returned by bi-service.
Map<String, Product> productsById(WidgetRef ref) => {
      for (final p in ref.watch(productsProvider).valueOrNull ?? const <Product>[]) p.id: p,
    };

String productLabel(Map<String, Product> products, String id) {
  final p = products[id];
  return p == null ? id : '${p.sku} — ${p.name}';
}

double? convertQty(double qty, String from, String to, List<UomConversion> convs) {
  if (from.isEmpty || to.isEmpty || from == to) return qty;
  for (final c in convs) {
    if (c.factor <= 0) continue;
    if (c.fromUom == from && c.toUom == to) return qty * c.factor;
    if (c.fromUom == to && c.toUom == from) return qty / c.factor;
  }
  return null;
}

/// Price per stock unit of a supplier quote (price ÷ min qty, converted from the product's
/// purchase unit to its stock unit) — lets quotes with different pack sizes be compared.
double? supplierUnitCost(Product? p, SupplierPrice sp) {
  if (p == null || sp.minQty <= 0) return null;
  final stockPerPurchase = convertQty(1, p.purchaseUom, p.stockUom, p.conversions);
  if (stockPerPurchase == null || stockPerPurchase <= 0) return null;
  return sp.price / sp.minQty / stockPerPurchase;
}

/// Cheapest registered quote for a product, by price per stock unit.
({SupplierPrice sp, double unitCost})? bestSupplierPrice(Product? p, Iterable<SupplierPrice> prices) {
  ({SupplierPrice sp, double unitCost})? best;
  for (final sp in prices) {
    if (sp.productId != p?.id) continue;
    final cost = supplierUnitCost(p, sp);
    if (cost == null) continue;
    if (best == null || cost < best.unitCost) best = (sp: sp, unitCost: cost);
  }
  return best;
}

class NumParam extends StatelessWidget {
  const NumParam({super.key, required this.label, required this.controller, this.decimal = false});

  final String label;
  final TextEditingController controller;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

/// Card with the parameter fields (in a wrap) and the buttons of a BI/report screen.
class ParamsCard extends StatelessWidget {
  const ParamsCard({super.key, required this.fields, required this.actions});

  final List<Widget> fields;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: erpPanel,
        border: Border.all(color: erpLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final f in fields) SizedBox(width: 150, child: f)],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.negative = false, this.hint});

  final String label;
  final String value;
  final bool negative;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: erpPanel,
        border: Border.all(color: erpLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: erpMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: negative ? erpDanger : erpText),
          ),
          if (hint != null) Text(hint!, style: const TextStyle(color: erpMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, this.color = erpAccent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
