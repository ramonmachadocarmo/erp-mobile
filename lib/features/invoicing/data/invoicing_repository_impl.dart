import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../domain/entities.dart';

abstract class InvoicingRepository {
  Future<Result<List<Invoice>>> invoices(String direction);
  Future<Result<void>> issue(String id);
  Future<Result<void>> importFile({
    required String direction,
    String filePath = '',
    String fileName = '',
    String purchaseOrderId = '',
    bool withoutNote = false,
  });
}

class InvoicingRepositoryImpl implements InvoicingRepository {
  const InvoicingRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Invoice>>> invoices(String direction) => guardApi(() async {
        final list = await _client.getList('/api/invoicing/invoices?direction=$direction');
        return list
            .map(
              (j) => Invoice(
                id: asString(j, 'id'),
                invoiceNumber: asInt(j, 'invoice_number'),
                series: asString(j, 'series'),
                status: asString(j, 'status'),
                direction: asString(j, 'direction'),
                source: asString(j, 'source'),
                totalInvoice: asDouble(j, 'total_invoice'),
                fileName: asString(j, 'file_name'),
                purchaseOrderId: asString(j, 'purchase_order_id'),
              ),
            )
            .toList();
      });

  @override
  Future<Result<void>> issue(String id) =>
      guardApi(() => _client.post('/api/invoicing/invoices/$id/issue'));

  @override
  Future<Result<void>> importFile({
    required String direction,
    String filePath = '',
    String fileName = '',
    String purchaseOrderId = '',
    bool withoutNote = false,
  }) =>
      guardApi(
        () => _client.postMultipart(
          '/api/invoicing/invoices/import',
          filePath: filePath.isEmpty ? null : filePath,
          fileName: fileName,
          fields: {
            'direction': direction,
            if (purchaseOrderId.isNotEmpty) 'purchase_order_id': purchaseOrderId,
            if (withoutNote) 'without_note': 'true',
          },
        ),
      );
}
