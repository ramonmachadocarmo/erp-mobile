import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../config/domain/entities.dart';
import '../data/sales_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepositoryImpl(ref.watch(apiClientProvider)),
);

final salesOrdersProvider =
    AsyncNotifierProvider<SalesOrdersNotifier, List<SalesOrder>>(SalesOrdersNotifier.new);

class SalesOrdersNotifier extends AsyncNotifier<List<SalesOrder>> {
  @override
  Future<List<SalesOrder>> build() =>
      ref.read(salesRepositoryProvider).orders().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(salesRepositoryProvider).orders().then((r) => r.getOrThrow()),
    );
  }

  Future<void> create(SalesOrder order) async {
    (await ref.read(salesRepositoryProvider).createOrder(order)).getOrThrow();
    await reload();
  }

  Future<void> cancel(String id) async {
    (await ref.read(salesRepositoryProvider).cancelOrder(id)).getOrThrow();
    await reload();
  }

  Future<void> undoPicking(String id) async {
    (await ref.read(salesRepositoryProvider).undoPicking(id)).getOrThrow();
    await reload();
  }

  Future<void> deliver(String id) async {
    (await ref.read(salesRepositoryProvider).deliver(id)).getOrThrow();
    await reload();
  }

  Future<void> failDelivery(String id, String note) async {
    (await ref.read(salesRepositoryProvider).failDelivery(id, note)).getOrThrow();
    await reload();
  }

  Future<void> undoDeliver(String id) async {
    (await ref.read(salesRepositoryProvider).undoDeliver(id)).getOrThrow();
    await reload();
  }
}

final deliveryPlansProvider =
    AsyncNotifierProvider<DeliveryPlansNotifier, List<DeliveryPlan>>(DeliveryPlansNotifier.new);

class DeliveryPlansNotifier extends AsyncNotifier<List<DeliveryPlan>> {
  @override
  Future<List<DeliveryPlan>> build() =>
      ref.read(salesRepositoryProvider).deliveryPlans().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(salesRepositoryProvider).deliveryPlans().then((r) => r.getOrThrow()),
    );
  }

  Future<void> deliver(String orderId) async {
    (await ref.read(salesRepositoryProvider).deliver(orderId)).getOrThrow();
    await reload();
    await ref.read(salesOrdersProvider.notifier).reload();
  }

  Future<void> failDelivery(String orderId, String note) async {
    (await ref.read(salesRepositoryProvider).failDelivery(orderId, note)).getOrThrow();
    await reload();
    await ref.read(salesOrdersProvider.notifier).reload();
  }

  Future<void> undoDeliver(String orderId) async {
    (await ref.read(salesRepositoryProvider).undoDeliver(orderId)).getOrThrow();
    await reload();
    await ref.read(salesOrdersProvider.notifier).reload();
  }

  Future<PlanResult> createPlans({
    required String centerId,
    required List<String> vehicleIds,
    required List<String> orderIds,
  }) async {
    final out = (await ref.read(salesRepositoryProvider).createDeliveryPlans(
          centerId: centerId,
          vehicleIds: vehicleIds,
          orderIds: orderIds,
        ))
        .getOrThrow();
    await reload();
    return out;
  }

  Future<DeliveryPlan> confirm(String id, {RouteOption? option}) async {
    final p = (await ref.read(salesRepositoryProvider).confirmDeliveryPlan(id, option: option)).getOrThrow();
    await reload();
    return p;
  }
}

final deliveryCandidatesProvider =
    AsyncNotifierProvider<DeliveryCandidatesNotifier, List<DeliveryCandidate>>(DeliveryCandidatesNotifier.new);

class DeliveryCandidatesNotifier extends AsyncNotifier<List<DeliveryCandidate>> {
  @override
  Future<List<DeliveryCandidate>> build() =>
      ref.read(salesRepositoryProvider).deliveryCandidates().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(salesRepositoryProvider).deliveryCandidates().then((r) => r.getOrThrow()),
    );
  }
}

final deliveryPlanProvider = FutureProvider.family<DeliveryPlan, String>((ref, id) async {
  return (await ref.watch(salesRepositoryProvider).getDeliveryPlan(id)).getOrThrow();
});

final customersProvider =
    AsyncNotifierProvider<CustomersNotifier, List<Person>>(CustomersNotifier.new);

class CustomersNotifier extends AsyncNotifier<List<Person>> {
  @override
  Future<List<Person>> build() =>
      ref.read(salesRepositoryProvider).customers().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(salesRepositoryProvider).customers().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Person person) async {
    (await ref.read(salesRepositoryProvider).saveCustomer(person)).getOrThrow();
    await reload();
  }
}

final salesLookupsProvider = FutureProvider<SalesLookups>(
  (ref) async => (await ref.watch(salesRepositoryProvider).lookups()).getOrThrow(),
);
