import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../data/assets_repository_impl.dart';
import '../domain/entities.dart';

final assetsRepositoryProvider = Provider(
  (ref) => AssetsRepositoryImpl(ref.watch(apiClientProvider)),
);

final assetsProvider = AsyncNotifierProvider<AssetsNotifier, List<FixedAsset>>(AssetsNotifier.new);

class AssetsNotifier extends AsyncNotifier<List<FixedAsset>> {
  @override
  Future<List<FixedAsset>> build() =>
      ref.read(assetsRepositoryProvider).assets().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(assetsRepositoryProvider).assets().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(FixedAsset a) async {
    (await ref.read(assetsRepositoryProvider).save(a)).getOrThrow();
    await reload();
  }

  Future<void> transfer(String id, String location, String notes) async {
    (await ref.read(assetsRepositoryProvider).transfer(id, location, notes)).getOrThrow();
    await reload();
    await ref.read(assetMovementsProvider.notifier).reload();
  }

  Future<void> depreciate(String id) async {
    (await ref.read(assetsRepositoryProvider).depreciate(id)).getOrThrow();
    await reload();
    await ref.read(assetMovementsProvider.notifier).reload();
  }

  Future<void> disposeAsset(String id, String notes) async {
    (await ref.read(assetsRepositoryProvider).dispose(id, notes)).getOrThrow();
    await reload();
    await ref.read(assetMovementsProvider.notifier).reload();
  }
}

final assetMovementsProvider =
    AsyncNotifierProvider<AssetMovementsNotifier, List<AssetMovement>>(AssetMovementsNotifier.new);

class AssetMovementsNotifier extends AsyncNotifier<List<AssetMovement>> {
  @override
  Future<List<AssetMovement>> build() =>
      ref.read(assetsRepositoryProvider).movements().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(assetsRepositoryProvider).movements().then((r) => r.getOrThrow()),
    );
  }
}

final fixedProductsProvider = FutureProvider(
  (ref) async => (await ref.watch(assetsRepositoryProvider).fixedProducts()).getOrThrow(),
);
