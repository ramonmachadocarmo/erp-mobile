import '../../../core/error/result.dart';
import '../../config/domain/entities.dart';
import 'entities.dart';

abstract class PurchasingRepository {
  Future<Result<List<Quote>>> quotes();
  Future<Result<void>> createQuote(Quote quote);
  Future<Result<void>> convertQuote(String id, {required String methodId, required String termId});
  Future<Result<List<PurchaseOrder>>> orders();
  Future<Result<void>> createOrder(PurchaseOrder order);
  Future<Result<void>> receive(String id, {String warehouseId = ''});
  Future<Result<void>> confer(String id);
  Future<Result<void>> cancel(String id);
  Future<Result<List<Person>>> suppliers();
  Future<Result<Person>> saveSupplier(Person person);
  Future<Result<List<PurchasePrice>>> history();
  Future<Result<PurchaseLookups>> lookups();
}
