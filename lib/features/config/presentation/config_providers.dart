import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../data/config_repository_impl.dart';
import '../domain/config_repository.dart';
import '../domain/entities.dart';

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepositoryImpl(ref.watch(apiClientProvider)),
);

final unitsProvider = AsyncNotifierProvider<UnitsNotifier, List<Unit>>(
  UnitsNotifier.new,
);

class UnitsNotifier extends AsyncNotifier<List<Unit>> {
  @override
  Future<List<Unit>> build() =>
      ref.read(configRepositoryProvider).units().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(configRepositoryProvider).units().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Unit unit) async {
    (await ref.read(configRepositoryProvider).saveUnit(unit)).getOrThrow();
    await reload();
  }
}

final methodsProvider =
    AsyncNotifierProvider<MethodsNotifier, List<PaymentMethod>>(MethodsNotifier.new);

class MethodsNotifier extends AsyncNotifier<List<PaymentMethod>> {
  @override
  Future<List<PaymentMethod>> build() =>
      ref.read(configRepositoryProvider).methods().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(configRepositoryProvider).methods().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(PaymentMethod method) async {
    (await ref.read(configRepositoryProvider).saveMethod(method)).getOrThrow();
    await reload();
  }
}

final termsProvider =
    AsyncNotifierProvider<TermsNotifier, List<PaymentTerm>>(TermsNotifier.new);

class TermsNotifier extends AsyncNotifier<List<PaymentTerm>> {
  @override
  Future<List<PaymentTerm>> build() =>
      ref.read(configRepositoryProvider).terms().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(configRepositoryProvider).terms().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(PaymentTerm term) async {
    (await ref.read(configRepositoryProvider).saveTerm(term)).getOrThrow();
    await reload();
  }
}

final quoteRequiredProvider =
    AsyncNotifierProvider<QuoteRequiredNotifier, bool>(QuoteRequiredNotifier.new);

class QuoteRequiredNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.read(configRepositoryProvider).quoteRequired().then((r) => r.getOrThrow());

  Future<void> setValue(bool value) async {
    (await ref.read(configRepositoryProvider).setQuoteRequired(value)).getOrThrow();
    state = AsyncData(value);
  }
}

final defaultWarehouseProvider =
    AsyncNotifierProvider<DefaultWarehouseNotifier, String>(DefaultWarehouseNotifier.new);

class DefaultWarehouseNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() =>
      ref.read(configRepositoryProvider).defaultWarehouse().then((r) => r.getOrThrow());

  Future<void> setValue(String id) async {
    (await ref.read(configRepositoryProvider).setDefaultWarehouse(id)).getOrThrow();
    state = AsyncData(id);
  }
}

final centersProvider = FutureProvider<List<DistCenter>>(
  (ref) async => (await ref.watch(configRepositoryProvider).centers()).getOrThrow(),
);

final vehiclesProvider = FutureProvider<List<Vehicle>>(
  (ref) async => (await ref.watch(configRepositoryProvider).vehicles()).getOrThrow(),
);
