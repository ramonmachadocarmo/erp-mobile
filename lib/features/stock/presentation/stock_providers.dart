import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../config/domain/entities.dart';
import '../data/stock_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/stock_repository.dart';

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepositoryImpl(ref.watch(apiClientProvider)),
);

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(ProductsNotifier.new);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() =>
      ref.read(stockRepositoryProvider).products().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(stockRepositoryProvider).products().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Product p) async {
    (await ref.read(stockRepositoryProvider).saveProduct(p)).getOrThrow();
    await reload();
  }

  Future<void> remove(String id) async {
    (await ref.read(stockRepositoryProvider).deleteProduct(id)).getOrThrow();
    await reload();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() =>
      ref.read(stockRepositoryProvider).categories().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(stockRepositoryProvider).categories().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Category c) async {
    (await ref.read(stockRepositoryProvider).saveCategory(c)).getOrThrow();
    await reload();
  }

  Future<void> remove(String id) async {
    (await ref.read(stockRepositoryProvider).deleteCategory(id)).getOrThrow();
    await reload();
  }
}

final warehousesProvider =
    AsyncNotifierProvider<WarehousesNotifier, List<Warehouse>>(WarehousesNotifier.new);

class WarehousesNotifier extends AsyncNotifier<List<Warehouse>> {
  @override
  Future<List<Warehouse>> build() =>
      ref.read(stockRepositoryProvider).warehouses().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(stockRepositoryProvider).warehouses().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Warehouse w) async {
    (await ref.read(stockRepositoryProvider).saveWarehouse(w)).getOrThrow();
    await reload();
  }
}

final balancesProvider =
    AsyncNotifierProvider<BalancesNotifier, List<Balance>>(BalancesNotifier.new);

class BalancesNotifier extends AsyncNotifier<List<Balance>> {
  @override
  Future<List<Balance>> build() =>
      ref.read(stockRepositoryProvider).balances().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(stockRepositoryProvider).balances().then((r) => r.getOrThrow()),
    );
  }

  Future<void> setBalance(String productId, String warehouseId, double qty) async {
    (await ref.read(stockRepositoryProvider).setBalance(
          productId: productId,
          warehouseId: warehouseId,
          quantity: qty,
        ))
        .getOrThrow();
    await reload();
  }
}

final salePricesProvider =
    AsyncNotifierProvider<SalePricesNotifier, List<SalePrice>>(SalePricesNotifier.new);

class SalePricesNotifier extends AsyncNotifier<List<SalePrice>> {
  @override
  Future<List<SalePrice>> build() =>
      ref.read(stockRepositoryProvider).salePrices().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(stockRepositoryProvider).salePrices().then((r) => r.getOrThrow()),
    );
  }

  Future<void> create(String productId, double price) async {
    (await ref.read(stockRepositoryProvider).createSalePrice(
          productId: productId,
          newPrice: price,
        ))
        .getOrThrow();
    await reload();
    await ref.read(productsProvider.notifier).reload();
  }
}

final assembliesProvider =
    AsyncNotifierProvider<AssembliesNotifier, List<Assembly>>(AssembliesNotifier.new);

class AssembliesNotifier extends AsyncNotifier<List<Assembly>> {
  @override
  Future<List<Assembly>> build() =>
      ref.read(stockRepositoryProvider).assemblies().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(stockRepositoryProvider).assemblies().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Assembly a) async {
    (await ref.read(stockRepositoryProvider).saveAssembly(a)).getOrThrow();
    await reload();
  }
}

final stockUnitsProvider = FutureProvider<List<Unit>>(
  (ref) async => (await ref.watch(stockRepositoryProvider).units()).getOrThrow(),
);
