import '../../../core/error/result.dart';
import 'entities.dart';

abstract class ConfigRepository {
  Future<Result<List<Unit>>> units();
  Future<Result<Unit>> saveUnit(Unit unit);
  Future<Result<List<PaymentMethod>>> methods();
  Future<Result<PaymentMethod>> saveMethod(PaymentMethod method);
  Future<Result<List<PaymentTerm>>> terms();
  Future<Result<PaymentTerm>> saveTerm(PaymentTerm term);
  Future<Result<bool>> quoteRequired();
  Future<Result<void>> setQuoteRequired(bool value);
  Future<Result<String>> defaultWarehouse();
  Future<Result<void>> setDefaultWarehouse(String id);
  Future<Result<List<DistCenter>>> centers();
  Future<Result<List<Vehicle>>> vehicles();
}
