class FixedAsset {
  const FixedAsset({
    required this.id,
    required this.productId,
    required this.tag,
    this.serialNumber = '',
    this.description = '',
    this.location = '',
    this.acquisitionDate = '',
    this.acquisitionCost = 0,
    this.residualValue = 0,
    this.usefulLifeMonths = 0,
    this.netBookValue = 0,
    this.status = 'ACTIVE',
  });

  final String id;
  final String productId;
  final String tag;
  final String serialNumber;
  final String description;
  final String location;
  final String acquisitionDate;
  final double acquisitionCost;
  final double residualValue;
  final int usefulLifeMonths;
  final double netBookValue;
  final String status;
}

class AssetMovement {
  const AssetMovement({
    required this.id,
    required this.assetId,
    required this.movementType,
    required this.toLocation,
    required this.amount,
    required this.occurredAt,
    this.notes = '',
  });

  final String id;
  final String assetId;
  final String movementType;
  final String toLocation;
  final double amount;
  final String occurredAt;
  final String notes;

  String get typeLabel {
    switch (movementType) {
      case 'ACQUIRE':
        return 'Aquisição';
      case 'TRANSFER':
        return 'Transferência';
      case 'DEPRECIATE':
        return 'Depreciação';
      case 'DISPOSE':
        return 'Baixa';
      default:
        return movementType;
    }
  }
}
