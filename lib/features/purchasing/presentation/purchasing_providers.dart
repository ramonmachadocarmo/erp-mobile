import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../config/domain/entities.dart';
import '../data/purchasing_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/purchasing_repository.dart';

final purchasingRepositoryProvider = Provider<PurchasingRepository>(
  (ref) => PurchasingRepositoryImpl(ref.watch(apiClientProvider)),
);

final quotesProvider = AsyncNotifierProvider<QuotesNotifier, List<Quote>>(QuotesNotifier.new);

class QuotesNotifier extends AsyncNotifier<List<Quote>> {
  @override
  Future<List<Quote>> build() =>
      ref.read(purchasingRepositoryProvider).quotes().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(purchasingRepositoryProvider).quotes().then((r) => r.getOrThrow()),
    );
  }

  Future<void> create(Quote q) async {
    (await ref.read(purchasingRepositoryProvider).createQuote(q)).getOrThrow();
    await reload();
  }

  Future<void> updateQuote(String id, Quote q) async {
    (await ref.read(purchasingRepositoryProvider).updateQuote(id, q)).getOrThrow();
    await reload();
  }

  Future<void> deleteQuote(String id) async {
    (await ref.read(purchasingRepositoryProvider).deleteQuote(id)).getOrThrow();
    await reload();
  }

  Future<void> convert(String id, String methodId, String termId) async {
    (await ref.read(purchasingRepositoryProvider).convertQuote(id, methodId: methodId, termId: termId))
        .getOrThrow();
    await reload();
    await ref.read(purchaseOrdersProvider.notifier).reload();
  }
}

final purchaseOrdersProvider =
    AsyncNotifierProvider<PurchaseOrdersNotifier, List<PurchaseOrder>>(PurchaseOrdersNotifier.new);

class PurchaseOrdersNotifier extends AsyncNotifier<List<PurchaseOrder>> {
  @override
  Future<List<PurchaseOrder>> build() =>
      ref.read(purchasingRepositoryProvider).orders().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(purchasingRepositoryProvider).orders().then((r) => r.getOrThrow()),
    );
  }

  Future<void> create(PurchaseOrder o) async {
    (await ref.read(purchasingRepositoryProvider).createOrder(o)).getOrThrow();
    await reload();
  }

  Future<void> updateOrder(String id, PurchaseOrder o) async {
    (await ref.read(purchasingRepositoryProvider).updateOrder(id, o)).getOrThrow();
    await reload();
  }

  Future<void> delete(String id) async {
    (await ref.read(purchasingRepositoryProvider).deleteOrder(id)).getOrThrow();
    await reload();
  }

  Future<void> setPaymentStatus(String id, String status) async {
    (await ref.read(purchasingRepositoryProvider).setPaymentStatus(id, status)).getOrThrow();
    await reload();
  }

  Future<void> setDeliveryStatus(String id, String status) async {
    (await ref.read(purchasingRepositoryProvider).setDeliveryStatus(id, status)).getOrThrow();
    await reload();
  }

  Future<void> receive(String id, {String warehouseId = ''}) async {
    (await ref.read(purchasingRepositoryProvider).receive(id, warehouseId: warehouseId)).getOrThrow();
    await reload();
    await ref.read(purchaseHistoryProvider.notifier).reload();
  }

  Future<void> confer(String id) async {
    (await ref.read(purchasingRepositoryProvider).confer(id)).getOrThrow();
    await reload();
  }

  Future<void> cancel(String id) async {
    (await ref.read(purchasingRepositoryProvider).cancel(id)).getOrThrow();
    await reload();
  }
}

final suppliersProvider =
    AsyncNotifierProvider<SuppliersNotifier, List<Person>>(SuppliersNotifier.new);

class SuppliersNotifier extends AsyncNotifier<List<Person>> {
  @override
  Future<List<Person>> build() =>
      ref.read(purchasingRepositoryProvider).suppliers().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(purchasingRepositoryProvider).suppliers().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Person p) async {
    (await ref.read(purchasingRepositoryProvider).saveSupplier(p)).getOrThrow();
    await reload();
    ref.invalidate(purchaseLookupsProvider);
  }
}

final purchaseHistoryProvider =
    AsyncNotifierProvider<PurchaseHistoryNotifier, List<PurchasePrice>>(PurchaseHistoryNotifier.new);

class PurchaseHistoryNotifier extends AsyncNotifier<List<PurchasePrice>> {
  @override
  Future<List<PurchasePrice>> build() =>
      ref.read(purchasingRepositoryProvider).history().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(purchasingRepositoryProvider).history().then((r) => r.getOrThrow()),
    );
  }
}

final purchaseLookupsProvider = FutureProvider<PurchaseLookups>(
  (ref) async => (await ref.watch(purchasingRepositoryProvider).lookups()).getOrThrow(),
);
