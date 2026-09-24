import '../../../core/error/result.dart';
import '../../config/domain/entities.dart';
import 'entities.dart';

abstract class PurchasingRepository {
  Future<Result<List<Quote>>> quotes();
  Future<Result<void>> createQuote(Quote quote);
  Future<Result<void>> updateQuote(String id, Quote quote);
  Future<Result<void>> deleteQuote(String id);
  Future<Result<void>> convertQuote(String id, {required String methodId, required String termId});
  Future<Result<List<PurchaseOrder>>> orders();
  Future<Result<void>> createOrder(PurchaseOrder order);
  // Só aceito pelo backend enquanto o pedido está pendente de entrega e não pago.
  Future<Result<void>> updateOrder(String id, PurchaseOrder order);
  Future<Result<void>> deleteOrder(String id);
  Future<Result<void>> setPaymentStatus(String id, String status);
  // status: 'APPROVED' (reabre) ou 'CONFERRED' (finaliza à mão, sem mexer em estoque).
  Future<Result<void>> setDeliveryStatus(String id, String status);
  Future<Result<void>> receive(String id, {String warehouseId = ''});
  Future<Result<void>> confer(String id);
  Future<Result<void>> cancel(String id);
  Future<Result<List<Person>>> suppliers();
  Future<Result<Person>> saveSupplier(Person person);
  Future<Result<List<PurchasePrice>>> history();
  Future<Result<PurchaseLookups>> lookups();
}
