class Forecast {
  const Forecast({
    required this.kind,
    required this.targetId,
    required this.code,
    required this.name,
    required this.computedWeeklyQty,
    required this.overrideWeeklyQty,
    required this.effectiveWeeklyQty,
    required this.excluded,
  });

  final String kind;
  final String targetId;
  final String code;
  final String name;
  final double computedWeeklyQty;
  final double? overrideWeeklyQty;
  final double effectiveWeeklyQty;
  final bool excluded;

  bool get isKit => kind == 'KIT';
}

class PlanLine {
  const PlanLine({
    required this.productId,
    required this.sku,
    required this.name,
    required this.forecastQty,
    required this.onHandQty,
    required this.openPoQty,
    required this.neededQty,
  });

  final String productId;
  final String sku;
  final String name;
  final double forecastQty;
  final double onHandQty;
  final double openPoQty;
  final double neededQty;
}

class FinancialLine {
  const FinancialLine({
    required this.kind,
    required this.targetId,
    required this.code,
    required this.name,
    required this.weeklyQty,
    required this.unitRevenue,
    required this.unitCost,
    required this.weeklyRevenue,
    required this.weeklyCost,
    required this.weeklyProfit,
    required this.marginPercent,
  });

  final String kind;
  final String targetId;
  final String code;
  final String name;
  final double weeklyQty;
  final double unitRevenue;
  final double unitCost;
  final double weeklyRevenue;
  final double weeklyCost;
  final double weeklyProfit;
  final double marginPercent;
}

class BudgetAllocation {
  const BudgetAllocation({
    required this.id,
    required this.supplierId,
    required this.quantity,
    required this.unitPrice,
    required this.hasQuote,
  });

  final String id;
  final String supplierId;
  final double quantity;
  final double unitPrice;
  final bool hasQuote;
}

class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.productId,
    required this.neededQty,
    required this.allocations,
  });

  final String id;
  final String productId;
  final double neededQty;
  final List<BudgetAllocation> allocations;

  double get allocatedQty => allocations.fold(0, (n, a) => n + a.quantity);
  double get remainingQty => (neededQty - allocatedQty).clamp(0, double.infinity);
}

class Budget {
  const Budget({
    required this.id,
    required this.code,
    required this.status,
    required this.coverageWeeks,
    required this.safetyPercent,
    required this.lookbackWeeks,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String code;
  final String status;
  final int coverageWeeks;
  final double safetyPercent;
  final int lookbackWeeks;
  final String createdAt;
  final List<BudgetItem> items;

  bool get editable => status == 'DRAFT' || status == 'ALLOCATED';

  String get statusLabel => switch (status) {
        'DRAFT' => 'Rascunho',
        'ALLOCATED' => 'Alocado',
        'CONFIRMED' => 'Confirmado',
        'CANCELLED' => 'Cancelado',
        _ => status,
      };
}

class SupplierPrice {
  const SupplierPrice({
    required this.id,
    required this.productId,
    required this.supplierId,
    required this.price,
    required this.minQty,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String supplierId;
  final double price;
  final double minQty;
  final String updatedAt;
}

class BudgetSchedule {
  const BudgetSchedule({
    this.id = '',
    required this.name,
    required this.frequency,
    this.dayOfWeek = 1,
    this.dayOfMonth = 1,
    this.coverageWeeks = 4,
    this.safetyPercent = 10,
    this.lookbackWeeks = 8,
    this.active = true,
    this.nextRunAt = '',
    this.lastRunAt = '',
  });

  final String id;
  final String name;
  final String frequency;
  final int dayOfWeek;
  final int dayOfMonth;
  final int coverageWeeks;
  final double safetyPercent;
  final int lookbackWeeks;
  final bool active;
  final String nextRunAt;
  final String lastRunAt;

  bool get weekly => frequency == 'WEEKLY';
}

typedef PlanParams = ({int coverageWeeks, double safetyPercent, int lookbackWeeks});
