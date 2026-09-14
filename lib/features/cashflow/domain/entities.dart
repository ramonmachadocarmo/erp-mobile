class CashEntry {
  const CashEntry({
    required this.id,
    required this.dueDate,
    required this.amount,
    required this.direction,
    required this.status,
    this.paymentMethodCode = '',
    this.referenceType = '',
  });

  final String id;
  final String dueDate;
  final double amount;
  final String direction;
  final String status;
  final String paymentMethodCode;
  final String referenceType;
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
