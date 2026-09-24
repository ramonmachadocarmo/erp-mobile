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
}

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
