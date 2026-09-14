class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.series,
    required this.status,
    required this.direction,
    required this.source,
    required this.totalInvoice,
    this.fileName = '',
    this.purchaseOrderId = '',
  });

  final String id;
  final int invoiceNumber;
  final String series;
  final String status;
  final String direction;
  final String source;
  final double totalInvoice;
  final String fileName;
  final String purchaseOrderId;
}
