class CashEntry {
  const CashEntry({
    required this.id,
    required this.dueDate,
    required this.amount,
    required this.direction,
    required this.status,
    this.paymentMethodCode = '',
    this.referenceType = '',
    this.description = '',
  });

  final String id;
  final String dueDate;
  final double amount;
  final String direction;
  final String status;
  final String paymentMethodCode;
  // MANUAL = lançamento avulso (editável/removível daqui); SALE/PURCHASE vêm de um pedido.
  final String referenceType;
  final String description;
}

/// Um lançamento avulso de caixa, não vinculado a pedido de venda ou compra.
class ManualEntry {
  const ManualEntry({
    required this.direction,
    required this.dueDate,
    required this.amount,
    required this.description,
    this.paymentMethodId = '',
  });

  final String direction; // 'IN' ou 'OUT'
  final String dueDate; // YYYY-MM-DD
  final double amount;
  final String description;
  final String paymentMethodId;

  Map<String, dynamic> toJson() => {
        'direction': direction,
        'due_date': dueDate,
        'amount': amount,
        'description': description,
        if (paymentMethodId.isNotEmpty) 'payment_method_id': paymentMethodId,
      };
}

class CashSummary {
  const CashSummary({
    required this.date,
    required this.inflow,
    required this.outflow,
    required this.net,
    required this.balance,
  });

  final String date;
  final double inflow;
  final double outflow;
  final double net;
  final double balance;
}
