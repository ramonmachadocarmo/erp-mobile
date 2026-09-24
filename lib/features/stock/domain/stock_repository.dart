import '../../../core/error/result.dart';
import '../../config/domain/entities.dart';
import 'entities.dart';

abstract class StockRepository {
  Future<Result<List<Product>>> products();
  Future<Result<Product>> saveProduct(Product product);
  Future<Result<void>> deleteProduct(String id);
  Future<Result<List<Category>>> categories();
  Future<Result<Category>> saveCategory(Category category);
  Future<Result<void>> deleteCategory(String id);
  Future<Result<List<Warehouse>>> warehouses();
  Future<Result<Warehouse>> saveWarehouse(Warehouse warehouse);
  Future<Result<List<Balance>>> balances();
  Future<Result<void>> setBalance({
    required String productId,
    required String warehouseId,
    required double quantity,
  });
  Future<Result<List<SalePrice>>> salePrices();
  Future<Result<void>> createSalePrice({
    required String productId,
    required double newPrice,
  });
  Future<Result<List<Assembly>>> assemblies();
  Future<Result<Assembly>> saveAssembly(Assembly assembly);
  Future<Result<List<Unit>>> units();
  Future<Result<List<StockMovement>>> movements();
}
