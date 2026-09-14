import '../../../core/error/result.dart';
import '../../config/domain/entities.dart';
import 'entities.dart';

abstract class SalesRepository {
  Future<Result<List<SalesOrder>>> orders();
  Future<Result<SalesOrder>> getOrder(String id);
  Future<Result<void>> createOrder(SalesOrder order);
  Future<Result<void>> cancelOrder(String id);
  Future<Result<SalesOrder>> scanPick(String id, {required String productId, required String warehouseId, double quantity});
  Future<Result<SalesOrder>> completePicking(String id, {required int volumeCount});
  Future<Result<void>> undoPicking(String id);
  Future<Result<void>> deliver(String id);
  Future<Result<void>> failDelivery(String id, String note);
  Future<Result<void>> undoDeliver(String id);
  Future<Result<List<DeliveryPlan>>> deliveryPlans();
  Future<Result<DeliveryPlan>> getDeliveryPlan(String id);
  Future<Result<List<DeliveryCandidate>>> deliveryCandidates();
  Future<Result<PlanResult>> createDeliveryPlans({
    required String centerId,
    required List<String> vehicleIds,
    required List<String> orderIds,
  });
  Future<Result<DeliveryPlan>> confirmDeliveryPlan(String id, {RouteOption? option});
  Future<Result<List<Person>>> customers();
  Future<Result<Person>> saveCustomer(Person person);
  Future<Result<SalesLookups>> lookups();
}
